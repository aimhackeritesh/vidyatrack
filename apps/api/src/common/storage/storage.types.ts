export interface StoredFile {
  url: string;
  key: string;
  type: string;
  size: number;
}

export interface StorageDriver {
  save(buffer: Buffer, filename: string, mimetype: string, folder: string): Promise<StoredFile>;
}

/** 15 MB — generous enough for a syllabus PDF or a scanned homework sheet. */
export const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;

export const ALLOWED_MIME_TYPES = [
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/jpg',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
];
