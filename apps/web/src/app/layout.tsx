import type { Metadata } from 'next';
import { Fraunces, Inter } from 'next/font/google';
import './globals.css';

const display = Fraunces({ subsets: ['latin'], variable: '--font-display', weight: ['600', '700'], display: 'swap' });
const sans = Inter({ subsets: ['latin'], variable: '--font-sans', display: 'swap' });

export const metadata: Metadata = {
  title: 'VidyaTrack — School management for small Indian schools',
  description:
    'Attendance, fees, homework and parent communication for schools running on paper registers and WhatsApp groups. Try the live demo, no signup.',
  openGraph: {
    title: 'VidyaTrack — School management for small Indian schools',
    description: 'Attendance, fees, homework and parent communication. Try the live demo, no signup.',
    type: 'website',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${sans.variable}`}>
      <body className="bg-paper font-sans text-ink antialiased">{children}</body>
    </html>
  );
}
