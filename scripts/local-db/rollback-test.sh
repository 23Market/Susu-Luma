#!/usr/bin/env bash
# Prove the rollback: (baseline migrations) == (all migrations, then rollback).
# Compares schema dumps and checks the rollback refuses to run without consent.
# THROWAWAY local PostgreSQL only. Environment: PGHOST, PGPORT, PGUSER.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DB="${LUMA_ROLLBACK_BASE_DB:-luma_rollback_base}"
ROLL_DB="${LUMA_ROLLBACK_DB:-luma_rollback_after}"
DOWN="$ROOT/supabase/rollback/20261117000100_secure_foundation.down.sql"
TMP="$(mktemp -d)"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)
FAILS=0

case "${PGHOST:-}" in
  *supabase.co*|*supabase.com*|*amazonaws.com*|*neon.tech*)
    echo "REFUSING: PGHOST looks like a hosted database." >&2; exit 2 ;;
esac

cleanup() {
  for d in "$BASE_DB" "$ROLL_DB"; do
    "${PSQL[@]}" -d postgres -c "drop database if exists \"$d\" with (force)" >/dev/null 2>&1 || true
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdb() {
  "${PSQL[@]}" -d postgres -c "drop database if exists \"$1\" with (force)" >/dev/null 2>&1
  "${PSQL[@]}" -d postgres -c "create database \"$1\"" >/dev/null
  "${PSQL[@]}" -d "$1" -f "$ROOT/scripts/local-db/supabase_stub.sql" >/dev/null
}
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (got '$2', wanted '$3')"; FAILS=$((FAILS + 1)); fi; }
# pg_dump emits random \restrict/\unrestrict tokens (and SET/comment noise); strip them.
dump() { pg_dump -s -x -O --no-comments -d "$1" -n public -n storage 2>/dev/null | grep -v -E '^(--|SET |SELECT pg_catalog\.set_config|\\(un)?restrict)' | grep -v '^$'; }
dump_acl() { pg_dump -s -O --no-comments -d "$1" -n public 2>/dev/null | grep -E '^(GRANT|REVOKE|ALTER DEFAULT PRIVILEGES)' | sort; }

# Baseline: every migration except the two E7 migrations being rolled back.
mkdb "$BASE_DB"
for f in "$ROOT"/supabase/migrations/*.sql; do
  case "$f" in *20261117000100_secure_foundation.sql|*20261118000100_verification_risk_policy.sql) continue ;; esac
  "${PSQL[@]}" -d "$BASE_DB" -f "$f" >/dev/null
done

# Full migration set, then rollback.
mkdb "$ROLL_DB"
for f in "$ROOT"/supabase/migrations/*.sql; do "${PSQL[@]}" -d "$ROLL_DB" -f "$f" >/dev/null; done

"${PSQL[@]}" -d "$ROLL_DB" -f "$DOWN" >"$TMP/refuse.out" 2>"$TMP/refuse.err"
check "rollback refuses to run without luma.allow_data_loss" "$(grep -c 'Refusing to roll back' "$TMP/refuse.err")" "1"
check "refused rollback changed nothing (private schema still present)" \
  "$(psql -X -q -A -t -d "$ROLL_DB" -c "select count(*) from pg_namespace where nspname = 'private'")" "1"

PGOPTIONS="-c luma.allow_data_loss=yes" "${PSQL[@]}" -d "$ROLL_DB" -f "$DOWN" >"$TMP/down.out" 2>"$TMP/down.err"
down_rc=$?
check "rollback exits 0 with consent" "$down_rc" "0"
check "rollback raised no ERROR (NOTICEs are expected)" "$(grep -c 'ERROR' "$TMP/down.err")" "0"

dump "$BASE_DB" >"$TMP/base.sql"; dump "$ROLL_DB" >"$TMP/after.sql"
check "schema after rollback equals the baseline schema" "$(diff -q "$TMP/base.sql" "$TMP/after.sql" >/dev/null && echo same || echo different)" "same"
dump_acl "$BASE_DB" >"$TMP/base.acl"; dump_acl "$ROLL_DB" >"$TMP/after.acl"
check "grants after rollback equal the baseline grants" "$(diff -q "$TMP/base.acl" "$TMP/after.acl" >/dev/null && echo same || echo different)" "same"
if ! diff -q "$TMP/base.sql" "$TMP/after.sql" >/dev/null; then diff "$TMP/base.sql" "$TMP/after.sql" | head -30; fi
if ! diff -q "$TMP/base.acl" "$TMP/after.acl" >/dev/null; then diff "$TMP/base.acl" "$TMP/after.acl" | head -30; fi

# The rolled-back database must accept the ORIGINAL (pre-E7) policy test from the baseline.
check "no secure-foundation objects remain" "$(psql -X -q -A -t -d "$ROLL_DB" -c "select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname in ('public','private') and p.proname in ('create_organization_with_owner','has_platform_role','review_supplier_verification','my_platform_access','protect_risk_controls')")" "0"

echo
if [ "$FAILS" -eq 0 ]; then echo "ROLLBACK TOTAL: all checks passed"; else echo "ROLLBACK TOTAL: $FAILS check(s) failed"; fi
[ "$FAILS" -eq 0 ]
