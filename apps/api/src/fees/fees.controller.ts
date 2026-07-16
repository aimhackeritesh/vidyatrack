import { Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FeesService } from './fees.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('fees')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('fees')
export class FeesController {
  constructor(private readonly svc: FeesService) {}

  @Get('heads') @Roles('admin') feeHeads(@CurrentUser() u: any) { return this.svc.getFeeHeads(u.schoolId); }
  @Post('heads') @Roles('admin') createFeeHead(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createFeeHead(u.schoolId, dto); }
  @Put('heads/:id') @Roles('admin') updateFeeHead(@CurrentUser() u: any, @Param('id') id: string, @Body() dto: any) { return this.svc.updateFeeHead(u.schoolId, id, dto); }
  @Delete('heads/:id') @Roles('admin') deleteFeeHead(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.deleteFeeHead(u.schoolId, id); }

  @Post('invoices/generate')
  @Roles('admin')
  @ApiOperation({ summary: 'Generate/refresh this month\'s invoices from the fee structure (idempotent)' })
  generateInvoices(@CurrentUser() u: any, @Body() dto: any) { return this.svc.generateInvoices(u.schoolId, u.id, dto.month, dto.classId); }
  @Post('payments') @Roles('admin') collect(@CurrentUser() u: any, @Body() dto: any) { return this.svc.collectPayment(u.schoolId, u.id, dto); }
  @Get('dues') @Roles('admin', 'parent') dues(@CurrentUser() u: any, @Query('studentId') sid: string) { return this.svc.getStudentDues(u.schoolId, u, sid); }
  @Get('my-dues') @Roles('parent', 'student') @ApiOperation({ summary: "Caller's own/child outstanding + paid invoices, ownership-scoped" })
  myDues(@CurrentUser() u: any) { return this.svc.getMyDues(u.schoolId, u); }
  @Get('invoice/:id') @Roles('admin', 'teacher', 'parent', 'student') invoiceDetail(@CurrentUser() u: any, @Param('id') id: string) { return this.svc.getInvoiceDetail(u.schoolId, u, id); }
  @Get('daily-revenue') @Roles('admin') dailyRevenue(@CurrentUser() u: any) { return this.svc.getDailyRevenue(u.schoolId); }

  @Post('pay/order')
  @Roles('parent', 'student')
  @ApiOperation({ summary: 'Create a gateway order for an invoice (amount clamped to remaining balance)' })
  createPayOrder(@CurrentUser() u: any, @Body() dto: any) { return this.svc.createPaymentOrder(u.schoolId, u, dto.invoiceId, dto.amount); }

  @Post('pay/verify')
  @Roles('parent', 'student')
  @ApiOperation({ summary: 'Server-side verify a gateway payment and record it (idempotent)' })
  verifyPayment(@CurrentUser() u: any, @Body() dto: any) { return this.svc.verifyPayment(u.schoolId, u, dto); }

  @Get('receipt/:paymentId') @Roles('admin', 'teacher', 'parent', 'student') receipt(@CurrentUser() u: any, @Param('paymentId') paymentId: string) { return this.svc.getReceipt(u.schoolId, u, paymentId); }

  @Post('income')
  @Roles('admin')
  @ApiOperation({ summary: 'Add other (non-fee) income — reflects immediately in Daily Revenue' })
  addIncome(@CurrentUser() u: any, @Body() dto: any) { return this.svc.addIncome(u.schoolId, u.id, dto); }

  @Post('expenses') @Roles('admin') addExpense(@CurrentUser() u: any, @Body() dto: any) { return this.svc.addExpense(u.schoolId, u.id, dto); }

  @Post('void')
  @Roles('admin')
  @ApiOperation({ summary: 'Void a payment/income/expense entry (audit-logged)' })
  voidEntry(@CurrentUser() u: any, @Body() dto: any) { return this.svc.voidEntry(u.schoolId, u.id, dto.kind, dto.id, dto.reason); }

  @Get('today') @Roles('admin') today(@CurrentUser() u: any) { return this.svc.listToday(u.schoolId); }

  @Get('revenue-range')
  @Roles('admin')
  @ApiOperation({ summary: 'Daily received/expense/net series for the Total Revenue graph' })
  revenueRange(@CurrentUser() u: any, @Query('from') from: string, @Query('to') to: string) {
    const today = new Date().toISOString().split('T')[0];
    return this.svc.getRevenueRange(u.schoolId, from ?? today, to ?? today);
  }
}
