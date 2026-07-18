#!/usr/bin/env bash

: '
Initialize the RDS database with the Pagila dataset.

Usage:
  init-db.sh <local-port> <ec2-instance-id> <remote-host> <remote-port>
'

set -o pipefail
set -o nounset
set -o errexit

local_port="$1"
ec2_instance_id="$2"
remote_host="$3"
remote_port="$4"

project_root="$(git rev-parse --show-toplevel)"
log_file="$(realpath ${project_root}/db-init.log)"
aws_annoying_cli='pipx run aws-annoying~=0.10.0'

function cleanup() {
  $aws_annoying_cli session-manager stop | tee --append "$log_file"
}
trap cleanup EXIT

# Start SSH tunnel via SSM Session Manager
$aws_annoying_cli session-manager port-forward \
  --terminate-running-process \
  --local-port "$local_port" \
  --through "$ec2_instance_id" \
  --remote-host "$remote_host" \
  --remote-port "$remote_port" \
  | tee --append "$log_file"

# Run SQL scripts
export PGHOST="localhost"
export PGPORT="$local_port"

# Pagila dataset (https://github.com/devrimgunduz/pagila)
pagila_schema_url='https://raw.githubusercontent.com/devrimgunduz/pagila/refs/heads/master/pagila-schema.sql'
pagila_data_url='https://raw.githubusercontent.com/devrimgunduz/pagila/refs/heads/master/pagila-data.sql'

curl --fail --silent --show-error --location \
  "$pagila_schema_url" | psql | tee --append "$log_file"

curl --fail --silent --show-error --location \
  "$pagila_data_url" | psql | tee --append "$log_file"
