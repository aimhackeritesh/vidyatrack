/**
 * Demo seed — creates a complete, demo-able school so every Phase 0 screen has data.
 *
 * Produces (per the v2 Phase 0 spec):
 *   • 1 school (code VDTRK2627DEMO01)
 *   • 3 classes × 2 sections = 6 sections, 40 students each = 240 students
 *   • 5 teachers
 *   • ~1 month of daily attendance (sessions + records + daily_attendance_summary)
 *     and teacher attendance  → dashboard charts show real 0–100% data (fixes B2/B3)
 *   • fee heads, invoices, and payments dated today → Daily Revenue card is non-zero (B7 data)
 *
 * Re-runnable: wipes this demo school's tenant data first, then rebuilds.
 *
 * Run: npm run seed   (or: npm run seed:demo)  from apps/api
 *      Connects with DATABASE_ADMIN_URL (superuser → bypasses RLS) when set.
 */
import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import * as argon2 from 'argon2';
import { v4 as uuidv4 } from 'uuid';
dotenv.config();

const SCHOOL_CODE = 'VDTRK2627DEMO01';
const PASSWORD = 'Demo@1234';

const CLASSES = ['1', '2', '3'];
const SECTIONS = ['A', 'B'];
const STUDENTS_PER_SECTION = 40;
const ATTENDANCE_DAYS = 30; // calendar days back; Sundays skipped

const TEACHERS = [
  { phone: '9999900002', name: 'Ramesh Gupta', code: 'EMP001', subjects: '{Mathematics,Science}' },
  { phone: '9999900004', name: 'Sunita Verma', code: 'EMP002', subjects: '{English,Hindi}' },
  { phone: '9999900005', name: 'Anil Kapoor', code: 'EMP003', subjects: '{Social Science}' },
  { phone: '9999900006', name: 'Meena Joshi', code: 'EMP004', subjects: '{EVS,Drawing}' },
  { phone: '9999900007', name: 'Vikram Rao', code: 'EMP005', subjects: '{Computer,Sports}' },
];

const FIRST_NAMES = [
  'Aarav', 'Priya', 'Rohit', 'Anjali', 'Vikas', 'Sneha', 'Arjun', 'Pooja', 'Rahul', 'Neha',
  'Sumit', 'Kavya', 'Vivek', 'Ritu', 'Amit', 'Shivani', 'Deepak', 'Meena', 'Mohit', 'Tanvi',
  'Karan', 'Isha', 'Nikhil', 'Divya', 'Sahil', 'Aarti', 'Manish', 'Swati', 'Gaurav', 'Nidhi',
  'Akash', 'Riya', 'Yash', 'Komal', 'Harsh', 'Payal', 'Raj', 'Simran', 'Dev', 'Sara',
];
const LAST_NAMES = ['Sharma', 'Singh', 'Kumar', 'Gupta', 'Verma', 'Mishra', 'Yadav', 'Tiwari', 'Dubey', 'Agarwal'];

const seedUrl = process.env.DATABASE_ADMIN_URL || process.env.DATABASE_URL || '';
const ds = new DataSource({
  type: 'postgres',
  url: seedUrl,
  // Managed Postgres (Railway/RDS/etc.) requires TLS over the public proxy;
  // local docker does not.
  ssl: /localhost|127\.0\.0\.1|@postgres[.:]/.test(seedUrl) ? false : { rejectUnauthorized: false },
  synchronize: false,
  logging: false,
  entities: [],
});

// Deterministic, varied attendance so charts have shape (≈88% present overall).
function statusFor(studentIdx: number, dayIdx: number): string {
  const h = (studentIdx * 31 + dayIdx * 17 + 7) % 100;
  if (h < 88) return 'present';
  if (h < 95) return 'absent';
  if (h < 98) return 'late';
  return 'leave';
}

function fmtDate(d: Date): string {
  return d.toISOString().split('T')[0];
}

