#!/usr/bin/env bash
# Recreates a scratch database, applies the stub + every migration, then runs the SQL tests.
#   PGHOST=/tmp PGPORT=54329 PGUSER=pgtest supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
DB=${DB:-susu_test}
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
P="psql -v ON_ERROR_STOP=1 -q -d $DB"
$P -f supabase/tests/00_stub_supabase.sql
for f in supabase/migrations/*.sql; do echo "apply $f"; $P -f "$f"; done
for f in supabase/tests/[1-9]*.sql; do echo "test  $f"; $P -f "$f"; done
echo "ALL SQL TESTS PASSED"
