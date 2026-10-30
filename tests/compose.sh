#!/usr/bin/env bash
# Starts a compose stack and checks what runs across its containers: a song upload handled by the
# queue container, and a broadcast that goes through Redis, the queue and reverb containers to a WebSocket
# client on Koel's own address.
# Usage: tests/compose.sh [image] [mysql|postgres]   (defaults to phanan/koel:test and mysql)

set -euo pipefail

IMAGE="${1:-phanan/koel:test}"
DATABASE="${2:-mysql}"
PORT=8089
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
COMPOSE_FILE="$WORK_DIR/compose.yml"

if ! docker run --rm --entrypoint php "$IMAGE" artisan list --raw | grep '^reverb:start' >/dev/null; then
  echo "::warning::The Koel version in $IMAGE doesn't include Reverb. Skipping the compose stack test."
  exit 0
fi

compose() {
  docker compose -p koel-compose-test --project-directory "$ROOT" -f "$COMPOSE_FILE" "$@"
}

query_database() {
  if [[ "$DATABASE" == postgres ]]; then
    compose exec -T database psql -U koel -d koel -tAc "$1"
  else
    compose exec -T database mariadb -ukoel -pkoel-password -N -e "$1" koel
  fi
}

cleanup() {
  status=$?

  if [[ $status -ne 0 ]]; then
    compose logs koel queue reverb || true
    compose exec -T queue sh -c 'tail -n 40 storage/logs/laravel.log' || true
  fi

  compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

sed \
  -e "s|image: phanan/koel$|image: $IMAGE|" \
  -e "s|- 80:80|- $PORT:80|" \
  -e "s|REVERB_PORT: 80$|REVERB_PORT: $PORT|" \
  -e "s|<koel_password>|koel-password|; s|<root_password>|root-password|" \
  -e "s|<reverb_app_key>|test-key|; s|<reverb_app_secret>|test-secret|" \
  "$ROOT/docker-compose.$DATABASE.yml" \
  | awk -v key="base64:$(openssl rand -base64 32)" '{ print } /^  environment: &koel-environment$/ { print "    APP_KEY: " key }' \
  > "$COMPOSE_FILE"

compose up -d --quiet-pull

echo "Waiting for the database..."
for _ in $(seq 1 60); do
  query_database 'SELECT 1' >/dev/null 2>&1 && break
  sleep 2
done

# Koel may have tried its migrations before the database accepted connections.
compose restart koel >/dev/null

echo "Waiting for Koel..."
for _ in $(seq 1 60); do
  [[ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/")" == 200 ]] && break
  sleep 2
done

for service in queue reverb; do
  healthcheck="$(docker inspect -f '{{json .Config.Healthcheck.Test}}' "$(compose ps -q "$service")")"

  if [[ "$healthcheck" != '["NONE"]' ]]; then
    echo "The $service container runs the image's web health check, which it can never pass."
    exit 1
  fi
done

node "$ROOT/tests/live-updates.mjs" \
  "ws://localhost:$PORT/app/test-key?protocol=7&client=js&version=8.4.0" \
  live-updates-test ping \
  docker compose -p koel-compose-test --project-directory "$ROOT" -f "$COMPOSE_FILE" \
    exec -T -u www-data koel php -r '
      require "vendor/autoload.php";
      $app = require "bootstrap/app.php";
      $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
      Illuminate\Support\Facades\Broadcast::on("live-updates-test")->as("ping")->send();
    '

if ! compose logs queue | grep -q 'AnonymousEvent.*DONE'; then
  echo "The broadcast didn't go through the queue container."
  exit 1
fi

echo "Live updates work. Uploading a song..."

upload_status="$(compose exec -T -u www-data koel sh -s <<'UPLOAD'
set -e

php -r '
  require "vendor/autoload.php";
  $app = require "bootstrap/app.php";
  $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
  $app->make(App\Repositories\UserRepository::class)->getOrCreateFirstAdmin();
  App\Models\Setting::set("media_path", "/music");
'

ffmpeg -loglevel error -y -f lavfi -i sine=frequency=440:duration=2 -metadata title="Compose upload test" /tmp/compose-upload-test.mp3

token="$(curl -s -H 'Accept: application/json' -H 'Content-Type: application/json' \
  -d '{"email":"admin@koel.dev","password":"KoelIsCool"}' http://localhost/api/me \
  | php -r 'echo json_decode(stream_get_contents(STDIN))->token;')"

curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' -H "Authorization: Bearer $token" \
  -F file=@/tmp/compose-upload-test.mp3 http://localhost/api/upload
UPLOAD
)"

if [[ "$upload_status" != 202 ]]; then
  echo "Expected the upload to be queued (202), got $upload_status."
  exit 1
fi

uploaded=0
for _ in $(seq 1 30); do
  uploaded="$(query_database "SELECT COUNT(*) FROM songs WHERE title = 'Compose upload test'")"
  [[ "$uploaded" == 1 ]] && break
  sleep 1
done

if [[ "$uploaded" != 1 ]]; then
  echo "The queue container didn't turn the upload into a song."
  exit 1
fi

if ! compose exec -T koel sh -c 'find /music -name "compose-upload-test.mp3" | grep -q .'; then
  echo "The uploaded file isn't in the music library."
  exit 1
fi

echo "Uploads work."

compose stop -t 20 queue reverb >/dev/null 2>&1

for service in queue reverb; do
  exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$(compose ps -aq "$service")")"

  if [[ "$exit_code" != 0 ]]; then
    echo "The $service container didn't stop cleanly (exit code $exit_code)."
    exit 1
  fi
done

echo "The queue and reverb containers stop cleanly."