async function wipeDemo(schoolId: string) {
  // Communication / notification rows (safe to clear; reference users/school only).
  await ds.query(`DELETE FROM notifications WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM notices WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM circulars WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM messages WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM suggestions WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM leave_requests WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM audit_logs WHERE school_id=$1`, [schoolId]);
  // Academics
  await ds.query(`DELETE FROM exam_results WHERE exam_id IN (SELECT id FROM exams WHERE school_id=$1)`, [schoolId]);
  await ds.query(`DELETE FROM exams WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM homework WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM study_materials WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM syllabus WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM timetable_slots WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM holidays WHERE school_id=$1`, [schoolId]);
  // Child-first delete so foreign keys never block. Scoped to the demo school.
  await ds.query(
    `DELETE FROM fee_payments WHERE invoice_id IN (SELECT id FROM fee_invoices WHERE school_id=$1)`,
    [schoolId],
  );
  await ds.query(`DELETE FROM fee_payments WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM fee_invoices WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM fee_heads WHERE school_id=$1`, [schoolId]);
  await ds.query(
    `DELETE FROM attendance_records WHERE session_id IN (SELECT id FROM attendance_sessions WHERE school_id=$1)`,
    [schoolId],
  );
  await ds.query(`DELETE FROM attendance_sessions WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM teacher_attendance WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM daily_attendance_summary WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM daily_revenue_summary WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM expenses WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM other_income WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM students WHERE school_id=$1`, [schoolId]);
  // Auto-generated Student/Parent login accounts (global users table). Deleting
  // the user cascades its user_roles. Done after students so no guardian FK remains.
  await ds.query(
    `DELETE FROM users WHERE login_id IS NOT NULL AND id IN (SELECT user_id FROM user_roles WHERE school_id=$1)`,
    [schoolId],
  );
  await ds.query(`DELETE FROM teachers WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM sections WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM classes WHERE school_id=$1`, [schoolId]);
  await ds.query(`DELETE FROM user_roles WHERE school_id=$1`, [schoolId]);
}

