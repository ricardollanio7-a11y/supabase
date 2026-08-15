#!/bin/bash
# SessionStart hook (see ../settings.json) — installs pnpm deps in cloud
# sessions. No-op locally.
#
# The install runs in the BACKGROUND. A cold install of this monorepo takes
# several minutes, well past the default 60s hook timeout, and a hook that
# gets killed mid-install leaves node_modules/.pnpm fully populated but never
# linked: no .modules.yaml, no .bin, no per-workspace node_modules. Every
# pnpm script then fails on missing binaries, and the half-finished store
# looks close enough to a real install that it is easy to misread as one.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Resolve the repo root from this script's own location instead of trusting
# $CLAUDE_PROJECT_DIR — in remote multi-repo sessions it can come through
# empty, and `cd ""` is a silent no-op, so pnpm install would run in whatever
# directory the hook happened to start in.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log=/tmp/supabase-pnpm-install.log
done_marker=/tmp/supabase-pnpm-install.done
fail_marker=/tmp/supabase-pnpm-install.failed
rm -f "$done_marker" "$fail_marker"

nohup bash -c "
  cd '$repo_root'
  if pnpm install >'$log' 2>&1; then
    touch '$done_marker'
  else
    touch '$fail_marker'
  fi
" >/dev/null 2>&1 &

echo "session-start: pnpm install started in background (log: $log)"
echo "session-start: before running any pnpm script, wait for it:"
echo "  until [ -e $done_marker ] || [ -e $fail_marker ]; do sleep 5; done"
