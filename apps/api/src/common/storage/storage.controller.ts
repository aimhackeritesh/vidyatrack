import { BadRequestException, Controller, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { Roles, RolesGuard } from '../guards/roles.guard';
import { CurrentUser } from '../decorators/current-user.decorator';
import { StorageService } from './storage.service';
import { MAX_UPLOAD_BYTES } from './storage.types';

@ApiTags('uploads')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('uploads')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  @Post()
  @Roles('admin', 'teacher', 'superadmin')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES } }))
  async upload(@UploadedFile() file: Express.Multer.File, @CurrentUser() u: any) {
    if (!file) throw new BadRequestException('No file uploaded');
    const folder = u.schoolId ?? 'platform';
    return this.storage.save(file, folder);
  }
}