async function run() {
  await ds.initialize();
  console.log('Connected to DB');

  const hash = await argon2.hash(PASSWORD);

  // ───── school ─────
  const schoolId = uuidv4();
  await ds.query(
    `INSERT INTO schools(id,code,name,principal_name,email,phone,address,city,state,academic_year_start,plan,status,sms_credits)
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'trial','active',500)
     ON CONFLICT(code) DO NOTHING`,
    [schoolId, SCHOOL_CODE, 'Demo Global School', 'Mrs. Priya Sharma',
     'demo@vidyatrack.in', '9999900001', 'MG Road', 'Bareilly', 'Uttar Pradesh', '2026-04-01'],
  );
  const [school] = await ds.query(`SELECT id FROM schools WHERE code=$1`, [SCHOOL_CODE]);
  const SID = school.id as string;

  // ───── platform super-admin (global, not tied to a school) ─────
  const [existingSA] = await ds.query(`SELECT id FROM users WHERE email=$1`, ['founder@vidyatrack.in']);
  if (!existingSA) {
    await ds.query(
      `INSERT INTO users(id,email,password_hash,name,is_superadmin,status) VALUES($1,$2,$3,$4,true,'active')`,
      [uuidv4(), 'founder@vidyatrack.in', hash, 'Platform Owner'],
    );
  } else {
    await ds.query(`UPDATE users SET password_hash=$2, is_superadmin=true WHERE id=$1`, [existingSA.id, hash]);
  }

  console.log('Wiping previous demo data for', SCHOOL_CODE);
  await wipeDemo(SID);

  const [{ today }] = await ds.query(`SELECT CURRENT_DATE::text as today`);
  const todayDate = new Date(`${today}T00:00:00Z`);

  // ───── admin user + role ─────
  const adminId = uuidv4();
  await ds.query(
    `INSERT INTO users(id,phone,email,password_hash,name,status)
     VALUES($1,$2,$3,$4,$5,'active') ON CONFLICT(phone) DO UPDATE SET password_hash=EXCLUDED.password_hash`,
    [adminId, '9999900001', 'admin@demo.vidyatrack.in', hash, 'Admin User'],
  );
  const [admin] = await ds.query(`SELECT id FROM users WHERE phone='9999900001'`);
  await ds.query(
    `INSERT INTO user_roles(id,user_id,school_id,role) VALUES($1,$2,$3,'admin')
     ON CONFLICT(user_id,school_id,role) DO NOTHING`,
    [uuidv4(), admin.id, SID],
  );

  // ───── teachers ─────
  const teacherIds: string[] = [];
  for (const t of TEACHERS) {
    const uid = uuidv4();
    await ds.query(
      `INSERT INTO users(id,phone,email,password_hash,name,status)
       VALUES($1,$2,$3,$4,$5,'active') ON CONFLICT(phone) DO UPDATE SET password_hash=EXCLUDED.password_hash, name=EXCLUDED.name`,
      [uid, t.phone, `${t.code.toLowerCase()}@demo.vidyatrack.in`, hash, t.name],
    );
    const [u] = await ds.query(`SELECT id FROM users WHERE phone=$1`, [t.phone]);
    const tid = uuidv4();
    await ds.query(
      `INSERT INTO teachers(id,school_id,user_id,employee_code,designation,subjects,status)
       VALUES($1,$2,$3,$4,'Class Teacher',$5,'active')
       ON CONFLICT(school_id,user_id) DO UPDATE SET employee_code=EXCLUDED.employee_code RETURNING id`,
      [tid, SID, u.id, t.code, t.subjects],
    );
    const [teacher] = await ds.query(`SELECT id FROM teachers WHERE school_id=$1 AND user_id=$2`, [SID, u.id]);
    teacherIds.push(teacher.id);
    await ds.query(
      `INSERT INTO user_roles(id,user_id,school_id,role,linked_entity_id)
       VALUES($1,$2,$3,'teacher',$4) ON CONFLICT(user_id,school_id,role) DO UPDATE SET linked_entity_id=EXCLUDED.linked_entity_id`,
      [uuidv4(), u.id, SID, teacher.id],
    );
  }

  // ───── classes, sections, students ─────
  const sectionIds: string[] = [];
  const allStudentIds: string[] = [];
  let admissionSeq = 0;

  for (let ci = 0; ci < CLASSES.length; ci++) {
    const cid = uuidv4();
    await ds.query(
      `INSERT INTO classes(id,school_id,name,order_no) VALUES($1,$2,$3,$4) ON CONFLICT(school_id,name) DO NOTHING`,
      [cid, SID, CLASSES[ci], ci],
    );
    const [cls] = await ds.query(`SELECT id FROM classes WHERE school_id=$1 AND name=$2`, [SID, CLASSES[ci]]);

    for (const sec of SECTIONS) {
      const sid = uuidv4();
      await ds.query(
        `INSERT INTO sections(id,class_id,school_id,name) VALUES($1,$2,$3,$4) ON CONFLICT(class_id,name) DO NOTHING`,
        [sid, cls.id, SID, sec],
      );
      const [section] = await ds.query(`SELECT id FROM sections WHERE class_id=$1 AND name=$2`, [cls.id, sec]);
      sectionIds.push(section.id);

      // 40 students for this section, batched into one INSERT.
      const rows: string[] = [];
      const params: any[] = [];
      const sectionStudentIds: string[] = [];
      for (let r = 0; r < STUDENTS_PER_SECTION; r++) {
        admissionSeq++;
        const studId = uuidv4();
        sectionStudentIds.push(studId);
        allStudentIds.push(studId);
        const name = `${FIRST_NAMES[r % FIRST_NAMES.length]} ${LAST_NAMES[(r + ci) % LAST_NAMES.length]}`;
        const gender = r % 2 === 0 ? 'M' : 'F';
        const admissionNo = `2026${String(admissionSeq).padStart(4, '0')}`;
        const base = params.length;
        rows.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},$${base + 7},'active','2026-04-01')`);
        params.push(studId, SID, section.id, admissionNo, r + 1, name, gender);
      }
      await ds.query(
        `INSERT INTO students(id,school_id,section_id,admission_no,roll_no,name,gender,status,admission_date)
         VALUES ${rows.join(',')}`,
        params,
      );
    }
  }
  console.log(`Created ${sectionIds.length} sections, ${allStudentIds.length} students`);

  // ───── demo parent linked to the first student ─────
  const parentId = uuidv4();
  await ds.query(
    `INSERT INTO users(id,phone,password_hash,name,status)
     VALUES($1,$2,$3,$4,'active') ON CONFLICT(phone) DO UPDATE SET password_hash=EXCLUDED.password_hash`,
    [parentId, '9999900003', hash, 'Ramesh Sharma (Parent)'],
  );
  const [parentUser] = await ds.query(`SELECT id FROM users WHERE phone='9999900003'`);
  const firstStudentId = allStudentIds[0];
  await ds.query(`UPDATE students SET guardian_user_id=$1 WHERE id=$2`, [parentUser.id, firstStudentId]);
  await ds.query(
    `INSERT INTO user_roles(id,user_id,school_id,role,linked_entity_id)
     VALUES($1,$2,$3,'parent',$4) ON CONFLICT(user_id,school_id,role) DO UPDATE SET linked_entity_id=EXCLUDED.linked_entity_id`,
    [uuidv4(), parentUser.id, SID, firstStudentId],
  );

  // ───── attendance: last N days (skip Sundays) ─────
  // Build the list of working dates, oldest → newest, ending today.
  const dates: Date[] = [];
  for (let back = ATTENDANCE_DAYS; back >= 0; back--) {
    const d = new Date(todayDate);
    d.setUTCDate(d.getUTCDate() - back);
    if (d.getUTCDay() === 0) continue; // skip Sunday
    dates.push(d);
  }

  // Map sectionId → its 40 student ids (in roll order)
  const sectionStudents: Record<string, { id: string; idx: number }[]> = {};
  for (const secId of sectionIds) {
    const studs = await ds.query(
      `SELECT id, roll_no FROM students WHERE section_id=$1 AND status='active' ORDER BY roll_no`,
      [secId],
    );
    sectionStudents[secId] = studs.map((s: any, i: number) => ({ id: s.id, idx: i }));
  }

  let sessionCount = 0;
  for (let di = 0; di < dates.length; di++) {
    const dateStr = fmtDate(dates[di]);
    for (const secId of Object.keys(sectionStudents)) {
      const studs = sectionStudents[secId];
      const sessionId = uuidv4();
      await ds.query(
        `INSERT INTO attendance_sessions(id,school_id,section_id,date,session,marked_by,marked_at)
         VALUES($1,$2,$3,$4,'full_day',$5,$6)`,
        [sessionId, SID, secId, dateStr, admin.id, `${dateStr}T09:30:00Z`],
      );

      const recRows: string[] = [];
      const recParams: any[] = [];
      const counts = { present: 0, absent: 0, late: 0, leave: 0 };
      for (const s of studs) {
        const status = statusFor(s.idx, di);
        (counts as any)[status]++;
        const base = recParams.length;
        recRows.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4})`);
        recParams.push(uuidv4(), sessionId, s.id, status);
      }
      await ds.query(
        `INSERT INTO attendance_records(id,session_id,student_id,status) VALUES ${recRows.join(',')}`,
        recParams,
      );

      await ds.query(
        `INSERT INTO daily_attendance_summary(id,school_id,section_id,date,total_students,present,absent,late,on_leave,updated_at)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW())
         ON CONFLICT(school_id,section_id,date) DO UPDATE SET
           total_students=EXCLUDED.total_students,present=EXCLUDED.present,
           absent=EXCLUDED.absent,late=EXCLUDED.late,on_leave=EXCLUDED.on_leave,updated_at=NOW()`,
        [uuidv4(), SID, secId, dateStr, studs.length, counts.present, counts.absent, counts.late, counts.leave],
      );
      sessionCount++;
    }

    // teacher attendance for the same day (mostly present)
    const tRows: string[] = [];
    const tParams: any[] = [];
    for (let ti = 0; ti < teacherIds.length; ti++) {
      const h = (ti * 13 + di * 7) % 100;
      const status = h < 92 ? 'present' : h < 97 ? 'absent' : 'leave';
      const base = tParams.length;
      tRows.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6})`);
      tParams.push(uuidv4(), SID, teacherIds[ti], dateStr, status, admin.id);
    }
    await ds.query(
      `INSERT INTO teacher_attendance(id,school_id,teacher_id,date,status,marked_by) VALUES ${tRows.join(',')}
       ON CONFLICT(school_id,teacher_id,date) DO NOTHING`,
      tParams,
    );
  }
  console.log(`Created ${sessionCount} attendance sessions over ${dates.length} working days`);

  // ───── fees: heads, invoices (3 months), payments dated today ─────
  const feeHeads = [
    { name: 'Tuition Fee', amount: 1500, frequency: 'monthly' },
    { name: 'Transport Fee', amount: 800, frequency: 'monthly' },
    { name: 'Annual Charges', amount: 5000, frequency: 'annual' },
  ];
  for (const fh of feeHeads) {
    await ds.query(
      `INSERT INTO fee_heads(id,school_id,name,amount,frequency) VALUES($1,$2,$3,$4,$5)`,
      [uuidv4(), SID, fh.name, fh.amount, fh.frequency],
    );
  }
  const MONTHLY_DUE = 2300; // tuition + transport

  // First day of current month and the two prior months
  const monthStart = (offset: number) => {
    const d = new Date(Date.UTC(todayDate.getUTCFullYear(), todayDate.getUTCMonth() - offset, 1));
    return fmtDate(d);
  };
  const months = [monthStart(2), monthStart(1), monthStart(0)]; // oldest → current

  // Build invoices for every student × 3 months (batched per month).
  const invoiceIdByStudentMonth: Record<string, string> = {};
  for (let m = 0; m < months.length; m++) {
    const rows: string[] = [];
    const params: any[] = [];
    for (const studId of allStudentIds) {
      const invId = uuidv4();
      invoiceIdByStudentMonth[`${studId}:${m}`] = invId;
      const dueDate = months[m].replace(/-01$/, '-10');
      const base = params.length;
      rows.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},'pending')`);
      params.push(invId, SID, studId, months[m], MONTHLY_DUE, dueDate);
    }
    await ds.query(
      `INSERT INTO fee_invoices(id,school_id,student_id,month,due_amount,due_date,status) VALUES ${rows.join(',')}`,
      params,
    );
  }

  // Payments recorded TODAY so the Daily Revenue card is non-zero.
  //  - 20 students pay their current-month invoice (some with fine/discount)
  //  - 12 students also clear an older (back-due) month today
  const payRows: string[] = [];
  const payParams: any[] = [];
  const paidInvoiceIds: string[] = [];
  for (let i = 0; i < 20; i++) {
    const studId = allStudentIds[i];
    const invId = invoiceIdByStudentMonth[`${studId}:2`]; // current month
    paidInvoiceIds.push(invId);
    const fine = i % 5 === 0 ? 50 : 0;
    const discount = i % 7 === 0 ? 100 : 0;
    const mode = i % 2 === 0 ? 'upi' : 'cash';
    const base = payParams.length;
    payRows.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},$${base + 7},$${base + 8},$${base + 9},NOW())`);
    payParams.push(uuidv4(), invId, SID, MONTHLY_DUE, mode, fine, discount, admin.id, `RCP${Date.now()}${i}`);
  }
  for (let i = 0; i < 12; i++) {
    const studId = allStudentIds[i];
    const invId = invoiceIdByStudentMonth[`${studId}:0`]; // oldest month → back due
    paidInvoiceIds.push(invId);
    const base = payParams.length;
    payRows.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},'cash',0,0,$${base + 5},$${base + 6},NOW())`);
    payParams.push(uuidv4(), invId, SID, MONTHLY_DUE, admin.id, `RCPB${Date.now()}${i}`);
  }
  await ds.query(
    `INSERT INTO fee_payments(id,invoice_id,school_id,amount,mode,fine,discount,received_by,receipt_no,paid_at)
     VALUES ${payRows.join(',')}`,
    payParams,
  );
  // Mark those invoices paid
  await ds.query(`UPDATE fee_invoices SET status='paid', updated_at=NOW() WHERE id = ANY($1::uuid[])`, [paidInvoiceIds]);

  // An expense today so the Expense line is non-zero.
  await ds.query(
    `INSERT INTO expenses(id,school_id,category,amount,note,spent_by,date) VALUES($1,$2,'Stationery',2000,'Whiteboard markers & registers',$3,CURRENT_DATE)`,
    [uuidv4(), SID, admin.id],
  );

  // Roll up today's revenue into daily_revenue_summary (what the dashboard reads).
  // Cast required: the function is refresh_daily_revenue(uuid) and a bare $1 is untyped.
  await ds.query(`SELECT refresh_daily_revenue($1::uuid)`, [SID]);

  const [rev] = await ds.query(`SELECT amount_received, back_due, fine_received, discount, expense, total_revenue FROM daily_revenue_summary WHERE school_id=$1`, [SID]);

  await ds.destroy();
  console.log('\n✅  Demo seed complete');
  console.log(`   School Code : ${SCHOOL_CODE}`);
  console.log(`   Classes     : ${CLASSES.join(', ')}  × sections ${SECTIONS.join(', ')}  (40 students each)`);
  console.log(`   Students    : ${allStudentIds.length}`);
  console.log(`   Teachers    : ${TEACHERS.length}`);
  console.log(`   Attendance  : ${dates.length} working days seeded`);
  console.log(`   Daily revenue today → received ₹${rev?.amount_received}, back-due ₹${rev?.back_due}, fine ₹${rev?.fine_received}, discount ₹${rev?.discount}, expense ₹${rev?.expense}, total ₹${rev?.total_revenue}`);
  console.log('   Logins (password Demo@1234):');
  console.log('     Admin   phone=9999900001');
  console.log('     Teacher phone=9999900002 .. 9999900007');
  console.log('     Parent  phone=9999900003');
}

run().catch((e) => { console.error(e); process.exit(1); });
