import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { StorageDriver, StoredFile } from './storage.types';

/**
 * Stub adapter — same StorageDriver interface as LocalStorageDriver, so
 * switching STORAGE_MODE=s3 is a one-line change once S3_ACCESS_KEY /
 * S3_SECRET_KEY / S3_BUCKET / S3_ENDPOINT (already stubbed in .env) are
 * filled in and @aws-sdk/client-s3 is added as a dependency.
 */
@Injectable()
export class S3StorageDriver implements StorageDriver {
  async save(_buffer: Buffer, _filename: string, _mimetype: string, _folder: string): Promise<StoredFile> {
    throw new InternalServerErrorException(
      'S3 storage is not configured yet. Set STORAGE_MODE=local, or install @aws-sdk/client-s3 and fill in S3_* env vars.',
    );
  }
}
