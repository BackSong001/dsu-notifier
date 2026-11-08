#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container="dsu-db-test-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run --detach --rm --name "$container" -e POSTGRES_PASSWORD=fixture-only public.ecr.aws/supabase/postgres:17.11.0.006 >/dev/null
for attempt in {1..30}; do
  if docker exec "$container" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
for migration in supabase/migrations/*.sql; do
  docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < "$migration" >/dev/null
done
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < backend/__TEST__/release.sql

DSU_DB_CONTAINER="$container" node --test backend/__TEST__/integration/database.test.js
