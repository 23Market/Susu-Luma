#!/usr/bin/env bash
# Concurrency checks for the secure foundation on a THROWAWAY local PostgreSQL.
#
# Single-session pgTAP files cannot see races, so this launches real parallel sessions.
# NOT a substitute for staging verification. Environment: PGHOST, PGPORT, PGUSER.
# The script creates and drops its own database and refuses hosted hosts.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="${LUMA_CONCURRENCY_DB:-luma_concurrency_test}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)
TMP="$(mktemp -d)"
FAILS=0

case "${PGHOST:-}" in
  *supabase.co*|*supabase.com*|*amazonaws.com*|*neon.tech*)
    echo "REFUSING: PGHOST looks like a hosted database." >&2; exit 2 ;;
esac

cleanup() {
  "${PSQL[@]}" -d postgres -c "drop database if exists \"$DB\" with (force)" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

"${PSQL[@]}" -d postgres -c "drop database if exists \"$DB\" with (force)" >/dev/null 2>&1
"${PSQL[@]}" -d postgres -c "create database \"$DB\"" >/dev/null
"${PSQL[@]}" -d "$DB" -f "$ROOT/scripts/local-db/supabase_stub.sql" >/dev/null
"${PSQL[@]}" -d "$DB" -c "alter database \"$DB\" set search_path = public, extensions" >/dev/null
for f in "$ROOT"/supabase/migrations/*.sql; do "${PSQL[@]}" -d "$DB" -f "$f" >/dev/null; done

q() { psql -X -q -A -t -v ON_ERROR_STOP=1 -d "$DB" -c "$1"; }

check() { # description actual expected
  if [ "$2" = "$3" ]; then printf 'PASS %s (got %s)\n' "$1" "$2"
  else printf 'FAIL %s (got %s, wanted %s)\n' "$1" "$2" "$3"; FAILS=$((FAILS + 1)); fi
}

# Start N sessions that all wait on one advisory lock, then release them together.
# usage: run_parallel PREFIX COUNT 'sql-with-%i-for-index'
run_parallel() {
  local prefix="$1" count="$2" sql="$3" i
  psql -X -q -d "$DB" -c "select pg_advisory_lock(4242); select pg_sleep(1.5);" >/dev/null 2>&1 &
  local holder=$!
  sleep 0.4
  local pids=()
  for i in $(seq 1 "$count"); do
    (
      psql -X -q -A -t -d "$DB" >"$TMP/$prefix.$i.out" 2>"$TMP/$prefix.$i.err" <<SQL
begin;
select pg_advisory_xact_lock_shared(4242);
${sql//%i/$i}
commit;
SQL
      echo $? >"$TMP/$prefix.$i.rc"
    ) &
    pids+=($!)
  done
  wait "$holder" 2>/dev/null
  wait "${pids[@]}" 2>/dev/null
}

as_user() { # uuid
  printf "set local role authenticated; set local request.jwt.claims = '{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal2\"}';" "$1"
}

U1=aaaaaaaa-1111-0000-0000-000000000001; S1=aaaaaaaa-1111-0000-0000-000000000002
RV1=aaaaaaaa-1111-0000-0000-000000000011; RV2=aaaaaaaa-1111-0000-0000-000000000012; RV3=aaaaaaaa-1111-0000-0000-000000000013
OA=aaaaaaaa-1111-0000-0000-000000000021; OB=aaaaaaaa-1111-0000-0000-000000000022
O1=bbbbbbbb-1111-0000-0000-000000000001; O2=bbbbbbbb-1111-0000-0000-000000000002

psql -X -q -v ON_ERROR_STOP=1 -d "$DB" >/dev/null <<SQL
begin;
insert into auth.users(id) values ('$U1'),('$S1'),('$RV1'),('$RV2'),('$RV3'),('$OA'),('$OB');
insert into public.organizations(id, legal_name, display_name, organization_type, created_by) values
  ('$O1', 'Concurrent Supplier', 'Concurrent Supplier', 'supplier', '$S1'),
  ('$O2', 'Two Owner Org', 'Two Owner Org', 'business', '$OA');
insert into public.organization_memberships(organization_id, user_id, member_role) values
  ('$O1', '$S1', 'owner'), ('$O2', '$OA', 'owner'), ('$O2', '$OB', 'owner');
insert into public.platform_roles(user_id, role) values
  ('$RV1','verification_reviewer'),('$RV2','verification_reviewer'),('$RV3','verification_reviewer');
insert into storage.objects(bucket_id, name) values ('verification-evidence', '$O1/registration.pdf');
commit;
SQL

echo "== A. 12 parallel onboarding retries with one idempotency key =="
run_parallel onb 12 "$(as_user $U1) select public.create_organization_with_owner('Concurrent Ltd','Concurrent','buyer',null,null,null,'cccccccc-0000-0000-0000-000000000001');"
ids=$(cat "$TMP"/onb.*.out | sort -u | grep -c .)
errs=$(cat "$TMP"/onb.*.err | grep -c . || true)
check "all sessions returned the same organisation id" "$ids" "1"
check "no session errored" "$errs" "0"
check "exactly one organisation row" "$(q "select count(*) from public.organizations where creation_key = 'cccccccc-0000-0000-0000-000000000001'")" "1"
check "exactly one owner membership" "$(q "select count(*) from public.organization_memberships m join public.organizations o on o.id = m.organization_id where o.creation_key = 'cccccccc-0000-0000-0000-000000000001' and m.member_role = 'owner'")" "1"
check "exactly one creation audit event" "$(q "select count(*) from public.audit_events a join public.organizations o on o.id = a.entity_id where a.action = 'organization.created' and o.creation_key = 'cccccccc-0000-0000-0000-000000000001'")" "1"

echo "== B. 8 parallel verification submissions for one supplier =="
run_parallel sub 8 "$(as_user $S1) select public.submit_supplier_verification('$O1', array['$O1/registration.pdf']);"
okc=$(grep -l . "$TMP"/sub.*.out 2>/dev/null | wc -l | tr -d ' ')
dupe=$(cat "$TMP"/sub.*.err | grep -c 'duplicate key' || true)
check "exactly one submission succeeded" "$okc" "1"
check "the other seven were refused as duplicates" "$dupe" "7"
check "exactly one open case" "$(q "select count(*) from public.supplier_verification_cases where organization_id = '$O1' and status in ('pending','in_review','awaiting_second_review')")" "1"

echo "== C. three reviewers decide the same standard-risk case at once =="
CASE=$(q "select id from public.supplier_verification_cases where organization_id = '$O1'")
rm -f "$TMP"/dec.*
for r in $RV1 $RV2 $RV3; do :; done
psql -X -q -d "$DB" -c "select pg_advisory_lock(4243); select pg_sleep(1.5);" >/dev/null 2>&1 &
holder=$!; sleep 0.4; pids=(); i=0
for r in $RV1 $RV2 $RV3; do
  i=$((i + 1))
  (
    psql -X -q -A -t -d "$DB" >"$TMP/dec.$i.out" 2>"$TMP/dec.$i.err" <<SQL
begin;
select pg_advisory_xact_lock_shared(4243);
$(as_user $r) select public.review_supplier_verification('$CASE', 'approve', 'concurrent approval', 'Business registration');
commit;
SQL
  ) &
  pids+=($!)
done
wait "$holder" 2>/dev/null; wait "${pids[@]}" 2>/dev/null
check "exactly one reviewer's approval took effect" "$(cat "$TMP"/dec.*.out | grep -c '^approved$' || true)" "1"
check "the other decisions were refused as 'not open'" "$(cat "$TMP"/dec.*.err | grep -c 'case is not open for review' || true)" "2"
check "exactly one decision row recorded" "$(q "select count(*) from public.verification_decisions where case_id = '$CASE'")" "1"
check "exactly one approval audit event" "$(q "select count(*) from public.audit_events where entity_id = '$CASE' and action = 'verification.approved'")" "1"

echo "== D. two owners remove each other at the same time =="
run_two() {
  psql -X -q -d "$DB" -c "select pg_advisory_lock(4244); select pg_sleep(1.5);" >/dev/null 2>&1 &
  local h=$!; sleep 0.4
  ( psql -X -q -A -t -d "$DB" >"$TMP/own.1.out" 2>"$TMP/own.1.err" <<SQL
begin; select pg_advisory_xact_lock_shared(4244);
delete from public.organization_memberships where organization_id = '$O2' and user_id = '$OB';
select pg_sleep(0.8);
commit;
SQL
  ) & local p1=$!
  ( psql -X -q -A -t -d "$DB" >"$TMP/own.2.out" 2>"$TMP/own.2.err" <<SQL
begin; select pg_advisory_xact_lock_shared(4244);
delete from public.organization_memberships where organization_id = '$O2' and user_id = '$OA';
select pg_sleep(0.8);
commit;
SQL
  ) & local p2=$!
  wait "$h" 2>/dev/null; wait "$p1" "$p2" 2>/dev/null
}
run_two
check "organisation still has at least one owner" "$(q "select (count(*) >= 1)::text from public.organization_memberships where organization_id = '$O2' and member_role = 'owner'")" "true"

echo
if [ "$FAILS" -eq 0 ]; then echo "CONCURRENCY TOTAL: all checks passed"; else echo "CONCURRENCY TOTAL: $FAILS check(s) failed"; fi
[ "$FAILS" -eq 0 ]
