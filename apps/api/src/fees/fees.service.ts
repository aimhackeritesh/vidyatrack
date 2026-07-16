import { BadRequestException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { TenantDb } from '../common/database/tenant-db.service';
import { v4 as uuidv4 } from 'uuid';
import { PAYMENT_GATEWAY, PaymentGateway } from './payment/payment-gateway.interface';

@Injectable()
export class FeesService {
  constructor(
    private readonly db: TenantDb,
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
  ) {}

  getFeeHeads(schoolId: string) {
    return this.db.query(`SELECT * FROM fee_heads WHERE school_id=$1 ORDER BY name`, [schoolId]);
  }

  // ── Fee structure (Phase D1) ─────────────────────────────────────────────────
  async createFeeHead(schoolId: string, data: any) {
    if (!data.name || data.amount == null || Number(data.amount) < 0) {
      throw new BadRequestException('Name and a non-negative amount are required');
    }
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO fee_heads(id,school_id,name,amount,frequency,class_id) VALUES($1,$2,$3,$4,$5,$6)`,
      [id, schoolId, data.name, data.amount, data.frequency ?? 'monthly', data.classId ?? null],
    );
    return { id };
  }

  async updateFeeHead(schoolId: string, id: string, data: any) {
    if (!data.name || data.amount == null || Number(data.amount) < 0) {
      throw new BadRequestException('Name and a non-negative amount are required');
    }
    const res = await this.db.query(
      `UPDATE fee_heads SET name=$3, amount=$4, frequency=$5, class_id=$6 WHERE id=$1 AND school_id=$2 RETURNING id`,
      [id, schoolId, data.name, data.amount, data.frequency ?? 'monthly', data.classId ?? null],
    );
    if (!res.length) throw new NotFoundException('Fee head not found');
    return { message: 'Updated' };
  }

  async deleteFeeHead(schoolId: string, id: string) {
    const res = await this.db.query(`DELETE FROM fee_heads WHERE id=$1 AND school_id=$2 RETURNING id`, [id, schoolId]);
    if (!res.length) throw new NotFoundException('Fee head not found');
    return { message: 'Deleted' };
  }

  // ── Invoice generation (Phase D2) ────────────────────────────────────────────
  /**
   * Turns fee_heads into a fee_invoice per active student for the given month.
   * Idempotent: re-running only touches invoices still `pending` (paid/partial/
   * overdue/waived invoices are left alone even if the fee structure changed).
   * Quarterly/annual heads are spread evenly across their period; one_time heads
   * are billed only on a student's very first invoice.
   */
  async generateInvoices(schoolId: string, userId: string, month: string, classId?: string) {
    const monthDate = month.length === 7 ? `${month}-01` : month;
    const dueDateDay = Number(await this.getSetting(schoolId, 'due_date_day', '10'));

    const students = await this.db.query(
      `SELECT s.id, sec.class_id
       FROM students s JOIN sections sec ON sec.id = s.section_id
       WHERE s.school_id=$1 AND s.status='active' ${classId ? 'AND sec.class_id=$2' : ''}`,
      classId ? [schoolId, classId] : [schoolId],
    );

    let created = 0, updated = 0, skipped = 0;
    for (const student of students) {
      const heads = await this.db.query(
        `SELECT amount, frequency FROM fee_heads WHERE school_id=$1 AND (class_id IS NULL OR class_id=$2)`,
        [schoolId, student.class_id],
      );
      let dueAmount = 0;
      for (const h of heads) {
        const amt = Number(h.amount);
        if (h.frequency === 'monthly') dueAmount += amt;
        else if (h.frequency === 'quarterly') dueAmount += amt / 3;
        else if (h.frequency === 'annual') dueAmount += amt / 12;
        else if (h.frequency === 'one_time') {
          const [existing] = await this.db.query(`SELECT 1 FROM fee_invoices WHERE school_id=$1 AND student_id=$2 LIMIT 1`, [schoolId, student.id]);
          if (!existing) dueAmount += amt;
        }
      }
      dueAmount = Math.round(dueAmount * 100) / 100;

      const res = await this.db.query(
        `INSERT INTO fee_invoices(id,school_id,student_id,month,due_amount,due_date,status)
         VALUES($1,$2,$3,$4::date,$5,($4::date + ($6::int - 1) * INTERVAL '1 day'),'pending')
         ON CONFLICT (school_id,student_id,month) DO UPDATE
           SET due_amount=EXCLUDED.due_amount, due_date=EXCLUDED.due_date, updated_at=NOW()
           WHERE fee_invoices.status='pending'
         RETURNING (xmax = 0) AS inserted`,
        [uuidv4(), schoolId, student.id, monthDate, dueAmount, dueDateDay],
      );
      if (res.length) { if (res[0].inserted) created++; else updated++; } else { skipped++; }
    }

    await this.audit(schoolId, userId, 'invoices.generate', null, { month: monthDate, classId, created, updated, skipped });
    return { month: monthDate, studentsProcessed: students.length, created, updated, skipped };
  }

  private async getSetting(schoolId: string, key: string, fallback: string): Promise<string> {
    const [row] = await this.db.query(`SELECT value FROM school_settings WHERE school_id=$1 AND key=$2`, [schoolId, key]);
    return row?.value ?? fallback;
  }

  async collectPayment(schoolId: string, collectorId: string, data: any) {
    const paymentId = uuidv4();
    const receiptNo = `RCP${Date.now()}`;
    await this.db.query(
      `INSERT INTO fee_payments(id,invoice_id,school_id,amount,mode,fine,discount,received_by,receipt_no,paid_at)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW())`,
      [paymentId, data.invoiceId, schoolId, data.amount, data.mode ?? 'cash',
       data.fine ?? 0, data.discount ?? 0, collectorId, receiptNo],
    );
    await this.recomputeInvoiceStatus(data.invoiceId);
    await this.refreshRevenueSummary(schoolId);
    await this.audit(schoolId, collectorId, 'fee.collect', paymentId, { amount: data.amount, invoiceId: data.invoiceId });
    return { paymentId, receiptNo };
  }

  async getStudentDues(schoolId: string, user: any, studentId: string) {
    await this.assertStudentAccess(schoolId, user, studentId);
    return this.db.query(
      `SELECT fi.*,
              COALESCE((SELECT SUM(amount) FROM fee_payments WHERE invoice_id=fi.id AND voided_at IS NULL),0) as paid_amount
       FROM fee_invoices fi
       WHERE fi.school_id=$1 AND fi.student_id=$2 AND fi.status != 'paid'
       ORDER BY fi.month`,
      [schoolId, studentId],
    );
  }

  // ── Parent-facing dues (Phase D3) ───────────────────────────────────────────
  /** Every invoice (not just unpaid) for the caller's own/child student, plus a running total owed. */
  async getMyDues(schoolId: string, user: any) {
    const studentId = await this.viewerStudentId(schoolId, user);
    if (!studentId) return { studentId: null, totalOutstanding: 0, invoices: [] };
    const invoices = await this.db.query(
      `SELECT fi.*,
              COALESCE((SELECT SUM(amount) FROM fee_payments WHERE invoice_id=fi.id AND voided_at IS NULL),0) as paid_amount
       FROM fee_invoices fi WHERE fi.school_id=$1 AND fi.student_id=$2 ORDER BY fi.month DESC`,
      [schoolId, studentId],
    );
    const totalOutstanding = invoices.reduce(
      (sum: number, i: any) => sum + Math.max(0, Number(i.due_amount) - Number(i.paid_amount)), 0,
    );
    return { studentId, totalOutstanding: Math.round(totalOutstanding * 100) / 100, invoices };
  }

  async getInvoiceDetail(schoolId: string, user: any, invoiceId: string) {
    const [invoice] = await this.db.query(`SELECT * FROM fee_invoices WHERE id=$1 AND school_id=$2`, [invoiceId, schoolId]);
    if (!invoice) throw new NotFoundException('Invoice not found');
    await this.assertStudentAccess(schoolId, user, invoice.student_id);
    const payments = await this.db.query(`SELECT * FROM fee_payments WHERE invoice_id=$1 ORDER BY paid_at DESC`, [invoiceId]);
    return { invoice, payments };
  }

  // ── Online payment (Phase D4) ────────────────────────────────────────────────
  private async invoiceBalance(invoiceId: string, dueAmount: number): Promise<number> {
    const [{ paid }] = await this.db.query(
      `SELECT COALESCE(SUM(amount),0) as paid FROM fee_payments WHERE invoice_id=$1 AND voided_at IS NULL`, [invoiceId],
    );
    return Math.round((dueAmount - Number(paid)) * 100) / 100;
  }

  async createPaymentOrder(schoolId: string, user: any, invoiceId: string, requestedAmount?: number) {
    const [invoice] = await this.db.query(`SELECT * FROM fee_invoices WHERE id=$1 AND school_id=$2`, [invoiceId, schoolId]);
    if (!invoice) throw new NotFoundException('Invoice not found');
    await this.assertStudentAccess(schoolId, user, invoice.student_id);

    const balance = await this.invoiceBalance(invoiceId, Number(invoice.due_amount));
    if (balance <= 0) throw new BadRequestException('Invoice already fully paid');
    const amount = requestedAmount ? Math.min(Number(requestedAmount), balance) : balance;
    if (amount <= 0) throw new BadRequestException('Amount must be greater than 0');

    const order = await this.gateway.createOrder({ amount, receiptId: invoiceId });
    return { ...order, invoiceId };
  }

  /** Server-side verified — the client's claim of payment is never trusted without this. Idempotent on gateway_payment_id. */
  async verifyPayment(schoolId: string, user: any, data: any) {
    const { invoiceId, orderId, paymentId, signature } = data;
    const [invoice] = await this.db.query(`SELECT * FROM fee_invoices WHERE id=$1 AND school_id=$2`, [invoiceId, schoolId]);
    if (!invoice) throw new NotFoundException('Invoice not found');
    await this.assertStudentAccess(schoolId, user, invoice.student_id);

    const [existing] = await this.db.query(`SELECT id, receipt_no FROM fee_payments WHERE gateway_payment_id=$1`, [paymentId]);
    if (existing) return { paymentId: existing.id, receiptNo: existing.receipt_no, alreadyProcessed: true };

    const verified = await this.gateway.verifyPayment({ orderId, paymentId, signature });
    if (!verified) throw new BadRequestException('Payment verification failed');

    const balance = await this.invoiceBalance(invoiceId, Number(invoice.due_amount));
    const amount = Math.min(Number(data.amount) || balance, balance);
    if (amount <= 0) throw new BadRequestException('Invoice already fully paid');

    const id = uuidv4();
    const receiptNo = `RCP${Date.now()}`;
    await this.db.query(
      `INSERT INTO fee_payments(id,invoice_id,school_id,amount,mode,receipt_no,paid_at,gateway_order_id,gateway_payment_id)
       VALUES($1,$2,$3,$4,'online',$5,NOW(),$6,$7)`,
      [id, invoiceId, schoolId, amount, receiptNo, orderId, paymentId],
    );
    await this.recomputeInvoiceStatus(invoiceId);
    await this.refreshRevenueSummary(schoolId);
    await this.audit(schoolId, user.id, 'fee.pay.online', id, { amount, invoiceId });
    await this.notifyPayment(schoolId, user.id, amount, invoiceId);
    return { paymentId: id, receiptNo, amount };
  }

  async getReceipt(schoolId: string, user: any, paymentId: string) {
    const [payment] = await this.db.query(
      `SELECT fp.*, fi.student_id, fi.month, s.name as student_name
       FROM fee_payments fp JOIN fee_invoices fi ON fi.id=fp.invoice_id JOIN students s ON s.id=fi.student_id
       WHERE fp.id=$1 AND fp.school_id=$2`,
      [paymentId, schoolId],
    );
    if (!payment) throw new NotFoundException('Payment not found');
    await this.assertStudentAccess(schoolId, user, payment.student_id);
    return payment;
  }

  private async notifyPayment(schoolId: string, payerId: string, amount: number, invoiceId: string) {
    const admins = await this.db.query(`SELECT user_id FROM user_roles WHERE school_id=$1 AND role='admin'`, [schoolId]);
    const recipients = [payerId, ...admins.map((a: any) => a.user_id)];
    for (const userId of recipients) {
      await this.db.query(
        `INSERT INTO notifications(id,school_id,user_id,title,body,type,data) VALUES($1,$2,$3,$4,$5,'fee_payment',$6)`,
        [uuidv4(), schoolId, userId, 'Payment received', `₹${amount} received towards fees`, JSON.stringify({ invoiceId })],
      );
    }
  }

  private async viewerStudentId(schoolId: string, user: any): Promise<string | undefined> {
    if (user.role === 'student') {
      const [r] = await this.db.query(`SELECT linked_entity_id FROM user_roles WHERE id=$1`, [user.userRoleId]);
      return r?.linked_entity_id;
    }
    if (user.role === 'parent') {
      const [r] = await this.db.query(
        `SELECT id FROM students WHERE school_id=$1 AND guardian_user_id=$2 AND status='active' ORDER BY created_at LIMIT 1`,
        [schoolId, user.id],
      );
      return r?.id;
    }
    return undefined;
  }

  private async assertStudentAccess(schoolId: string, user: any, studentId: string) {
    if (user.role === 'admin' || user.role === 'teacher') return;
    if (user.role === 'parent') {
      const [r] = await this.db.query(`SELECT 1 FROM students WHERE id=$1 AND school_id=$2 AND guardian_user_id=$3`, [studentId, schoolId, user.id]);
      if (!r) throw new ForbiddenException('Not your child');
      return;
    }
    if (user.role === 'student') {
      const [r] = await this.db.query(`SELECT 1 FROM user_roles WHERE id=$1 AND linked_entity_id=$2`, [user.userRoleId, studentId]);
      if (!r) throw new ForbiddenException('Not allowed');
      return;
    }
    throw new ForbiddenException('Not allowed');
  }

  async getDailyRevenue(schoolId: string) {
    const [r] = await this.db.query(`SELECT * FROM daily_revenue_summary WHERE school_id=$1`, [schoolId]);
    return r ?? { total_revenue: 0, amount_received: 0, back_due: 0, fine_received: 0, expense: 0, discount: 0 };
  }

  // ── Manual entries (Phase 3) ────────────────────────────────────────────────

  /** Other income — admission forms, donations, transport, etc. */
  async addIncome(schoolId: string, userId: string, data: any) {
    if (!data.amount || Number(data.amount) <= 0) throw new BadRequestException('Amount must be greater than 0');
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO other_income(id,school_id,category,amount,note,received_by,date)
       VALUES($1,$2,$3,$4,$5,$6,COALESCE($7,CURRENT_DATE))`,
      [id, schoolId, data.category ?? 'Other', data.amount, data.note ?? null, userId, data.date ?? null],
    );
    await this.refreshRevenueSummary(schoolId);
    await this.audit(schoolId, userId, 'income.add', id, { category: data.category, amount: data.amount });
    return { id };
  }

  async addExpense(schoolId: string, userId: string, data: any) {
    if (!data.amount || Number(data.amount) <= 0) throw new BadRequestException('Amount must be greater than 0');
    const id = uuidv4();
    await this.db.query(
      `INSERT INTO expenses(id,school_id,category,amount,note,spent_by,date) VALUES($1,$2,$3,$4,$5,$6,COALESCE($7,CURRENT_DATE))`,
      [id, schoolId, data.category ?? 'Other', data.amount, data.note ?? null, userId, data.date ?? null],
    );
    await this.refreshRevenueSummary(schoolId);
    await this.audit(schoolId, userId, 'expense.add', id, { category: data.category, amount: data.amount });
    return { id };
  }

  /** Void any money entry. Past entries should be corrected via an adjustment,
   *  but same-day mistakes can be voided; both keep a full audit trail. */
  async voidEntry(schoolId: string, userId: string, kind: 'payment' | 'income' | 'expense', id: string, reason: string) {
    const table = kind === 'payment' ? 'fee_payments' : kind === 'income' ? 'other_income' : 'expenses';
    const [row] = await this.db.query(`SELECT * FROM ${table} WHERE id=$1 AND school_id=$2`, [id, schoolId]);
    if (!row) throw new NotFoundException('Entry not found');
    if (row.voided_at) throw new BadRequestException('Entry is already voided');

    await this.db.query(`UPDATE ${table} SET voided_at=NOW(), void_reason=$3 WHERE id=$1 AND school_id=$2`, [id, schoolId, reason ?? '']);
    if (kind === 'payment') await this.recomputeInvoiceStatus(row.invoice_id);
    await this.refreshRevenueSummary(schoolId);
    await this.audit(schoolId, userId, `${kind}.void`, id, { reason, amount: row.amount });
    return { message: 'Entry voided', id };
  }

  /** Today's entries for the "Today's Revenue" detail / void UI. */
  async listToday(schoolId: string) {
    const payments = await this.db.query(
      `SELECT fp.id, fp.amount, fp.fine, fp.discount, fp.mode, fp.receipt_no, fp.paid_at, fp.voided_at,
              s.name as student_name
       FROM fee_payments fp
       JOIN fee_invoices fi ON fi.id=fp.invoice_id
       JOIN students s ON s.id=fi.student_id
       WHERE fp.school_id=$1 AND fp.paid_at::DATE=CURRENT_DATE ORDER BY fp.paid_at DESC`,
      [schoolId],
    );
    const income = await this.db.query(
      `SELECT id, category, amount, note, voided_at FROM other_income WHERE school_id=$1 AND date=CURRENT_DATE ORDER BY created_at DESC`,
      [schoolId],
    );
    const expenses = await this.db.query(
      `SELECT id, category, amount, note, voided_at FROM expenses WHERE school_id=$1 AND date=CURRENT_DATE ORDER BY created_at DESC`,
      [schoolId],
    );
    return { payments, income, expenses };
  }

  /** Per-day series for the Total Revenue graph. */
  async getRevenueRange(schoolId: string, from: string, to: string) {
    return this.db.query(
      `WITH days AS (SELECT generate_series($2::date, $3::date, '1 day')::date AS d),
       fees AS (
         SELECT fp.paid_at::DATE AS d, SUM(fp.amount) AS amt, SUM(fp.fine) AS fine
         FROM fee_payments fp WHERE fp.school_id=$1 AND fp.voided_at IS NULL
           AND fp.paid_at::DATE BETWEEN $2 AND $3 GROUP BY 1),
       inc AS (
         SELECT date AS d, SUM(amount) AS amt FROM other_income
         WHERE school_id=$1 AND voided_at IS NULL AND date BETWEEN $2 AND $3 GROUP BY 1),
       exp AS (
         SELECT date AS d, SUM(amount) AS amt FROM expenses
         WHERE school_id=$1 AND voided_at IS NULL AND date BETWEEN $2 AND $3 GROUP BY 1)
       SELECT to_char(days.d,'YYYY-MM-DD') AS date,
              COALESCE(fees.amt,0)+COALESCE(inc.amt,0) AS received,
              COALESCE(exp.amt,0) AS expense,
              COALESCE(fees.amt,0)+COALESCE(inc.amt,0)+COALESCE(fees.fine,0)-COALESCE(exp.amt,0) AS net
       FROM days
       LEFT JOIN fees ON fees.d=days.d
       LEFT JOIN inc ON inc.d=days.d
       LEFT JOIN exp ON exp.d=days.d
       ORDER BY days.d`,
      [schoolId, from, to],
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  private async recomputeInvoiceStatus(invoiceId: string) {
    await this.db.query(
      `UPDATE fee_invoices fi SET status = (CASE
         WHEN (SELECT COALESCE(SUM(amount),0) FROM fee_payments WHERE invoice_id=fi.id AND voided_at IS NULL) >= fi.due_amount THEN 'paid'
         WHEN (SELECT COALESCE(SUM(amount),0) FROM fee_payments WHERE invoice_id=fi.id AND voided_at IS NULL) > 0 THEN 'partial'
         ELSE 'pending' END)::invoice_status_enum, updated_at=NOW()
       WHERE fi.id=$1`,
      [invoiceId],
    );
  }

  private async refreshRevenueSummary(schoolId: string) {
    await this.db.query(`SELECT refresh_daily_revenue($1::uuid)`, [schoolId]);
  }

  private async audit(schoolId: string, userId: string, action: string, entityId: string, payload: any) {
    await this.db.query(
      `INSERT INTO audit_logs(id,school_id,user_id,action,entity,entity_id,payload) VALUES($1,$2,$3,$4,'revenue',$5,$6)`,
      [uuidv4(), schoolId, userId, action, entityId, JSON.stringify(payload)],
    );
  }
}
