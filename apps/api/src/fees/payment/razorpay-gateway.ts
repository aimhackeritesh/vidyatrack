import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';
import Razorpay from 'razorpay';
import { CreateOrderParams, GatewayOrder, PaymentGateway, VerifyPaymentParams } from './payment-gateway.interface';

/** PAYMENT_MODE=razorpay — real order creation + HMAC signature verification against test/live keys. */
@Injectable()
export class RazorpayGateway implements PaymentGateway {
  private readonly client = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID || '',
    key_secret: process.env.RAZORPAY_KEY_SECRET || '',
  });

  async createOrder({ amount, receiptId, notes }: CreateOrderParams): Promise<GatewayOrder> {
    const order = await this.client.orders.create({
      amount: Math.round(amount * 100), // paise
      currency: 'INR',
      receipt: receiptId,
      notes,
    });
    return { orderId: order.id, amount, currency: 'INR', keyId: process.env.RAZORPAY_KEY_ID };
  }

  async verifyPayment({ orderId, paymentId, signature }: VerifyPaymentParams): Promise<boolean> {
    const expected = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '')
      .update(`${orderId}|${paymentId}`)
      .digest('hex');
    return expected === signature;
  }

  verifyWebhookSignature(rawBody: string, signature: string): boolean {
    const expected = crypto
      .createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET || '')
      .update(rawBody)
      .digest('hex');
    return expected === signature;
  }
}
