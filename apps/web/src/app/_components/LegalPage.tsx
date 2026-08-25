import Link from 'next/link';

export function LegalPage({
  title, updated, children,
}: { title: string; updated: string; children: React.ReactNode }) {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16 md:py-24">
      <Link href="/" className="text-sm text-ink-soft hover:text-ink">← VidyaTrack</Link>
      <h1 className="mt-10 font-display text-title font-700">{title}</h1>
      <p className="mt-4 text-sm text-ink-faint">Last updated {updated}</p>
      <div className="legal mt-14 space-y-10">{children}</div>
      <footer className="mt-20 border-t border-line pt-8 text-sm text-ink-faint">
        Questions: <a href="mailto:support@vidyatrack.in" className="underline hover:text-ink">support@vidyatrack.in</a>
      </footer>
    </main>
  );
}

export function Section({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="font-display text-xl font-600">{heading}</h2>
      <div className="mt-4 max-w-prose space-y-4 leading-relaxed text-ink-soft">{children}</div>
    </section>
  );
}
