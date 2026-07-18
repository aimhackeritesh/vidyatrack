import { Module } from '@nestjs/common';
import { PAYMENT_GATEWAY } from './payment-gateway.interface';
import { MockGateway } from './mock-gateway';

@Module({
  providers: [{ provide: PAYMENT_GATEWAY, useClass: MockGateway }],
  exports: [PAYMENT_GATEWAY],
})
export class PaymentModule {}
