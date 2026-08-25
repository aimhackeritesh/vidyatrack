import type { Metadata } from 'next';
import { LegalPage, Section } from '../_components/LegalPage';

export const metadata: Metadata = {
  title: 'Privacy Policy — VidyaTrack',
  description: 'How VidyaTrack handles student, guardian and staff data.',
};

export default function Privacy() {
  return (
    <LegalPage title="Privacy Policy" updated="25 August 2026">
      <Section heading="Who controls the data">
        <p>
          VidyaTrack is software supplied to a school. The <strong className="text-ink">school</strong> decides what
          information is entered and why, and is the data fiduciary (controller) for it. VidyaTrack
          stores and processes that information on the school’s behalf and on its instructions, as a
          data processor.
        </p>
        <p>
          If you are a parent, student or staff member and want your information corrected or removed,
          please contact your school first — they administer the account. We will act on requests the
          school passes to us.
        </p>
      </Section>

      <Section heading="What we store">
        <p>Entered by the school, and only what a school record normally contains:</p>
        <ul className="list-disc space-y-2 pl-5">
          <li><strong className="text-ink">Students</strong> — name, admission number, class and section, date of birth, gender, optional photograph, attendance, exam marks, homework and fee records.</li>
          <li><strong className="text-ink">Parents and guardians</strong> — name and mobile number, and the fee payments recorded against their child.</li>
          <li><strong className="text-ink">Staff</strong> — name, mobile number, employee code, subjects and attendance.</li>
          <li><strong className="text-ink">Account data</strong> — the login identifier and a cryptographic hash of the password. We never store passwords themselves.</li>
        </ul>
        <p>
          We do not collect location, contacts, device identifiers for advertising, or any data from a
          phone beyond what a user types into the app.
        </p>
      </Section>

      <Section heading="Children’s information">
        <p>
          The app records information about children because that is what a school register contains.
          That information is entered by the school and its staff — never collected directly from a
          child, and the app shows a child only their own records.
        </p>
        <p>
          Under India’s Digital Personal Data Protection Act, consent for processing a child’s data is
          obtained by the school from the parent or guardian as part of admission. VidyaTrack does not
          profile children, does not show advertising, and does not use any of this information for
          marketing.
        </p>
      </Section>

      <Section heading="How it is used">
        <p>
          Only to provide the service: recording attendance, producing fee invoices and receipts,
          publishing homework, timetables and results, and sending in-app notices to the right people
          at that school. We do not sell data, share it with advertisers, or use it to train models.
        </p>
      </Section>

      <Section heading="Separation between schools">
        <p>
          Each school’s records are isolated at the database level, not only in application code.
          Every request runs under that school’s identity, and the database itself refuses to return
          another school’s rows. Passwords are hashed with Argon2, and all traffic between the apps and
          our servers is encrypted with HTTPS.
        </p>
      </Section>

      <Section heading="Where it is stored">
        <p>
          Data is held in a managed PostgreSQL database operated by Railway. Servers for this
          deployment are currently located in the United States. If your school requires data to remain
          in India, contact us before onboarding — that is a deployment change, not a limitation of the
          software.
        </p>
      </Section>

      <Section heading="Retention and deletion">
        <p>
          Records are kept for as long as the school’s account is active, because schools need
          historical attendance and fee records. When a school ends its use of VidyaTrack, its data is
          deleted on request; otherwise it is removed within 90 days of the account closing.
        </p>
      </Section>

      <Section heading="Other services we use">
        <p>
          Hosting and database: Railway. Web hosting: Vercel. Both process data solely to run the
          service. We do not use advertising networks or third-party analytics that track individuals.
        </p>
      </Section>

      <Section heading="The public demo">
        <p>
          The demo school reachable from this site contains invented data for evaluation only. Anything
          entered there is visible to other people trying the demo and is periodically erased. Never put
          real student information into the demo.
        </p>
      </Section>

      <Section heading="Changes">
        <p>
          If this policy changes materially, we will update the date above and notify schools using the
          service.
        </p>
      </Section>
    </LegalPage>
  );
}
