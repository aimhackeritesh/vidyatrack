# Play Store Submission Checklist

Everything needed to publish VidyaTrack, with the answers pre-filled. Companion to
[HANDOVER.md](HANDOVER.md) and [OPERATIONS.md](OPERATIONS.md).

> ⚠️ **Do not submit while the API is offline.** The reviewer will open the app, fail to log in,
> and reject it for broken functionality. Confirm `https://api-production-28467.up.railway.app/api/v1/health`
> returns `{"status":"ok"}` first.

---

## 1. Build — ✅ done in code

| Item | State |
|---|---|
| Release signing (upload key) | ✅ `android/key.properties` → `~/vidyatrack-upload-keystore.jks`, verified `CN=VidyaTrack` |
| App Bundle (.aab) | ✅ `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` |
| applicationId | ✅ `com.vidyatrack.vidyatrack` |
| targetSdk / compileSdk | ✅ 36 / 36 (Play requires ≥35) |
| App name on device | ✅ "VidyaTrack" |
| Launcher icon | ✅ custom adaptive icon (no longer the stock Flutter icon) |
| Cleartext HTTP | ✅ disabled in release; debug-only override for local dev |
| Minification / resource shrinking | ✅ enabled with Flutter-safe ProGuard rules |
| Privacy Policy URL | ✅ https://vidyatrack-web.vercel.app/privacy |
| Terms URL | ✅ https://vidyatrack-web.vercel.app/terms |

**Keystore:** password is in your password manager (also written to the session scratchpad).
**Back up `~/vidyatrack-upload-keystore.jks`.** Losing it means an upload-key reset request to Google.

---

## 2. Store listing — assets ready

| Asset | Status |
|---|---|
| App icon 512×512 | ✅ `apps/mobile/icon/play_store_512.png` |
| Feature graphic 1024×500 | ✅ `apps/mobile/icon/play_feature_graphic.png` |
| Phone screenshots (min 2, 16:9 or 9:16) | ⬜ **capture once the API is back** — see §6 |
| Short description (≤80 chars) | ✅ below |
| Full description (≤4000) | ✅ below |

**Short description**
```
Attendance, fees, homework and parent updates for small schools.
```

**Full description**
```
VidyaTrack is school management software built for small schools — the ones still
running on paper attendance registers, a fee notebook, and a WhatsApp group.

FOR THE PRINCIPAL / ADMIN
• Set your own fee structure — per class, monthly, quarterly, annual or one-time
• Generate monthly invoices for every student in one action
• Track daily collection, other income and expenses
• Add students and staff, or import a whole class from CSV
• Publish notices and approve staff leave

FOR TEACHERS
• Mark attendance for a whole section in one pass — works offline and syncs later
• Assign homework and upload study material
• Enter exam marks and publish results

FOR PARENTS
• Your child's attendance, timetable, homework, results and syllabus
• See pending fees and payment history
• Apply for leave

FOR STUDENTS
• Today's timetable, homework due, study material and your attendance record

BUILT FOR INDIAN SCHOOLS
• No email address needed — students and parents get login IDs issued by the school
• Works on modest phones and unreliable connections
• Each school's data is isolated at the database level

Accounts are created by your school. You cannot sign up directly — ask your school
for your login ID and password.
```

**Category:** Education · **Contact email:** support@vidyatrack.in · **Website:** https://vidyatrack-web.vercel.app

---

## 3. Data Safety form — pre-filled answers

Play Console → App content → Data safety. Answer exactly this:

**Does your app collect or share any of the required user data types?** → **Yes**

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Name (student, guardian, staff) | Yes | No | App functionality | Required |
| Phone number | Yes | No | App functionality, Account management | Required |
| Date of birth | Yes | No | App functionality | Required |
| Gender | Yes | No | App functionality | Optional |
| Photos (student photo, uploaded material) | Yes | No | App functionality | Optional |
| User IDs (login ID) | Yes | No | Account management | Required |
| Other info (attendance, marks, fee records) | Yes | No | App functionality | Required |

Also declare:
- **Is all data encrypted in transit?** → **Yes** (HTTPS)
- **Can users request data deletion?** → **Yes** — via their school; contact support@vidyatrack.in
- **Data is not shared with third parties**, not used for advertising, not sold.
- ❌ Do **not** tick: location, contacts, financial payment info (payments are simulated in this
  release and no card/UPI data is collected), health, messages, calendar, app activity/analytics.

---

## 4. Content rating questionnaire

Category: **Reference, News, or Educational**. Answer **No** to: violence, sexuality, profanity,
controlled substances, gambling, user-generated content shared publicly, and unrestricted internet
access. Expected outcome: **Everyone / PEGI 3**.

---

## 5. Target audience & children — read carefully

Play Console → App content → **Target audience and content**.

- **Target age groups:** select **13+ / adults** — the *users signing in* are school staff and
  parents. Do **not** market the app to children.
- **Is your app designed for children?** → **No.** It is a school-administration tool used by
  adults, which records information *about* students.
- Because it processes children's data, keep the privacy policy accurate about: the school being
  the data fiduciary, consent obtained by the school from parents, no profiling, and no ads.
- If you ever tick "designed for children," Play's **Families policy** applies and brings extra
  requirements (ads certification, stricter data rules). Avoid that unless you truly need it.

**India DPDP Act 2023:** the school obtains verifiable parental consent at admission; VidyaTrack
processes on the school's instruction. Get a written data-processing agreement with each school
before onboarding a real one.

---

## 6. Screenshots — capture when the API is live

Two or more phone screenshots are required. Best set (all show real seeded data):

1. Parent dashboard (tiles) 2. Attendance marking 3. Fee dues / invoice
4. Timetable grid 5. Admin home with revenue

```bash
# emulator must be running, API reachable
adb -s emulator-5554 exec-out screencap -p > shot1.png
```
Use the demo school (`VDTRK2627DEMO01` / `Demo@1234`). Do not show real student data.

---

## 7. Console setup steps

1. Create a Google Play Developer account ($25 one-time) — allow up to 48h for verification.
2. Create app → name **VidyaTrack**, language English (India), **App**, **Free**.
3. Upload the `.aab` to **Internal testing** first (not Production).
4. Complete: Data safety (§3), Content rating (§4), Target audience (§5), Privacy policy URL,
   App access (see below), Ads → **No ads**.
5. **App access:** the reviewer cannot sign up — you MUST provide demo credentials, or the app
   gets rejected. Enter under "All or some functionality is restricted":
   ```
   School Code: VDTRK2627DEMO01
   Username: 9999900001   (admin)   Password: Demo@1234
   Also: 9999900002 (teacher), 9999900003 (parent)
   ```
6. Roll out to Internal testing → verify on a real device → then promote to Production.

---

## 8. Before you go to Production

- [ ] API online and stable (Railway) — **currently offline**
- [ ] Database backups enabled (see OPERATIONS.md §9) — the volume is the only copy
- [ ] Crash reporting (Sentry) so you learn about crashes from real users
- [ ] Durable file storage — uploads are currently erased on every deploy
- [ ] Decide the demo-data story: reviewers need a working demo, but a public mutable demo sharing
      a database with real schools is a liability
