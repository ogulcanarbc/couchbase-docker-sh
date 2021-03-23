#!/bin/bash
set -e

STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-60}"
BUCKET_WAIT_TIME="${BUCKET_WAIT_TIME:-60}"
RAM_SIZE_MB="${RAM_SIZE_MB:-256}"
BUCKET_RAM_SIZE_MB="${BUCKET_RAM_SIZE_MB:-256}"
ENABLE_FLUSH="${ENABLE_FLUSH:-1}"

function wait_for_couchbase_server() {
  COUNT=0
  # shellcheck disable=SC2091
  until $(curl --output /dev/null --silent --head --fail http://localhost:8091); do
   # shellcheck disable=SC2004
   COUNT=$((COUNT + 1))
    if [ $COUNT -eq $STARTUP_TIMEOUT ]; then
      echo "couchbase server not set up for $STARTUP_TIMEOUT seconds!.."
      break
    fi
    echo "wait for couchbase server to come up.. try count -> $COUNT"
    sleep 1
  done
}

function cluster_initial() {
  couchbase-cli cluster-init \
    --cluster-username="$CB_REST_USERNAME" \
    --cluster-password="$CB_REST_PASSWORD" \
    --cluster-ramsize="$RAM_SIZE_MB" \
    --cluster-index-ramsize="$RAM_SIZE_MB" \
    --services data,index,query,fts \
    --index-storage-setting default

  if [[ $? != 0 ]]; then
    return 1
  fi
}

function bucket_create() {
  couchbase-cli bucket-create \
    -u "$CB_REST_USERNAME" \
    -p "$CB_REST_PASSWORD" \
    --bucket="${BUCKET}" \
    --bucket-type=couchbase \
    --bucket-ramsize="$BUCKET_RAM_SIZE_MB" \
    --enable-flush="$ENABLE_FLUSH" \
    --bucket-replica=0 \
    --cluster=localhost:8091

  if [[ $? != 0 ]]; then
    return 1
  fi
}

function user_manage_sysadmin() {
  couchbase-cli user-manage -c localhost:8091 \
    -u "$CB_REST_USERNAME" \
    -p "$CB_REST_PASSWORD" \
    --set --rbac-username sysadmin --rbac-password password --rbac-name "sysadmin" --roles admin --auth-domain local

  if [[ $? != 0 ]]; then
    return 1
  fi
}

function user_manage_admin() {
  couchbase-cli user-manage -c localhost:8091 \
    -u "$CB_REST_USERNAME" \
    -p "$CB_REST_PASSWORD" \
    --set --rbac-username admin --rbac-password password --rbac-name "admin" --roles bucket_full_access[*] --auth-domain local

  if [[ $? != 0 ]]; then
    return 1
  fi
}

function create_index() {
  TOTAL_RETRY_COUNT=$((BUCKET_WAIT_TIME - 1))
  RETRY_COUNT=0
  SUCCESS=0
  until [ $RETRY_COUNT -eq $TOTAL_RETRY_COUNT ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    EXIT_CODE=0
    cbc-n1ql -U "couchbase://localhost/$BUCKET" \
      -u "$CB_REST_USERNAME" \
      -P "$CB_REST_PASSWORD" \
      "CREATE PRIMARY INDEX \`primary-index\` ON \`$BUCKET\`" || EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
      SUCCESS=1
      break
    fi
    echo "RETRY: waiting to create primary index on $BUCKET."
    sleep 1
  done

  if [ $SUCCESS -eq 0 ]; then
    echo "FAILURE: bucket did not initialize after $BUCKET_WAIT_TIME seconds."
    exit 1
  fi
}

function main() {
  set -ex
  echo "couchbase UI :8091"
  echo "couchbase logs /opt/couchbase/var/lib/couchbase/logs"

  bash /entrypoint.sh "couchbase-server" &
  echo pid_entry=$!
  wait_for_couchbase_server
  cluster_initial
  bucket_create
  user_manage_sysadmin
  user_manage_admin
  create_index

  set +ex

  wait
}

main
