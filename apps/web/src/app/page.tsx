import Link from 'next/link';

const APK = 'https://github.com/aimhackeritesh/vidyatrack/releases/latest';
const REPO = 'https://github.com/aimhackeritesh/vidyatrack';

/** Real roles from the product — four shells, not padded to a tidy three. */
const ROLES = [
  {
    who: 'Principal / Admin',
    does: 'Sets the fee structure, generates monthly invoices, tracks daily collection, adds students and staff, publishes notices, approves leave.',
  },
  {
    who: 'Teacher',
    does: 'Marks attendance for a whole section in one pass — works offline and syncs later — assigns homework, uploads material, enters exam marks.',
  },
  {
    who: 'Parent',
    does: 'Sees their child’s attendance, timetable, homework, results and syllabus, checks pending fees and pays in the app, applies for leave.',
  },
  {
    who: 'Student',
    does: 'Today’s timetable, homework due, study material, syllabus and their own attendance record.',
  },
];

export default function Landing() {
  return (
    <main>
      {/* ── Nav ─────────────────────────────────────────────────────── */}
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-7">
        <span className="font-display text-xl font-700 tracking-tight">VidyaTrack</span>
        <nav className="flex items-center gap-7 text-sm text-ink-soft">
          <a href={REPO} className="hidden hover:text-ink sm:inline">Source</a>
          <Link href="/console" className="hover:text-ink">Console</Link>
        </nav>
      </header>

      {/* ── Hero ────────────────────────────────────────────────────── */}
      <section className="mx-auto max-w-6xl px-6 pb-24 pt-16 md:pb-36 md:pt-24">
        <p className="text-eyebrow font-medium uppercase text-brand">For schools of 100–500 students</p>
        <h1 className="mt-6 max-w-4xl font-display text-display font-700">
          Your school runs on paper registers and WhatsApp groups.
          <span className="text-ink-faint"> It doesn’t have to.</span>
        </h1>
        <p className="mt-8 max-w-prose text-lg leading-relaxed text-ink-soft">
          Attendance, fees, homework, results and parent updates — in one app for staff and
          one for parents. Built for schools that never had the budget or the patience for a
          full school ERP.
        </p>

        <div className="mt-11 flex flex-wrap items-center gap-4">
          <Link
            href="/console"
            className="rounded-md bg-brand px-7 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-navy"
          >
            Open the live demo
          </Link>
          <a
            href={APK}
            className="rounded-md border border-line px-7 py-3.5 text-sm font-semibold text-ink transition-colors hover:border-ink"
          >
            Download the Android app
          </a>
          <span className="text-sm text-ink-faint">No signup. Demo data resets.</span>
        </div>
      </section>

      {/* ── The problem — one large editorial statement, not a card ──── */}
      <section className="border-y border-line bg-paper-deep">
        <div className="mx-auto max-w-6xl px-6 py-24 md:py-32">
          <div className="grid gap-12 md:grid-cols-12">
            <h2 className="font-display text-title font-600 md:col-span-7">
              Fee registers go missing. Attendance lives in a notebook. Parents find out about
              a test the night before.
            </h2>
            <div className="max-w-prose space-y-5 text-ink-soft md:col-span-5">
              <p>
                The alternative has usually been enterprise school software priced and designed
                for large private schools — months of onboarding, trained operators, and an
                interface no parent will open twice.
              </p>
              <p className="text-ink">
                VidyaTrack is the small version of that. A principal can set it up in a morning.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── Roles — a list with one alignment axis, not a card grid ──── */}
      <section className="mx-auto max-w-6xl px-6 py-24 md:py-32">
        <p className="text-eyebrow font-medium uppercase text-ink-faint">One system, four points of view</p>
        <dl className="mt-12 divide-y divide-line border-t border-line">
          {ROLES.map((r) => (
            <div key={r.who} className="grid gap-3 py-8 md:grid-cols-12 md:gap-10">
              <dt className="font-display text-xl font-600 md:col-span-4">{r.who}</dt>
              <dd className="max-w-prose leading-relaxed text-ink-soft md:col-span-8">{r.does}</dd>
            </div>
          ))}
        </dl>
      </section>

      {/* ── Try it — the differentiator, given the one dark surface ──── */}
      <section className="bg-navy text-white">
        <div className="mx-auto max-w-6xl px-6 py-24 md:py-32">
          <div className="grid gap-14 md:grid-cols-12">
            <div className="md:col-span-5">
              <h2 className="font-display text-title font-600">Try it in thirty seconds</h2>
              <p className="mt-6 max-w-prose leading-relaxed text-white/70">
                Nothing to install to look around, and no sales call. The demo school has 240
                students, a month of attendance, and real fee records.
              </p>
              <Link
                href="/console"
                className="mt-9 inline-block rounded-md bg-white px-7 py-3.5 text-sm font-semibold text-navy transition-colors hover:bg-brand-wash"
              >
                Open the console
              </Link>
            </div>

            <div className="md:col-span-7">
              <div className="rounded-xl border border-white/15 p-7">
                <p className="text-eyebrow font-medium uppercase text-white/50">Demo sign-in</p>
                <dl className="mt-6 space-y-5 text-sm">
                  <div className="flex flex-wrap justify-between gap-2 border-b border-white/10 pb-5">
                    <dt className="text-white/60">Web console (owner)</dt>
                    <dd className="font-mono">founder@vidyatrack.in · Demo@1234</dd>
                  </div>
                  <div className="flex flex-wrap justify-between gap-2 border-b border-white/10 pb-5">
                    <dt className="text-white/60">School code</dt>
                    <dd className="font-mono">VDTRK2627DEMO01</dd>
                  </div>
                  <div className="flex flex-wrap justify-between gap-2">
                    <dt className="text-white/60">App — principal / teacher / parent</dt>
                    <dd className="font-mono text-right">9999900001 / …02 / …03 · Demo@1234</dd>
                  </div>
                </dl>
              </div>
              <p className="mt-5 text-sm leading-relaxed text-white/50">
                This is a public demo: fee payments are simulated, uploaded files are cleared on
                each deploy, and the data resets — so treat it as a showroom, not a school.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── Footer ──────────────────────────────────────────────────── */}
      <footer className="mx-auto max-w-6xl px-6 py-16">
        <div className="flex flex-wrap items-center justify-between gap-6 border-t border-line pt-10 text-sm text-ink-faint">
          <p>© {new Date().getFullYear()} VidyaTrack</p>
          <nav className="flex flex-wrap gap-7">
            <Link href="/privacy" className="hover:text-ink">Privacy</Link>
            <Link href="/terms" className="hover:text-ink">Terms</Link>
            <a href={REPO} className="hover:text-ink">Source</a>
            <a href="mailto:support@vidyatrack.in" className="hover:text-ink">support@vidyatrack.in</a>
          </nav>
        </div>
      </footer>
    </main>
  );
}
