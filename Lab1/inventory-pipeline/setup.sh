#!/bin/bash
# Drives the three-step inventory pipeline against a Confluent Platform
# installation running inside Minikube on a remote VM.
#
# Step 1: create the source Kafka topic (inventory.transactions)
# Step 2: create the derived ksqlDB stream + CTAS table -> inventory.availability
# Step 3: produce 20 sample messages
#
# Each step runs as a one-off Kubernetes Job inside the cluster so it can
# resolve the in-cluster DNS names that Kafka/ksqlDB advertise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Capture pre-existing shell env so it can win over .env values later.
PRE_SHELL_SSH_HOST="${SSH_HOST:-}"
PRE_SHELL_SSH_KEY="${SSH_KEY:-}"

SSH_HOST_FLAG=""
SSH_KEY_FLAG=""
# Try root .env first, then fall back to local .env
ROOT_ENV="$(cd "$SCRIPT_DIR/../.." && pwd)/.env"
if [ -f "$ROOT_ENV" ]; then
  ENV_FILE="${ENV_FILE:-$ROOT_ENV}"
else
  ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
fi
STEP="all"
CLEANUP=false
CLEANUP_ONLY=false

usage() {
  cat <<EOF
Usage: $0 [-h HOST] [-i KEY] [-e ENV] [-s STEP] [-c] [-C]
  -h HOST   SSH target (e.g. root@163.66.83.182).
  -i KEY    Path to SSH private key (.pem).
  -e ENV    Path to .env file.   Default: $SCRIPT_DIR/.env
  -s STEP   1 | 2 | 3 | all.     Default: all
  -c        Run cleanup before setup (deletes existing topics/ksqlDB objects)
  -C        Run cleanup ONLY (no setup after)

SSH_HOST and SSH_KEY may also be provided via:
  - shell environment variables (SSH_HOST=..., SSH_KEY=...)
  - the .env file (SSH_HOST=..., SSH_KEY=...)
Precedence: flag > shell env > .env

Examples:
  $0 -h root@163.66.83.182 -i ./wxdintg-stream-collector-key.pem
  $0                                  # uses SSH_HOST / SSH_KEY from .env
  $0 -s 2                             # rerun only step 2
  $0 -c                               # cleanup then run all steps
  $0 -c -s 1                          # cleanup then run only step 1
  $0 -C                               # cleanup only (no setup)
  SSH_HOST=root@1.2.3.4 SSH_KEY=./k.pem $0
EOF
  exit 1
}

# Extract a single KEY's value from an env file (handles optional quotes,
# leading/trailing whitespace, comments). Prints nothing if not found.
get_env_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  awk -v k="$key" -F= '
    /^[[:space:]]*#/ { next }
    {
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      if ($1 == k) {
        sub(/^[^=]+=/, "")
        gsub(/^[ \t]+|[ \t]+$/, "")
        gsub(/^"|"$/, "")
        gsub(/^'\''|'\''$/, "")
        print
        exit
      }
    }' "$file"
}

while getopts ":h:i:e:s:cC" opt; do
  case "$opt" in
    h) SSH_HOST_FLAG="$OPTARG" ;;
    i) SSH_KEY_FLAG="$OPTARG" ;;
    e) ENV_FILE="$OPTARG" ;;
    s) STEP="$OPTARG" ;;
    c) CLEANUP=true ;;
    C) CLEANUP_ONLY=true ;;
    *) usage ;;
  esac
done

# Resolve SSH_HOST / SSH_KEY: flag > shell env > .env value.
ENV_SSH_HOST=""
ENV_SSH_KEY=""
if [ -f "$ENV_FILE" ]; then
  ENV_SSH_HOST="$(get_env_value "$ENV_FILE" SSH_HOST)"
  ENV_SSH_KEY="$(get_env_value "$ENV_FILE" SSH_KEY)"
fi

SSH_HOST="${SSH_HOST_FLAG:-${PRE_SHELL_SSH_HOST:-$ENV_SSH_HOST}}"
SSH_KEY="${SSH_KEY_FLAG:-${PRE_SHELL_SSH_KEY:-$ENV_SSH_KEY}}"

# Relative SSH_KEY from .env: resolve against the .env's directory so the
# .env stays portable regardless of where you invoke the script from.
if [ -n "$SSH_KEY" ] && [ -z "$SSH_KEY_FLAG" ] && [ -z "$PRE_SHELL_SSH_KEY" ] \
   && [ "${SSH_KEY#/}" = "$SSH_KEY" ] && [ ! -f "$SSH_KEY" ]; then
  env_dir="$(cd "$(dirname "$ENV_FILE")" && pwd)"
  if [ -f "$env_dir/$SSH_KEY" ]; then
    SSH_KEY="$env_dir/$SSH_KEY"
  fi
