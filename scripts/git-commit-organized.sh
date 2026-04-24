#!/usr/bin/env bash
#
# Organized multi-commit script for english-phonics-app.
#
# Two phases (default):
#   1) On your current branch (e.g. dev): backend, assets, docs, helper script — NOT mobile/
#   2) New branch MOBILE_BRANCH (default: mobile): mobile/ as multiple focused commits
#
# Usage (from repo root):
#   ./scripts/git-commit-organized.sh
#
# Dry run (stage + show stat, then unstage; no commits, no branch switch):
#   DRY_RUN=1 ./scripts/git-commit-organized.sh
#
# Backend + chores only (stay on current branch; skip mobile branch entirely):
#   SKIP_MOBILE_BRANCH=1 ./scripts/git-commit-organized.sh
#
# Large archives (off by default):
#   INCLUDE_ARCHIVES=1 ./scripts/git-commit-organized.sh
#
# If branch "mobile" already exists, the script exits with an error unless you
# remove/rename it or set MOBILE_BRANCH to a fresh name, e.g. MOBILE_BRANCH=mobile-v2
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Long diffs (e.g. many audio files) otherwise open `less` and block until you press `q`.
export GIT_PAGER=cat

DRY_RUN="${DRY_RUN:-0}"
INCLUDE_ARCHIVES="${INCLUDE_ARCHIVES:-0}"
SKIP_MOBILE_BRANCH="${SKIP_MOBILE_BRANCH:-0}"
MOBILE_BRANCH="${MOBILE_BRANCH:-mobile}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repository" >&2
  exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "nothing to commit, working tree clean"
  exit 0
fi

BASE_BRANCH="$(git branch --show-current)"

# Stage paths, commit with message; on DRY_RUN, unstage those paths afterward.
run_commit() {
  local subject="$1"
  shift
  if [ "$#" -eq 0 ]; then
    echo "skip (no paths): $subject"
    return 0
  fi

  git add "$@" 2>/dev/null || true

  if git diff --cached --quiet; then
    echo "skip (nothing staged): $subject"
    return 0
  fi

  echo "----"
  echo "STAGED: $subject"
  git --no-pager diff --cached --stat

  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY_RUN] would commit: $subject"
    git diff --cached --name-only -z | xargs -0 -r git restore --staged -- 2>/dev/null || true
    return 0
  fi

  git commit -m "$subject"
}

# Commit whatever is already staged (used after custom git add steps).
commit_staged() {
  local subject="$1"
  if git diff --cached --quiet; then
    echo "skip (nothing staged): $subject"
    return 0
  fi
  echo "----"
  echo "STAGED: $subject"
  git --no-pager diff --cached --stat
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY_RUN] would commit: $subject"
    git diff --cached --name-only -z | xargs -0 -r git restore --staged -- 2>/dev/null || true
    return 0
  fi
  git commit -m "$subject"
}

# Switch to MOBILE_BRANCH at current HEAD (new branch), or abort if it exists.
checkout_new_mobile_branch() {
  if [ "$SKIP_MOBILE_BRANCH" = "1" ] || [ ! -d mobile ]; then
    return 0
  fi
  if git show-ref --verify --quiet "refs/heads/$MOBILE_BRANCH"; then
    echo "error: branch '$MOBILE_BRANCH' already exists." >&2
    echo "  Remove: git branch -D $MOBILE_BRANCH" >&2
    echo "  Or use: MOBILE_BRANCH=mobile-v2 ./scripts/git-commit-organized.sh" >&2
    exit 1
  fi
  git checkout -b "$MOBILE_BRANCH"
  echo "== Switched to new branch: $MOBILE_BRANCH (from $BASE_BRANCH @ HEAD)"
}

