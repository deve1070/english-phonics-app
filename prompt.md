# English Phonics App — Project State & Handoff

You are picking up an in-progress English phonics learning app for kids, built
by a solo developer. You have file access to the full repo. This document is
a complete state dump from the person who did the work up to this point —
read it before touching anything, since several things here are *deliberate
design decisions*, not bugs, and several others are *known, documented gaps*
that don't need rediscovering.

## Repo layout

```
english-phonics-app/
├── backend/          FastAPI + PostgreSQL
├── phonics-web/      Next.js (parent-facing web app)
├── mobile/           Flutter (primary experience, kids + parents)
```

If you're starting from the delivered zips (`backend_fixed.zip`,
`phonics-web-fixed.zip`, `phonics_mobile.zip`) rather than the live repo,
merge them into these three folders. `phonics_mobile.zip` is Dart source
only — see `mobile/SETUP.md` for generating the native Android/iOS
scaffolding via `flutter create` first.

---

## Non-negotiable design decisions — do not silently reverse these

These were explicit product decisions made during development. If a "fix"
would touch any of these, stop and flag it rather than changing it:

1. **Fully passwordless auth.** Login is phone number only. No password, PIN,
   or OTP anywhere in this version. This was an explicit, discussed decision
   — not an oversight. If you find yourself wanting to add a password field
   back, don't.
2. **No friend/teacher/gamification/subscription features.** These were
   found as dead/broken half-built code and were *deliberately deleted*
   (not just disabled): `FriendRequestStatus`, `NotificationType`,
   `get_current_teacher_or_admin`, the duplicate `ParentChild` model. Do not
   resurrect them without being asked. There is no points/badges system and
   no subscriptions model — don't add fields assuming they exist.
3. **One parent per child link enforced by a DB constraint**
   (`ParentChildLink.child_id` is unique). A parent can have many children;
   a child has exactly one parent. This is intentional for this version.
4. **Two-token auth model, not JWT refresh tokens.** The backend issues a
   7-day `access_token` (JWT) plus a separate `biometric_token` (device
   "stay signed in" token, redeemed via `POST /auth/passkey-login`, rotates
   on every use). There is **no** `/auth/refresh` endpoint and never was —
   don't build client code assuming one exists.
5. **Paragraph exercises get real-time feedback; phoneme/word exercises do
   not.** This was an explicit pedagogical decision (interrupting a
   beginning reader mid-word breaks fluency; paragraph-level live tracking
   doesn't since it's non-interruptive visual highlighting, not audio
   interruption). Don't "simplify" the paragraph exercise flow back to a
   single record-and-submit without checking first.

---

## Backend (`backend/`)

FastAPI, async SQLAlchemy, PostgreSQL, Alembic. Azure Speech SDK
(pronunciation assessment + TTS) and Azure OpenAI (exercise generation,
weekly reports) are external dependencies — both are `Optional` in
`app/core/config.py` and the app degrades gracefully (logs + fallback text)
if unset, it does not crash on missing keys except where noted below.

