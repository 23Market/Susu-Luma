#!/usr/bin/env bash
# Run supabase/migrations and supabase/tests/database on a THROWAWAY local PostgreSQL.
#
# NOT a substitute for the `database-security` CI job (real Supabase stack). It exists
# so engineers can iterate when Docker is unavailable. See supabase_stub.sql.
#
# Requirements: a running PostgreSQL superuser connection and the pgTAP extension.
# Environment: PGHOST, PGPORT, PGUSER (libpq defaults apply). The script creates and
# drops its own database and refuses to run if the host looks like a hosted database.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="${LUMA_TEST_DB:-luma_local_test}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)

case "${PGHOST:-}" in
  *supabase.co*|*supabase.com*|*amazonaws.com*|*neon.tech*)
    echo "REFUSING: PGHOST looks like a hosted database. Use a local throwaway server." >&2
    exit 2 ;;
esac

"${PSQL[@]}" -d postgres -c "drop database if exists \"$DB\" with (force)" >/dev/null
"${PSQL[@]}" -d postgres -c "create database \"$DB\"" >/dev/null
trap '"${PSQL[@]}" -d postgres -c "drop database if exists \"$DB\" with (force)" >/dev/null 2>&1 || true' EXIT

"${PSQL[@]}" -d "$DB" -f "$ROOT/scripts/local-db/supabase_stub.sql" >/dev/null
"${PSQL[@]}" -d "$DB" -c "create extension if not exists pgtap with schema extensions" >/dev/null
"${PSQL[@]}" -d "$DB" -c "alter database \"$DB\" set search_path = public, extensions" >/dev/null

echo "== migrations =="
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "apply $(basename "$f")"
  "${PSQL[@]}" -d "$DB" -f "$f" >/dev/null
done

echo "== tests =="
total_ok=0; total_fail=0; failed_files=0
for t in "$ROOT"/supabase/tests/database/*.sql; do
  out="$(mktemp)"
  set +e
  "${PSQL[@]}" -A -t -d "$DB" -f "$t" >"$out" 2>"$out.err"
  rc=$?
  set -e
  ok=$(grep -c '^ok ' "$out" || true)
  bad=$(grep -c '^not ok ' "$out" || true)
  plan=$(grep -E '^1\.\.[0-9]+' "$out" | head -1 | sed 's/1\.\.//' || true)
  status=PASS
  if [ "$rc" -ne 0 ] || [ "$bad" -ne 0 ] || [ -z "$plan" ] || [ "$ok" -ne "$plan" ]; then status=FAIL; fi
  printf '%-4s %-45s ok=%s not_ok=%s plan=%s psql_rc=%s\n' "$status" "$(basename "$t")" "$ok" "$bad" "${plan:-none}" "$rc"
  if [ "$status" = FAIL ]; then
    grep -E '^not ok |^# ' "$out" | head -20 || true
    head -5 "$out.err" || true
    failed_files=$((failed_files + 1))
  fi
  total_ok=$((total_ok + ok)); total_fail=$((total_fail + bad))
  rm -f "$out" "$out.err"
done

echo "TOTAL ok=$total_ok not_ok=$total_fail failed_files=$failed_files"
[ "$failed_files" -eq 0 ]
