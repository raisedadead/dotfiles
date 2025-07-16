#!/usr/bin/env zsh

# get instance id by name
function _mrgsh_aws_get_id() {
	local dependencies=("aws")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local instance_name="${1#aws-}" # Remove aws- prefix from the instance name
	
	if [[ -z "$instance_name" ]]; then
		echo "Error: Instance name is required." >&2
		return 1
	fi

	aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running" \
		--query 'Reservations[].Instances[].InstanceId' \
		--output text |
		head -n 1
}

# start ssh session using aws ssm
function _mrgsh_aws_start() {
	local dependencies=("aws")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local instance_name="${1#aws-}"   # Remove aws- prefix from the instance name
	local aws_profile="${2:-}"        # Optional AWS profile
	local custom_ssh_options="${3:-}" # Custom SSH options placeholder
	
	if [[ -z "$instance_name" ]]; then
		echo "Error: Instance name is required." >&2
		return 1
	fi

	local instance_id=$(_mrgsh_aws_get_id "$instance_name")

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

# main aws ssh function
function _mrgsh_aws() {
	local instance_name="$1"
	local aws_profile="${2:-}"
	local custom_ssh_options="${@:3}" # Capture all additional arguments as custom SSH options

	if [[ -z "$instance_name" ]]; then
		echo "Error: Usage: aws-ssh <instance-name> [aws-profile] [custom-ssh-options]" >&2
		return 1
	fi

	_mrgsh_aws_start "$instance_name" "$aws_profile" "$custom_ssh_options"
}