# Structured commits under mobile/ (call only on mobile branch).
commit_mobile_tree() {
  if [ ! -d mobile ]; then
    echo "skip: no mobile/ directory"
    return 0
  fi

  echo ""
  echo "========== Phase 2: mobile/ ($MOBILE_BRANCH) =========="

  # --- 1) Tooling + platform scaffolding ---
  run_commit "chore(mobile): Flutter project scaffolding and platforms" \
    mobile/pubspec.yaml \
    mobile/pubspec.lock \
    mobile/analysis_options.yaml \
    mobile/README.md \
    mobile/.metadata \
    mobile/.gitignore \
    mobile/android \
    mobile/ios \
    mobile/web \
    mobile/windows \
    mobile/linux \
    mobile/macos \
    mobile/test

  # --- 2) Core: theme, DI, network, constants ---
  run_commit "feat(mobile): core theme, DI, networking, and constants" \
    mobile/lib/core/theme \
    mobile/lib/core/di \
    mobile/lib/core/network \
    mobile/lib/core/constants

  # --- 3) Routing ---
  run_commit "feat(mobile): app routing and navigation shell" \
    mobile/lib/core/router

  # --- 4) App entrypoint ---
  run_commit "feat(mobile): application entrypoint" \
    mobile/lib/main.dart \
    mobile/lib/app.dart

  # --- 5) Features (by domain) ---
  run_commit "feat(mobile): authentication feature" \
    mobile/lib/features/auth

  run_commit "feat(mobile): splash and onboarding" \
    mobile/lib/features/splash \
    mobile/lib/features/onboarding

  run_commit "feat(mobile): home dashboard" \
    mobile/lib/features/home

  run_commit "feat(mobile): lessons and phonics learning" \
    mobile/lib/features/lessons \
    mobile/lib/features/phonics

  run_commit "feat(mobile): pronunciation and progress" \
    mobile/lib/features/pronunciation \
    mobile/lib/features/progress

  run_commit "feat(mobile): spelling bee and friends" \
    mobile/lib/features/spelling_bee \
    mobile/lib/features/friends

  run_commit "feat(mobile): profile, subscription, and gamification" \
    mobile/lib/features/profile \
    mobile/lib/features/subscription \
    mobile/lib/features/gamification

  # --- 6) Assets ---
  run_commit "assets(mobile): fonts, images, audio, and animation placeholders" \
    mobile/assets

  # --- 7) Anything left under mobile/ (generated registrants, etc.) ---
  git add mobile/
  commit_staged "chore(mobile): remaining Flutter project files"
}

echo "== Repository: $ROOT"
echo "== Base branch: $BASE_BRANCH"
echo "== DRY_RUN=$DRY_RUN INCLUDE_ARCHIVES=$INCLUDE_ARCHIVES SKIP_MOBILE_BRANCH=$SKIP_MOBILE_BRANCH MOBILE_BRANCH=$MOBILE_BRANCH"
echo ""

echo "========== Phase 1: backend + repo (no mobile/) =========="

# ---------------------------------------------------------------------------
# 1) Database migrations
# ---------------------------------------------------------------------------
run_commit "db(alembic): phonics schema and phoneme ordering migration" \
  backend/alembic/versions/55be59282c05_full_phonics_schema.py \
  backend/alembic/versions/a1b2c3d4e5f6_add_order_to_phonemes.py

# ---------------------------------------------------------------------------
# 2) Lessons domain (new)
# ---------------------------------------------------------------------------
run_commit "feat(backend): lessons CRUD, schemas, and REST endpoints" \
  backend/app/crud/crud_lesson.py \
  backend/app/schemas/lesson.py \
  backend/app/api/v1/endpoints/lessons.py

# ---------------------------------------------------------------------------
# 3) Progress domain (new)
# ---------------------------------------------------------------------------
run_commit "feat(backend): progress schema and CRUD" \
  backend/app/schemas/progress.py \
  backend/app/crud/crud_progress.py

# ---------------------------------------------------------------------------
# 4) Core API wiring and auth-related endpoints
# ---------------------------------------------------------------------------
run_commit "fix(backend): auth, users, security, and v1 router wiring" \
  backend/app/api/v1/endpoints/__init__.py \
  backend/app/api/v1/endpoints/auth.py \
  backend/app/api/v1/endpoints/users.py \
  backend/app/api/v1/router.py \
  backend/app/core/security.py

