# SRS Completion Tasks — Finish the SRS This Week

**Goal:** Complete the Software Requirements Specification (SRS) document so it is ready for sign-off by end of week. **Implementation starts next week.**

**Source document:** `docs/SRS_English_Phonics_App.md`  
**Each task below is a documentation/writing task** — the deliverable is **written SRS content** (text, tables, or edits), not code.

---

## How to Use

- **Backend team:** Owns Sections 3.8 (Payments), 3.9 (Notifications – backend part), 3.10 (Admin), 3.11 (Data/Privacy – backend), and related Appendix A entries.
- **Frontend (Web) team:** Owns Section 4.1 (UI) details for web, FR-W9/FR-W10 details, and any web-specific flows in the SRS.
- **Mobile team:** Owns Section 3.13 (Mobile) details, FR-M6/FR-M7, Section 4.1 (Mobile UI), and mobile-specific constraints.

**Deliverable per task:** Add or edit content in `SRS_English_Phonics_App.md` (or provide a clearly labeled draft section for merge). Mark task ☐ → ✅ when the SRS section is done and reviewed.

---

# Backend Team — SRS Writing Tasks

| Task ID | Task | Section / Location | Deliverable | Owner | Status |
|--------|------|--------------------|-------------|--------|--------|
| **BE-SRS-1** | **Payments – Subscription model** | §3.8, §2.2 | Define in SRS: (1) List of subscription plans (e.g. Free, Monthly, Yearly) with names and IDs; (2) What “premium content” means (e.g. by level, by lesson set, or by feature flag); (3) How access is stored (e.g. subscription table, period_end, plan_id). Add a small data model table or bullet list in §3.8 or Appendix. | | ☐ |
| **BE-SRS-2** | **Payments – API contract** | §3.8, Appendix B (or new Appendix D) | Document in SRS: (1) Endpoints to add (e.g. GET /api/v1/subscription/me, POST /api/v1/subscription/checkout-session, POST /api/v1/subscription/cancel); (2) Request/response shapes (high level); (3) Webhook events to handle (e.g. checkout.session.completed, customer.subscription.updated/deleted, invoice.payment_failed). | | ☐ |
| **BE-SRS-3** | **Payments – Security and PCI** | §5.2, §3.8 | Add to SRS: (1) No card storage; (2) Webhook signature verification (NFR-2.7); (3) That premium access is enforced server-side (NFR-2.8). Ensure FR-8.8 and NFR-2.7/2.8 are clear. | | ☐ |
| **BE-SRS-4** | **Notifications – Backend behavior** | §3.9 | Specify in SRS: (1) Which events trigger notifications (e.g. friend_request, achievement_unlocked, subscription_renewal, welcome); (2) Channels (in-app, email, push); (3) In-app: API to list/read notifications and mark read; (4) Email: which templates/events; (5) Push: device token registration API and who sends (backend vs provider). | | ☐ |
| **BE-SRS-5** | **Notifications – User preferences** | §3.9 (FR-9.4) | Specify in SRS: How notification preferences are stored and exposed (e.g. GET/PUT /api/v1/users/me/notification-preferences with keys like email_marketing, push_reminders). | | ☐ |
| **BE-SRS-6** | **Admin and reporting** | §3.10 | Specify in SRS: (1) List of reports/metrics (e.g. DAU/MAU, new signups, active subscriptions, revenue by plan); (2) Whether admin uses existing APIs or dedicated admin endpoints; (3) Plan management: create/edit plan (name, price_id, feature flags). | | ☐ |
| **BE-SRS-7** | **Data export and privacy** | §3.11 | Specify in SRS: (1) Data export: scope (profile, progress, scores) and format (JSON); endpoint e.g. GET /api/v1/users/me/export; (2) Account deletion: what is deleted vs anonymized vs retained for legal (e.g. payment history). | | ☐ |
| **BE-SRS-8** | **Environment variables** | Appendix A | Add to SRS: All payment-related env vars (e.g. STRIPE_*, webhook secret); notification-related (EMAIL_*, FCM_*, APNS_* or generic names). | | ☐ |

---

# Frontend (Web) Team — SRS Writing Tasks

