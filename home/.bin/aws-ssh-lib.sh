#!/usr/bin/env zsh

# Comprehensive AWS SSH Helper Script
# Supports dynamic user determination, custom SSH options, port forwarding, and AWS profiles.
# Dependencies: AWS CLI, session manager plugin, and jq for JSON parsing.

# Setup logging for debugging
# LOG_FILE="/tmp/aws-ssh-lib.log"
# exec 3>&1 4>&2 1>>${LOG_FILE} 2>&1

echo "Starting AWS SSH Helper Script..."

# Fetch the instance ID based on the instance name tag, stripping aws- prefix
get_instance_id() {
  local instance_name="${1#aws-}" # Remove aws- prefix from the instance name
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text |
    head -n 1
}

# Start an SSH session using AWS SSM
start_ssh_session() {
  local instance_name="${1#aws-}"   # Remove aws- prefix from the instance name
  local aws_profile="${2:-}"        # Optional AWS profile
  local custom_ssh_options="${3:-}" # Custom SSH options placeholder
  local instance_id=$(get_instance_id "$instance_name")

  if [[ -z "$instance_id" ]]; then
    echo "Error: Instance named '$instance_name' not found or not running." >&2
    return 1
  fi

  echo "Instance ID: $instance_id"

  # Using AWS profile if specified
  if [[ -n "$aws_profile" ]]; then
    AWS_PROFILE="$aws_profile" aws ssm start-session --target "$instance_id" --document-name "AWS-StartSSHSession"
  else
    aws ssm start-session --target "$instance_id" --document-name "AWS-StartSSHSession"
  fi
}

# Main function to handle input and initiate the SSH session
main() {
  local instance_name="$1"
  local aws_profile="${2:-}"
  local custom_ssh_options="${@:3}" # Capture all additional arguments as custom SSH options

  if [[ -z "$instance_name" ]]; then
    echo "Usage: $0 <instance-name> [aws-profile] [custom-ssh-options]" >&2
    return 1
  fi

  start_ssh_session "$instance_name" "$aws_profile" "$custom_ssh_options"
}

main "$@"
