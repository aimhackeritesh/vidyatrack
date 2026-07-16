import { Injectable } from '@nestjs/common';
import { promises as fs } from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { StorageDriver, StoredFile } from './storage.types';

/**
 * Writes to <api-root>/uploads/<folder>/<uuid>-<safe-name>, served statically
 * at /uploads/* by main.ts (useStaticAssets). Swap for an S3StorageDriver
 * behind the same StorageDriver interface once cloud credentials exist —
 * nothing above StorageService needs to change.
 */
@Injectable()
export class LocalStorageDriver implements StorageDriver {
  private readonly root = path.join(process.cwd(), 'uploads');

  async save(buffer: Buffer, filename: string, mimetype: string, folder: string): Promise<StoredFile> {
    const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_').slice(-100);
    const key = `${folder}/${uuidv4()}-${safeName}`;
    const fullPath = path.join(this.root, key);

    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, buffer);

    const baseUrl = process.env.APP_URL || 'http://localhost:3000';
    return {
      url: `${baseUrl}/uploads/${key}`,
      key,
      type: mimetype,
      size: buffer.length,
    };
  }
}
