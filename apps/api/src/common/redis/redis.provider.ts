import { Inject, Provider } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';

export const REDIS_CLIENT = 'REDIS_CLIENT';

export const RedisProvider: Provider = {
  provide: REDIS_CLIENT,
  inject: [ConfigService],
  useFactory: (cfg: ConfigService) => new Redis(cfg.get<string>('REDIS_URL') || 'redis://localhost:6379'),
};

// Parameter decorator that resolves the shared Redis client by its DI token.
export const InjectRedis = () => Inject(REDIS_CLIENT);
