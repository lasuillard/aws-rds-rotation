#!/usr/bin/env bash

: '
Connect to the RDS database via tunnel using SSM Session Manager.

Usage:
  PGPASSWORD=<password> psql.sh <local-port> <ec2-instance-id> <remote-host> <remote-port>
'

set -o pipefail
set -o nounset
set -o errexit

local_port="$1"
ec2_instance_id="$2"
remote_host="$3"
remote_port="$4"

project_root="$(git rev-parse --show-toplevel)"
log_file="$(realpath ${project_root}/psql.log)"

aws_annoying_cli=(pipx run 'aws-annoying[cli]~=0.11.0')
pid_file='./psql.pid'

function cleanup() {
  "${aws_annoying_cli[@]}" background kill \
    --pid-file "$pid_file" \
    --remove \
    | tee --append "$log_file"
}
trap cleanup EXIT

# Start tunnel via SSM Session Manager
"${aws_annoying_cli[@]}" background run \
  --pid-file "$pid_file" \
  --terminate-running-process \
  --log-file "$log_file" \
  -- session-manager port-forward \
     --local-port "$local_port" \
     --through "$ec2_instance_id" \
     --remote-host "$remote_host" \
     --remote-port "$remote_port" \
     --reason 'Initializing RDS database via SSM Session Manager' \
  | tee --append "$log_file"

# Wait for connection establishment
timeout=10
while ! (echo > "/dev/tcp/127.0.0.1/${local_port}"); do
  sleep 1
  timeout=$((timeout - 1))
  if [ $timeout -le 0 ]; then
    echo "Timeout waiting for local port $local_port to be ready" | tee --append "$log_file"
    exit 1
  fi
done

# Run psql, replacing current shell with the psql process
export PGHOST='localhost'
export PGPORT="$local_port"

exec psql "${@:5}"
