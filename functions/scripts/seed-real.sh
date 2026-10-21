#!/bin/sh
# DEV ONLY — seeds the two labelled test accounts on the REAL Firebase project (no match:
# they find and like each other in Discover).
# The testers' password lives in functions/.dev-testers.local (git-ignored), created on first run.
set -e
cd "$(dirname "$0")/.."
if [ ! -f .dev-testers.local ]; then
  umask 077
  printf 'DEV_PASSWORD=%s\n' "$(openssl rand -base64 18 | tr -d '/+=')" > .dev-testers.local
fi
DEV_PASSWORD=$(sed -n 's/^DEV_PASSWORD=//p' .dev-testers.local)
GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)
export DEV_PASSWORD GOOGLE_OAUTH_ACCESS_TOKEN
node scripts/seed-testers.mjs