# ---------------------------------------------------------------------------
# 5) Content endpoints and shared models/schemas
# ---------------------------------------------------------------------------
run_commit "refactor(backend): exercises, phonemes, progress endpoints and models" \
  backend/app/api/v1/endpoints/exercises.py \
  backend/app/api/v1/endpoints/phonemes.py \
  backend/app/api/v1/endpoints/progress.py \
  backend/app/models/__init__.py \
  backend/app/models/phoneme.py \
  backend/app/schemas/__init__.py \
  backend/app/schemas/exercise.py \
  backend/app/schemas/pronunciation_score.py \
  backend/app/schemas/user.py \
  backend/app/crud/__init__.py \
  backend/app/crud/crud_exercise.py \
  backend/app/crud/crud_pronunciation_score.py

# ---------------------------------------------------------------------------
# 6) Services, TTS, and dependencies
# ---------------------------------------------------------------------------
run_commit "feat(backend): Azure TTS with viseme timeline and service fixes" \
  backend/app/utils/tts_synthesizer.py \
  backend/app/api/v1/endpoints/tts.py \
  backend/app/services/exercise_generation_service.py \
  backend/app/services/pronunciation_service.py \
  backend/app/services/recommendation_service.py \
  backend/app/services/reference_audio_service.py \
  backend/app/utils/pronunciation_assessor.py \
  backend/requirements.txt

# ---------------------------------------------------------------------------
# 7) Maintenance scripts
# ---------------------------------------------------------------------------
run_commit "chore(backend): seed and cleanup utility scripts" \
  backend/seed_phonemes.py \
  backend/cleanup_invalid_exercises.py

# ---------------------------------------------------------------------------
# 8) Phoneme reference audio + removal of legacy uploads under uploads/audio
# ---------------------------------------------------------------------------
if compgen -G "backend/uploads/audio/sound_*.mp3" >/dev/null 2>&1; then
  git add backend/uploads/audio/sound_*.mp3
fi
git add -u backend/uploads/audio/
commit_staged "assets(backend): phoneme reference audio and remove legacy samples"

# ---------------------------------------------------------------------------
# 9) Documentation and root cleanup (mobile/ intentionally excluded)
# ---------------------------------------------------------------------------
run_commit "chore: drop obsolete SRS docs and stray root package files" \
  APP_SUMMARY.md \
  docs/SRS_Completion_Tasks.md \
  docs/SRS_English_Phonics_App.md \
  docs/SRS_English_Phonics_App.pdf \
  package.json \
  package-lock.json \
  requirments.txt

# ---------------------------------------------------------------------------
# 10) Optional archives
# ---------------------------------------------------------------------------
if [ "$INCLUDE_ARCHIVES" = "1" ]; then
  run_commit "chore: add backend and audio distribution archives" \
    backend.zip \
    backend/uploads/audio.zip
else
  echo "----"
  echo "NOTE: not staging backend.zip or backend/uploads/audio.zip (INCLUDE_ARCHIVES=1 to add)."
fi

# ---------------------------------------------------------------------------
# 11) Helper script (on base branch, before mobile branch)
# ---------------------------------------------------------------------------
run_commit "chore(repo): add organized multi-commit helper script" scripts/git-commit-organized.sh

# ---------------------------------------------------------------------------
# 12) Mobile branch + structured mobile commits
# ---------------------------------------------------------------------------
if [ "$SKIP_MOBILE_BRANCH" != "1" ] && [ -d mobile ]; then
  if [ "$DRY_RUN" = "1" ]; then
    echo ""
    echo "[DRY_RUN] Phase 2 would: git checkout -b $MOBILE_BRANCH"
    echo "[DRY_RUN] then ~12 focused commits under mobile/ (see commit_mobile_tree in script)."
  else
    checkout_new_mobile_branch
    commit_mobile_tree
  fi
else
  echo ""
  echo "== Skipping mobile branch (SKIP_MOBILE_BRANCH=1 or no mobile/ directory)."
fi

echo ""
echo "== Done. Current branch: $(git branch --show-current)"
echo "== Remaining status:"
git --no-pager status --short
