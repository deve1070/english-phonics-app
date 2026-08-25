# PhonicsFriends — web

The parent-facing web client for the phonics app, alongside a read-only
student view. The primary experience is the Flutter app in `../mobile`; this
covers what parents would rather do on a laptop — checking progress, reading
per-phoneme mastery, exporting a report.

Talks to the FastAPI backend in `../backend`.

## Running it

```bash
npm install
npm run dev
```

Set the API base URL in `.env.local`:

```
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
```

The backend must be running; see `../backend` for that.

## Stack

Next.js 16 with the App Router, React 19, TypeScript, Tailwind. Forms use
react-hook-form with Zod schemas. Authentication state lives in a React
context (`src/lib/auth/context.tsx`) over a small fetch wrapper
(`src/lib/api/client.ts`) that handles cookie-based JWTs and refresh.

## Routes

```
/                          landing
/login, /register          auth
/parent/dashboard          children, streaks, activity
/parent/children/[id]      per-child progress and phoneme mastery
/student/lessons           lesson list
/student/lessons/[id]      lesson detail
/student/phonemes/[id]     a single sound
/student/exercises/[id]    exercise with pronunciation recording
/student/progress          score trends
/student/spelling-bee      spelling game
```