fi

[ -n "$SSH_HOST" ] || { echo "missing SSH host (flag -h, env SSH_HOST, or .env SSH_HOST)"; usage; }
[ -n "$SSH_KEY"  ] || { echo "missing SSH key (flag -i, env SSH_KEY, or .env SSH_KEY)";    usage; }
[ -f "$SSH_KEY"  ] || { echo "key not found: $SSH_KEY"; exit 1; }
[ -f "$ENV_FILE" ] || { echo ".env not found: $ENV_FILE"; exit 1; }

# Ensure key permissions are sane; ssh refuses 0644 keys.
chmod 600 "$SSH_KEY" 2>/dev/null || true

# Ensure the key file ends with a newline. OpenSSH's PEM parser rejects
# keys without a trailing \n with a misleading "invalid format" error,
# even though `file` reports them as valid. Common when the .pem was
# downloaded or copy-pasted through a browser that dropped the final \n.
if [ -n "$(tail -c 1 "$SSH_KEY" 2>/dev/null)" ]; then
  echo "==> $SSH_KEY missing trailing newline, appending one"
  printf '\n' >> "$SSH_KEY"
fi

REMOTE_DIR="/root/inventory-pipeline"
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

remote() { ssh "${SSH_OPTS[@]}" "$SSH_HOST" "$@"; }
upload() { scp "${SSH_OPTS[@]}" "$@"; }

FILES=(create_topic.py create_derived_topic.py produce_messages.py run_in_cluster.sh)
for f in "${FILES[@]}"; do
  [ -f "$SCRIPT_DIR/$f" ] || { echo "missing local file: $SCRIPT_DIR/$f"; exit 1; }
done

# Add delete_topics.py to files list if cleanup is requested
if [ "$CLEANUP" = true ] || [ "$CLEANUP_ONLY" = true ]; then
  [ -f "$SCRIPT_DIR/delete_topics.py" ] || { echo "missing local file: $SCRIPT_DIR/delete_topics.py"; exit 1; }
  FILES+=(delete_topics.py)
fi

echo "==> Target:    $SSH_HOST"
echo "==> Key:       $SSH_KEY"
echo "==> .env:      $ENV_FILE"
echo "==> Remote:    $REMOTE_DIR"
if [ "$CLEANUP_ONLY" = true ]; then
  echo "==> Mode:      Cleanup ONLY"
elif [ "$CLEANUP" = true ]; then
  echo "==> Step:      $STEP"
  echo "==> Cleanup:   Before setup"
else
  echo "==> Step:      $STEP"
  echo "==> Cleanup:   No"
fi
echo

echo "==> Pushing scripts and .env..."
remote "mkdir -p $REMOTE_DIR"

# Strip SSH_HOST / SSH_KEY before uploading; those are orchestration-only
# and have no use inside the cluster pods.
TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT
grep -vE '^[[:space:]]*(SSH_HOST|SSH_KEY)[[:space:]]*=' "$ENV_FILE" > "$TMP_ENV" || true
upload "$TMP_ENV" "$SSH_HOST:$REMOTE_DIR/.env"

for f in "${FILES[@]}"; do
  upload "$SCRIPT_DIR/$f" "$SSH_HOST:$REMOTE_DIR/$f"
done
remote "chmod +x $REMOTE_DIR/run_in_cluster.sh"

run_step() {
  local name="$1" title="$2"
  echo
  echo "================================================================"
  echo "==> Step: $title"
  echo "================================================================"
  remote "bash $REMOTE_DIR/run_in_cluster.sh $name"
}

# Run cleanup if requested
if [ "$CLEANUP" = true ] || [ "$CLEANUP_ONLY" = true ]; then
  echo
  echo "================================================================"
  echo "==> CLEANUP: Deleting existing topics and ksqlDB objects"
  echo "================================================================"
  remote "bash $REMOTE_DIR/run_in_cluster.sh delete_topics"
  echo
  if [ "$CLEANUP_ONLY" = true ]; then
    echo "==> Cleanup completed."
    exit 0
  fi
  echo "==> Cleanup completed. Proceeding with setup..."
  sleep 2
fi

case "$STEP" in
  1)   run_step create_topic         "create inventory.transactions topic" ;;
  2)   run_step create_derived_topic "create ksqlDB stream + inventory.availability" ;;
  3)   run_step produce_messages     "publish 20 sample messages" ;;
  all)
       run_step create_topic         "create inventory.transactions topic"
       run_step create_derived_topic "create ksqlDB stream + inventory.availability"
       run_step produce_messages     "publish 20 sample messages"
       ;;
  *)   echo "unknown step: $STEP"; usage ;;
esac

echo
echo "==> Done."
