import { BadRequestException, Injectable } from '@nestjs/common';
import { LocalStorageDriver } from './local-storage.driver';
import { S3StorageDriver } from './s3-storage.driver';
import { ALLOWED_MIME_TYPES, StoredFile } from './storage.types';

@Injectable()
export class StorageService {
  private readonly driver =
    process.env.STORAGE_MODE === 's3' ? new S3StorageDriver() : new LocalStorageDriver();

  async save(file: Express.Multer.File, folder: string): Promise<StoredFile> {
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      throw new BadRequestException(`Unsupported file type: ${file.mimetype}`);
    }
    return this.driver.save(file.buffer, file.originalname, file.mimetype, folder);
  }
}
