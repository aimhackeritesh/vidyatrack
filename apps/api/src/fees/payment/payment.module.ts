import { Module } from '@nestjs/common';
import { PAYMENT_GATEWAY } from './payment-gateway.interface';
import { MockGateway } from './mock-gateway';
import { RazorpayGateway } from './razorpay-gateway';

@Module({
  providers: [
    {
      provide: PAYMENT_GATEWAY,
      useClass: process.env.PAYMENT_MODE === 'razorpay' ? RazorpayGateway : MockGateway,
    },
  ],
  exports: [PAYMENT_GATEWAY],
})
export class PaymentModule {}