### Verification status
Backend was verified by actually running it in a sandbox: `py_compile` on
every file, real imports of `app.main` with a Postgres+asyncpg dialect
string, and rendering every Alembic migration as literal Postgres SQL via
`--sql` offline mode (no live DB needed to check this). All passed clean as
of the last change. **Re-run these checks after any change**:
```bash
cd backend
python -c "import py_compile, glob; [py_compile.compile(f, doraise=True) for f in glob.glob('app/**/*.py', recursive=True)]"
SECRET_KEY=temp DATABASE_URL=postgresql+asyncpg://u:p@localhost/db python -c "from app.main import app"
SECRET_KEY=temp DATABASE_URL=postgresql://u:p@localhost/db alembic upgrade head --sql  # renders SQL, no DB needed
```
There is exactly one real test file: `tests/test_app_import.py` (checks the
app imports as a `FastAPI` instance — that's it, no coverage beyond that).
`test_azure.py` and `test_render.py` at the repo root look like manual smoke
scripts, not part of a pytest suite. **There is essentially no automated
test coverage on this backend — writing real tests is a high-value next
step.**

### Migrations
History was consolidated: 16 old migration files (which had **two
disconnected chain heads** — a broken state — and created tables for
features that no longer exist: `friend_requests`, `friends`,
`gamification`, `subscriptions`, `user_achievements`) were replaced with two
clean migrations reflecting exactly what the current models define:
`8de14b887107_consolidated_initial_schema.py` and
`3216f44b725d_add_unique_constraint_progress_user_.py`. Old files are kept
for reference only in `alembic/versions_archive_old/` — Alembic doesn't run
them. **If a real database already ran any of the old migrations, do not
run the new ones against it** — start fresh or reconcile manually.

### Deployment
`render.yaml` exists for Render.com deployment, `docker-compose.yml` for
local Postgres. The `render.yaml` startCommand had a bug (`main:app` instead
of `app.main:app` — would have failed immediately on deploy with
`ModuleNotFoundError`) which was just fixed, along with adding the other
required env vars (`SECRET_KEY`, Azure keys) that were missing from the env
var list. **This has not been tested against an actual Render deployment** —
worth verifying if you have access to deploy it.

### Utility/seed scripts — not reviewed in depth
The repo root has a number of one-off scripts:
`cleanup_invalid_exercises.py`, `fix_missing_phonemes.py`,
`fix_phoneme_count.py`, `generate_exercises_background.py`,
`list_phonemes.py`, `map_phonemes.py`, `update_phoneme_json_audio_urls.py`,
`seed.py`, `seed_lessons.py`, `seed_phonemes.py`, `seed_test_users.py`,
`clear_all_users.py`, `download_commons_audio.py`,
`generate_missing_azure_audio.py`, `organize_phoneme_files.py`,
`verify_phoneme_audio.py`, plus a `scripts/` folder and `phoneme.json`. None
of these were reviewed or fixed as part of this work — they were out of
scope. Treat them with the same scrutiny as everything else if you touch
them; don't assume they're correct just because they exist.

`sentry-sdk` is listed in `requirements.txt` but is **never actually
initialized anywhere in `app/`** — it's a fully unused dependency. Either
wire it up properly (`sentry_sdk.init(...)` in `main.py`, useful given there's
so little test coverage) or remove it from requirements.

### API surface — quick reference (verified exact shapes)

**Auth** (`/api/v1/auth`)
- `POST /register` — generic single-user register (not the parent+child flow)
- `POST /login` — `{phone_number}` → `Token{access_token, token_type, biometric_token}`. Checks `is_active`.
- `POST /passkey-login` — `{biometric_token}` → same `Token` shape, rotates the biometric token

**Parents** (`/api/v1/parents`) — the real parent-facing flow
- `POST /register` — `{name, phone_number, child: {name, user_name, nickname?}}` → `{parent_id, parent_phone, child, access_token, token_type, biometric_token}`
- `POST /children` — `ChildCreate{name, user_name, nickname?}` → `ChildResponse`
- `POST /child-login/{child_id}` — → `{access_token, token_type, child_id, child_name, expires_in_seconds}` (2hr token, no biometric_token)
- `GET /dashboard` — → `ParentDashboardResponse{parent_name, total_children, children: ChildSummary[]}`
- `GET /children/{id}/progress` — → `ChildProgressResponse` (lessons/exercises completed, avg score, streak, phoneme-level mastery list)
- `GET /children/{id}/weekly-report` — AI-generated, cached per week
- `GET|PUT /children/{id}/goals` — daily minutes target, lessons/week, screen time limit
- `POST /children/{id}/start-session` / `POST /children/{id}/end-session` — screen-time tracking; `end-session` accepts either the parent's token or the child's own token

**Lessons/Exercises** (`/api/v1/lessons`, `/api/v1/exercises`)
- `GET /lessons` — list, includes per-lesson `completed_exercises`/`total_exercises` for current user already computed server-side
- `GET /lessons/{id}` — detail, includes `phonemes[]` but **not** exercises
- `GET /lessons/{id}/exercises` — separate endpoint, exercises only
- `GET /exercises/{id}` — single exercise
- `POST /exercises/{id}/submit-pronunciation` — multipart, field `audio`, optional form field `sentence_index` (PARAGRAPH exercises only — scores against just that sentence instead of the whole paragraph; see `pronunciation_service.py::split_into_sentences`, mirrored exactly in the mobile client's `sentence_splitter.dart`)
- `GET /exercises/{id}/reference-audio?blend=` — streams `audio/mpeg`

**Users**: `GET /users/me` → `UserResponse{id, user_name, name, phone_number, is_active, role, created_at}` — **no `age_group` field exists**, don't assume it does.

### Known backend gaps not yet fixed (lower priority / deliberately deferred)
- No rate limiting anywhere (`login`/`register` especially — matters more given there's no password/OTP)
- `SessionEndRequest` requires `session_start` in the body but the implementation doesn't actually use it to identify which session to close (just finds whatever's open) — harmless today (only one session is ever open at a time per child) but the schema implies more than it does
- `InviteLink` model exists (`app/models/auth_models.py`) with no endpoints using it — an unfinished feature, not wired to anything
- Admin-only audio upload (`phonemes.py`, persisted to disk) has a size cap now but no real content-type/MIME validation beyond file extension
- No automated test suite beyond the one import-smoke-test mentioned above

---

## Web app (`phonics-web/`)

Next.js App Router, TypeScript, Tailwind, Zod, react-hook-form. Parent-facing
primarily (login, register, dashboard, child detail); has a student-facing
lessons/exercises flow too but that's secondary to the mobile app now.

### Verification status
`npx tsc --noEmit` and `npx eslint .` both pass with **zero errors, zero
warnings** as of the last change. A full `next build` was attempted but
fails only on fetching Google Fonts (`next/font/google` needs live internet
access at build time) — that's a sandbox network restriction, not a code
bug; it will build fine with normal internet access. **Re-verify this after
any change**: `rm -rf .next && npx tsc --noEmit && npx eslint .`

### What was fixed
The frontend had been built against an older backend contract
(password+PIN+refresh-tokens) that no longer matches the actual
(passwordless, single-token) backend. Rewrote: `login()`/`register()` in
`lib/auth/context.tsx`, the login/register pages (dropped the whole
password/PIN "Security" step), `lib/api/client.ts` (removed the fake
`/auth/refresh` flow, fixed cookie max-age from 1hr to the real 7-day JWT
lifetime). Also fixed pages that called endpoints that don't exist on the
backend at all (`GET /progress`, `GET /exercises` as a list) — `lessons`
page, `progress` page, and `parent/children/[id]` page were all rebuilt to
use the real endpoints (`GET /lessons`, `GET /parents/children/{id}/progress`).

### Known limitations
- Student's own progress view (`student/progress/page.tsx`) only shows
  per-lesson completion counts, not per-exercise score history — there's no
  backend endpoint for a student to see their own detailed attempt history
  (only the parent-facing `ChildProgressResponse` has that granularity, and
  it's parent-only). Adding a student-scoped equivalent would be a small,
  clean backend addition if this is wanted.
- The spelling-bee mini-game (`student/spelling-bee/page.tsx`) uses a fully
  local hardcoded word list, disconnected from the backend curriculum. Not
  a bug, just worth knowing it's not tied to lesson content.
- No automated tests (no Jest/Playwright/etc. configured at all).

---

## Mobile app (`mobile/`)

Flutter + Riverpod + go_router + dio + flutter_secure_storage. This is the
**primary intended experience** — chosen over React Native specifically for
best-in-class custom kid-friendly UI/animation capability, at the cost of no
code-sharing with the TypeScript web app.

### ⚠️ Verification status — read this before trusting anything here
**No Flutter/Dart toolchain was ever available during development** (the SDK
download servers weren't reachable from the sandbox). Every file was
written carefully against the exact, verified backend contract above, and
sanity-checked for brace/paren balance and import-vs-`pubspec.yaml`
consistency — but **none of it has ever been compiled, analyzed, or run**.
Before doing anything else:
```bash
cd mobile
flutter pub get
flutter analyze
```
Fix whatever that surfaces first. Known specific uncertainty: the
`speech_to_text` package's `listen()` API — whether `partialResults` is
a direct named parameter or only available via a `SpeechListenOptions`
object — was a genuine unknown at write time (flagged in a code comment in
`paragraph_exercise_screen.dart`); check the actual resolved package version.

### What's built
Full loop: splash (silent auto-login via biometric token) → login/register
→ parent dashboard (children list, add child, switch-to-child, weekly
report, learning goals editor) → child progress detail (phoneme-level
mastery) → student lessons list → lesson detail → exercise (recording,
playback, scoring) → paragraph exercise (see below).

### Session-tracking design (screen time)
A parent switching into a child's session opens a screen-time session
(`POST .../start-session`); switching back or logging out closes it
(`POST .../end-session`). If the app is killed mid-child-session and the
child's short-lived token has expired by the time it's reopened, the app
falls back to restoring the parent's stashed session and closes the
dangling screen-time session as part of that recovery — see
`AuthRepository.tryAutoLogin()`'s parent-stash fallback path. There's a
non-obvious token-ordering requirement in that fallback (the parent token
has to be restored *before* attempting to close the session, since the
child's token is already gone by that point and only the parent's token
can authorize closing someone else's session) — this was a real bug caught
and fixed during development, worth being careful about if you touch this
code.

### Paragraph exercise — the least-verified, most experimental part of the app
`features/lessons/screens/paragraph_exercise_screen.dart` runs two
independent subsystems concurrently:
1. **Sentence-chunked submission** (the real score): pause detection via
   the `record` package's amplitude stream auto-splits reading into
   sentences; each is submitted to the existing
   `/exercises/{id}/submit-pronunciation` endpoint with `sentence_index`
   set, the moment a pause is detected. Next sentence starts recording
   immediately, not waiting on the network call.
2. **Live word tracking** (instant visual signal only): on-device speech
   recognition (`speech_to_text`, no backend involvement) highlights words
   green/red as read, in real time, without interrupting reading. **Whether
   `record` and `speech_to_text` can both hold the microphone
   simultaneously on a real device is genuinely unknown** — if starting
   live tracking fails, it disables itself gracefully (shows an amber
   banner) and subsystem 1 keeps working alone. This dual-mic-access
   question is the single biggest open unknown in the whole codebase —
   test it first if you get a device.

Tunable constants that were picked without any way to test them against a
real microphone: `_silenceThresholdDb = -35.0`,
`_silenceDurationForBoundary = 900ms`, `_minSentenceDuration = 500ms` — all
in `paragraph_exercise_screen.dart`. Expect to need to tune these.

### Setup
`mobile/SETUP.md` has full instructions: generating native scaffolding via
`flutter create` (native `android/`/`ios/` folders were deliberately never
hand-written — too easy to get subtly wrong without the real toolchain to
verify against), required manifest/plist permissions (`RECORD_AUDIO`,
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` — the
iOS ones aren't optional, missing them crashes the app on first permission
request rather than showing a dialog), and a dedicated testing checklist
specifically for the paragraph exercise feature.

### Known gaps
- No automated tests (`flutter test`) written at all
- No offline handling — network errors show a message but there's no
  retry queue or offline cache
- No crash reporting/analytics wired up

---

## Suggested priority order if picking this up fresh

1. `flutter pub get && flutter analyze` on mobile — this is completely
   unverified and most likely to have real compile errors
2. Get the paragraph exercise feature on a real device — the dual-mic
   question and silence-detection tuning can't be resolved any other way
3. Write actual backend tests — coverage is essentially zero right now
4. Verify the `render.yaml` deployment actually works end-to-end
5. Decide whether to build a student-facing progress-detail endpoint (web
   gap noted above) or leave it as parent-only
6. Everything under "Known gaps" / "Known backend gaps" sections above, in
   whatever order matters most to the product
