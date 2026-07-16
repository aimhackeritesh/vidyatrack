export interface CreateOrderParams {
  amount: number;        // rupees
  receiptId: string;     // our invoice/receipt reference, echoed back by the gateway
  notes?: Record<string, string>;
}

export interface GatewayOrder {
  orderId: string;
  amount: number;
  currency: string;
  keyId?: string;        // public key the Flutter client needs to open checkout (razorpay mode only)
}

export interface VerifyPaymentParams {
  orderId: string;
  paymentId: string;
  signature: string;
}

export const PAYMENT_GATEWAY = 'PAYMENT_GATEWAY';

export interface PaymentGateway {
  createOrder(params: CreateOrderParams): Promise<GatewayOrder>;
  /** Server-side check that a client-reported payment is genuine. Never trust the client without this. */
  verifyPayment(params: VerifyPaymentParams): Promise<boolean>;
  verifyWebhookSignature(rawBody: string, signature: string): boolean;
}
