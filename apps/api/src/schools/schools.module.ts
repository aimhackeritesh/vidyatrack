import { Module } from '@nestjs/common';
import { SchoolsController } from './schools.controller';
import { SchoolsService } from './schools.service';
import { SchoolConfigModule } from '../config/school-config.module';
@Module({ imports: [SchoolConfigModule], controllers: [SchoolsController], providers: [SchoolsService] })
export class SchoolsModule {}