| Task ID | Task | Section / Location | Deliverable | Owner | Status |
|--------|------|--------------------|-------------|--------|--------|
| **FE-SRS-1** | **Payment UI – Flows** | §4.1, §3.12 (FR-W9) | Specify in SRS: (1) Where subscription is shown (e.g. Profile or dedicated Billing page); (2) Flow: “Upgrade” → redirect to backend checkout URL → success/cancel return URLs; (3) Success: show confirmation and updated access; (4) Cancel/failure: show message and retry option. | | ☐ |
| **FE-SRS-2** | **Payment UI – Premium content** | §3.12 (FR-W9) | Specify in SRS: When user lacks access to premium content: (1) What they see (e.g. locked lesson card, “Upgrade to unlock”); (2) Single CTA to subscription/checkout. | | ☐ |
| **FE-SRS-3** | **In-app notifications (Web)** | §4.1, §3.12 (FR-W10) | Specify in SRS: (1) Where notifications appear (e.g. bell icon in header, dropdown list); (2) Actions: mark as read, link to target (e.g. friend request → friends page); (3) Optional: link to notification preferences page. | | ☐ |
| **FE-SRS-4** | **Web UI – Responsive and accessibility** | §4.1, §5.4 | Ensure SRS states: (1) Payment and subscription screens are responsive (NFR-4.1); (2) Form labels and errors for payment-related steps (NFR-4.2, NFR-4.4). Add one or two sentences if missing. | | ☐ |
| **FE-SRS-5** | **Register and login – Alignment** | §3.12 (FR-W1, FR-W2) | Specify in SRS: (1) Register: exact backend endpoint and body (e.g. POST /api/v1/auth/register vs POST /users/); (2) Login response: must include user object (id, email, name, role) for NextAuth. | | ☐ |

---

# Mobile Team — SRS Writing Tasks

| Task ID | Task | Section / Location | Deliverable | Owner | Status |
|--------|------|--------------------|-------------|--------|--------|
| **MO-SRS-1** | **Mobile subscription – Strategy** | §3.13 (FR-M6), §3.8 (FR-8.7) | Specify in SRS: (1) Choice: platform IAP (StoreKit / Google Play Billing) vs web-based checkout in WebView; (2) If IAP: how backend validates receipts and syncs subscription state; (3) If WebView: same checkout as web, return to app and refresh token/state. | | ☐ |
| **MO-SRS-2** | **Mobile subscription – UI and access** | §3.13 (FR-M6), §4.1 | Specify in SRS: (1) Where user sees plan and manages subscription (e.g. Profile or Settings); (2) Premium content: locked state and “Upgrade” CTA; (3) After purchase: how app learns new access (e.g. refetch /subscription/me or refresh token). | | ☐ |
| **MO-SRS-3** | **Push notifications** | §3.13 (FR-M7), §3.9 | Specify in SRS: (1) App registers device token with backend (e.g. POST /api/v1/users/me/device-tokens); (2) Backend stores token and uses FCM/APNs (or provider) to send; (3) Which events trigger push (e.g. friend request, achievement); (4) User can disable push in app settings (link to FR-9.4). | | ☐ |
| **MO-SRS-4** | **Mobile platform and constraints** | §2.4, §4.1, §4.3 | Specify in SRS: (1) Target platforms (iOS, Android, or both) and min OS versions; (2) Tech stack (e.g. React Native, Flutter, native); (3) Microphone and audio: permissions and any platform-specific constraints for recording/playback. | | ☐ |
| **MO-SRS-5** | **Mobile auth and profile** | §3.13 (FR-M1–M5) | Ensure SRS clearly states: (1) Login/register use same backend APIs as web; (2) Token stored in secure storage (Keychain/Keystore); (3) Profile view/edit use same endpoints (e.g. GET/PUT /users/me). Add one or two sentences if missing. | | ☐ |

---

# Cross-Cutting — All Teams

| Task ID | Task | Section / Location | Deliverable | Owner | Status |
|--------|------|--------------------|-------------|--------|--------|
| **CC-SRS-1** | **Premium content definition** | §3.2 (FR-2.7), §3.3 (FR-3.1), §3.4 (FR-4.2) | Agree and document in SRS: Single definition of “premium” (e.g. by lesson_id, level, or product_id). Backend enforces; web and mobile show locked/upgrade consistently. | Backend + Web + Mobile | ☐ |
| **CC-SRS-2** | **Glossary and terms** | §1.3 | Add to SRS glossary: Subscription, Premium content, Checkout, Webhook, IAP, Push token. Ensure no new acronyms are used without definition. | Any | ☐ |
| **CC-SRS-3** | **Document review and sign-off** | Full document | One pass: fix numbering, cross-references, and “To be specified” where content was added. Update Appendix C (Document History) and set Status to “Ready for implementation” when done. | PM / Lead | ☐ |

---

# Summary

| Team | Number of SRS writing tasks | Focus |
|------|-----------------------------|--------|
| **Backend** | 8 | Payments (model, API, webhooks, security), Notifications (events, channels, preferences), Admin/Reporting, Data export/Privacy, Env vars |
| **Frontend (Web)** | 5 | Payment UI flows, Premium content UX, In-app notifications UI, Responsive/a11y, Register/login contract |
| **Mobile** | 5 | Subscription strategy (IAP vs WebView), Subscription UI, Push (registration, events), Platform/stack, Auth/profile |
| **Cross-cutting** | 3 | Premium content definition, Glossary, Final review |

**Total:** 21 SRS completion tasks.  
**Target:** All tasks completed and SRS ready for implementation by end of week.
