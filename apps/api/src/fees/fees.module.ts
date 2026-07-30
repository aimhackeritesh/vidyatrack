import { Module } from '@nestjs/common';
import { FeesController } from './fees.controller';
import { FeesService } from './fees.service';
import { PaymentModule } from './payment/payment.module';
import { SchoolConfigModule } from '../config/school-config.module';
@Module({ imports: [PaymentModule, SchoolConfigModule], controllers: [FeesController], providers: [FeesService] })
export class FeesModule {}
