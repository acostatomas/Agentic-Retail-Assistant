#!/bin/bash
# Helper that runs on the VM. Packages a Python script + .env into a
# ConfigMap, launches a one-off Job in the `confluent` namespace, and
# streams the pod's logs until completion.
#
# Usage: run_in_cluster.sh <script_basename>
#   e.g. run_in_cluster.sh create_topic   (expects create_topic.py next to this)

set -euo pipefail

SCRIPT_NAME="${1:?usage: $0 <script_basename>}"
NS="${NAMESPACE:-confluent}"
JOB="${SCRIPT_NAME//_/-}-job"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_PATH="$WORKDIR/${SCRIPT_NAME}.py"
ENV_PATH="$WORKDIR/.env"
[ -f "$SCRIPT_PATH" ] || { echo "missing script: $SCRIPT_PATH"; exit 1; }
[ -f "$ENV_PATH" ]    || { echo "missing .env: $ENV_PATH"; exit 1; }

kubectl -n "$NS" delete configmap "$JOB" --ignore-not-found >/dev/null
kubectl -n "$NS" create configmap "$JOB" \
  --from-file=app.py="$SCRIPT_PATH" \
  --from-file=.env="$ENV_PATH" >/dev/null

kubectl -n "$NS" delete job "$JOB" --ignore-not-found >/dev/null

cat <<MANIFEST | kubectl apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB
  namespace: $NS
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: python:3.11-slim
        workingDir: /app
        command: ["bash", "-c"]
        args:
        - |
          set -e
          pip install --quiet --no-input confluent-kafka python-dotenv requests
          python app.py
        volumeMounts:
        - name: code
          mountPath: /app
      volumes:
      - name: code
        configMap:
          name: $JOB
MANIFEST

POD=""
for _ in $(seq 1 30); do
  POD=$(kubectl -n "$NS" get pods -l job-name="$JOB" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  [ -n "$POD" ] && break
  sleep 1
done
[ -n "$POD" ] || { echo "pod did not appear for $JOB"; exit 1; }
echo "Pod: $POD"

kubectl -n "$NS" wait --for=condition=Ready pod/"$POD" --timeout=300s 2>/dev/null || true
kubectl -n "$NS" logs -f "$POD" || true

EXIT=""
for _ in $(seq 1 30); do
  EXIT=$(kubectl -n "$NS" get pod "$POD" \
    -o jsonpath="{.status.containerStatuses[0].state.terminated.exitCode}" 2>/dev/null || true)
  [ -n "$EXIT" ] && break
  sleep 1
done

if [ "${EXIT:-1}" -ne 0 ]; then
  echo "ERROR: pod $POD exited with code ${EXIT:-unknown}"
  exit 1
fi
echo "OK: $SCRIPT_NAME"
