import { Injectable } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { CreateOrderParams, GatewayOrder, PaymentGateway, VerifyPaymentParams } from './payment-gateway.interface';

/**
 * Demo/dev default (PAYMENT_MODE=mock, no live merchant keys needed). Simulates
 * a real gateway's shape (orderId → client "pays" → verify) so the full parent
 * pay-fees flow is demoable end-to-end. It is intentionally NOT cryptographically
 * verified — any non-empty paymentId against a mock order is accepted. Swap to
 * RazorpayGateway (real HMAC signature verification) via PAYMENT_MODE=razorpay
 * once merchant test/live keys exist; nothing above this class needs to change.
 */
@Injectable()
export class MockGateway implements PaymentGateway {
  async createOrder({ amount, receiptId }: CreateOrderParams): Promise<GatewayOrder> {
    return { orderId: `mock_order_${uuidv4()}`, amount, currency: 'INR' };
  }

  async verifyPayment({ orderId, paymentId }: VerifyPaymentParams): Promise<boolean> {
    return orderId.startsWith('mock_order_') && !!paymentId;
  }

  verifyWebhookSignature(): boolean {
    return true; // no real webhooks in mock mode
  }
}
