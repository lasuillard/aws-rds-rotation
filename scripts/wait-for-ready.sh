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

response_code=-1
attempts=0

echo "Waiting for instance ${ec2_instance_id} to be ready..."
while [[ $response_code != 0 && $attempts -le 10 ]]; do
  echo "Attempt $attempts..."
  command_id="$(
    aws ssm send-command \
      --instance-ids "$ec2_instance_id" \
      --document-name "AWS-RunShellScript" \
      --parameters '{"commands":["echo 'ready' >> /tmp/ready.txt"]}' \
      --query 'Command.CommandId' \
      --output text
  )"
  sleep 5
  response_code="$(
    aws ssm get-command-invocation \
      --command-id "$command_id" \
      --instance-id "$ec2_instance_id" \
      --query ResponseCode \
      --output text
  )"
  if [[ "$response_code" == "0" ]]; then
    echo "Instance ${ec2_instance_id} is ready."
    exit 0
  fi
  sleep 30
  ((attempts++))
done

echo "Maximum attempts reached. Last response code: ${response_code}"
exit 1
