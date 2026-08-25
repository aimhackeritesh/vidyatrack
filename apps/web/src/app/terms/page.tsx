import type { Metadata } from 'next';
import { LegalPage, Section } from '../_components/LegalPage';

export const metadata: Metadata = {
  title: 'Terms of Use — VidyaTrack',
  description: 'Terms governing use of the VidyaTrack app and console.',
};

export default function Terms() {
  return (
    <LegalPage title="Terms of Use" updated="25 August 2026">
      <Section heading="What this covers">
        <p>
          These terms apply to the VidyaTrack mobile app and web console. Where a school has signed a
          separate written agreement with us, that agreement takes precedence.
        </p>
      </Section>

      <Section heading="Accounts">
        <p>
          Accounts are issued by a school to its staff, students and guardians — you cannot self-register.
          Credentials are personal: keep them confidential and tell your school immediately if you think
          someone else has them. The school may suspend or reset any account it issued.
        </p>
      </Section>

      <Section heading="Acceptable use">
        <p>You agree not to:</p>
        <ul className="list-disc space-y-2 pl-5">
          <li>access or attempt to access records belonging to another school, family or staff member;</li>
          <li>upload unlawful material, malware, or content that is not appropriate in a school;</li>
          <li>probe, scrape, overload or reverse-engineer the service;</li>
          <li>use information obtained through the app for marketing or any purpose unrelated to the school.</li>
        </ul>
      </Section>

      <Section heading="The school’s responsibilities">
        <p>
          The school decides what data goes in and who may see it, obtains any consent required from
          parents and guardians, and is responsible for keeping its records accurate and for how its
          staff use the service.
        </p>
      </Section>

      <Section heading="Fees recorded in the app">
        <p>
          Fee amounts, invoices and receipts reflect what the school enters and are a record of the
          school’s own arrangement with a family. VidyaTrack is not a party to that arrangement and does
          not collect fees on the school’s behalf. In this release, in-app payment is simulated for
          demonstration and does not move money.
        </p>
      </Section>

      <Section heading="Availability">
        <p>
          We aim to keep the service running and to give notice of planned maintenance, but we do not
          guarantee uninterrupted availability. Schools should keep their own copies of anything they
          are legally required to retain.
        </p>
      </Section>

      <Section heading="Demonstration data">
        <p>
          The public demo is provided as-is for evaluation. Data in it is invented, visible to others
          trying it, and erased periodically.
        </p>
      </Section>

      <Section heading="Liability">
        <p>
          To the extent permitted by law, VidyaTrack is not liable for indirect or consequential loss,
          or for loss arising from data that a school or its staff entered incorrectly. Nothing here
          limits liability that cannot lawfully be limited.
        </p>
      </Section>

      <Section heading="Ending use">
        <p>
          A school may stop using VidyaTrack at any time and request export and deletion of its data.
          We may suspend access where these terms are breached in a way that puts other users or their
          data at risk.
        </p>
      </Section>

      <Section heading="Governing law">
        <p>These terms are governed by the laws of India.</p>
      </Section>
    </LegalPage>
  );
}
