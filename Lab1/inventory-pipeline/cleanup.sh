#!/bin/bash
# Cleanup script: removes all Kafka topics and ksqlDB objects created by setup.sh
# This allows you to start fresh with corrected configurations.
#
# Usage: ./cleanup.sh [-h HOST] [-i KEY] [-e ENV]
#   -h HOST   SSH target (e.g. root@163.66.83.182).
#   -i KEY    Path to SSH private key (.pem).
#   -e ENV    Path to .env file.   Default: $SCRIPT_DIR/.env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Capture pre-existing shell env so it can win over .env values later.
PRE_SHELL_SSH_HOST="${SSH_HOST:-}"
PRE_SHELL_SSH_KEY="${SSH_KEY:-}"

SSH_HOST_FLAG=""
SSH_KEY_FLAG=""
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

usage() {
  cat <<EOF
Usage: $0 [-h HOST] [-i KEY] [-e ENV]
  -h HOST   SSH target (e.g. root@163.66.83.182).
  -i KEY    Path to SSH private key (.pem).
  -e ENV    Path to .env file.   Default: $SCRIPT_DIR/.env

SSH_HOST and SSH_KEY may also be provided via:
  - shell environment variables (SSH_HOST=..., SSH_KEY=...)
  - the .env file (SSH_HOST=..., SSH_KEY=...)
Precedence: flag > shell env > .env

Examples:
  $0 -h root@163.66.83.182 -i ./wxdintg-stream-collector-key.pem
  $0                                  # uses SSH_HOST / SSH_KEY from .env
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

while getopts ":h:i:e:" opt; do
  case "$opt" in
    h) SSH_HOST_FLAG="$OPTARG" ;;
    i) SSH_KEY_FLAG="$OPTARG" ;;
    e) ENV_FILE="$OPTARG" ;;
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

# Check required files
[ -f "$SCRIPT_DIR/delete_topics.py" ] || { echo "missing: $SCRIPT_DIR/delete_topics.py"; exit 1; }
[ -f "$SCRIPT_DIR/run_in_cluster.sh" ] || { echo "missing: $SCRIPT_DIR/run_in_cluster.sh"; exit 1; }

echo "==> Target:    $SSH_HOST"
echo "==> Key:       $SSH_KEY"
echo "==> .env:      $ENV_FILE"
echo "==> Remote:    $REMOTE_DIR"
echo

echo "==> Pushing cleanup script and .env..."
remote "mkdir -p $REMOTE_DIR"

# Strip SSH_HOST / SSH_KEY before uploading; those are orchestration-only
# and have no use inside the cluster pods.
TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT
grep -vE '^[[:space:]]*(SSH_HOST|SSH_KEY)[[:space:]]*=' "$ENV_FILE" > "$TMP_ENV" || true
upload "$TMP_ENV" "$SSH_HOST:$REMOTE_DIR/.env"

upload "$SCRIPT_DIR/delete_topics.py" "$SSH_HOST:$REMOTE_DIR/delete_topics.py"
upload "$SCRIPT_DIR/run_in_cluster.sh" "$SSH_HOST:$REMOTE_DIR/run_in_cluster.sh"
remote "chmod +x $REMOTE_DIR/run_in_cluster.sh"

echo
echo "================================================================"
echo "==> Running cleanup: deleting topics and ksqlDB objects"
echo "================================================================"
remote "bash $REMOTE_DIR/run_in_cluster.sh delete_topics"

echo
echo "==> Cleanup completed successfully!"
echo "==> You can now run ./setup.sh to recreate resources with correct configuration."

# Made with Bob
