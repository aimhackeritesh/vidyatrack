import { Module } from '@nestjs/common';
import { FeesController } from './fees.controller';
import { FeesService } from './fees.service';
import { PaymentModule } from './payment/payment.module';
@Module({ imports: [PaymentModule], controllers: [FeesController], providers: [FeesService] })
export class FeesModule {}
