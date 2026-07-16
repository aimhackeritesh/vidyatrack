import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
dotenv.config();

// Migrations run DDL and must bypass RLS, so prefer the admin/superuser URL.
export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_ADMIN_URL || process.env.DATABASE_URL,
  synchronize: false,
  logging: false,
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/migrations/*{.ts,.js}'],
});
