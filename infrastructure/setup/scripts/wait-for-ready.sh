#!/usr/bin/env bash

: '
Wait for EC2 instance to be ready to connect by sending a command via SSM.

Usage:
  wait-for-ready.sh <ec2-instance-id>

References:
- https://stackoverflow.com/questions/62403030/terraform-wait-till-the-instance-is-reachable
'

set -o pipefail
set -o nounset
set -o errexit

ec2_instance_id="$1"

project_root="$(git rev-parse --show-toplevel)"
log_file="$(realpath ${project_root}/setup.log)"

aws_annoying_cli=(uv tool run 'aws-annoying[cli]~=0.11.0')

echo "Waiting for EC2 instance $ec2_instance_id to be ready..." | tee --append "$log_file"
"${aws_annoying_cli[@]}" ec2 wait-for-ready \
  --instance-id "$ec2_instance_id" \
  --max-attempts 20 \
  --delay 15 \
  >>"$log_file" 2>&1
