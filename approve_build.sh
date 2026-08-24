#!/bin/bash
# Script untuk approve Jenkins input approval dari dalam container
# Usage: bash approve_build.sh <username> <api_token> <build_number>

USER="${1:-andika101204}"
TOKEN="${2}"
BUILD="${3:-40}"
JOB="devops-demo-platform"
JENKINS="http://localhost:8080"

if [ -z "$TOKEN" ]; then
  echo "ERROR: API token diperlukan."
  echo "Usage: bash approve_build.sh andika101204 YOUR_API_TOKEN 40"
  exit 1
fi

echo ">>> Mengambil CSRF Crumb..."
CRUMB_JSON=$(curl -sf -u "$USER:$TOKEN" "$JENKINS/crumbIssuer/api/json")
if [ $? -ne 0 ]; then
  echo "ERROR: Gagal autentikasi. Cek username/token."
  exit 1
fi

CRUMB_FIELD=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField'])")
CRUMB_VALUE=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumb'])")
echo "Crumb: $CRUMB_FIELD=$CRUMB_VALUE"

echo ""
echo ">>> Mengambil Input ID untuk build #$BUILD..."
PENDING=$(curl -sf -u "$USER:$TOKEN" "$JENKINS/job/$JOB/$BUILD/wfapi/pendingInputActions")
if [ -z "$PENDING" ] || [ "$PENDING" = "[]" ]; then
  echo "ERROR: Tidak ada pending input pada build #$BUILD. Mungkin sudah di-approve atau build tidak ada."
  exit 1
fi

INPUT_ID=$(echo "$PENDING" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "Input ID: $INPUT_ID"

echo ""
echo ">>> Mengirim approval untuk build #$BUILD..."
RESULT=$(curl -sf -X POST \
  -u "$USER:$TOKEN" \
  -H "$CRUMB_FIELD: $CRUMB_VALUE" \
  "$JENKINS/job/$JOB/$BUILD/input/$INPUT_ID/proceed")

echo "BERHASIL! Build #$BUILD approved. Pipeline akan lanjut ke Production."
