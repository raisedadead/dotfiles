#!/bin/bash

#-----------------------------------------------------------
#
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: tailscale-mgmt.sh
#
#-----------------------------------------------------------

function ts_mgmt() {
  # ANSI color codes
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color

  dry_run=true # Enable dry-run by default
  if [[ "$1" == "--no-dry-run" ]]; then
    dry_run=false
    shift # Shift the arguments if dry-run is explicitly set
  fi

  # Check if required commands are available
  required_commands=(jq curl awk)
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}Command $cmd not found. Please install it.${NC}"
      return 1
    fi
  done

  # Get tailnet and target from arguments
  tailnet="$1"
  target="$2"
  if [ -z "$tailnet" ] || [ -z "$target" ]; then
    echo -e "${RED}Usage: ts_mgmt [--no-dry-run] <tailnet> <target>${NC}"
    return 1
  fi

  # Get API key
  api_key=$(op read "${TAILSCALE_OP_ITEM:?set TAILSCALE_OP_ITEM to the 1Password reference of the API key}")
  if [ -z "$api_key" ]; then
    echo -e "${RED}API key not found. Please check the credential is available${NC}"
    return 1
  fi

  # Print table header
  echo -e "$(printf "%-20s %-10s %s" "Device ID" "Status" "Device Name")"

  # Process devices
  response=$(curl -s "https://api.tailscale.com/api/v2/tailnet/$tailnet/devices" -u "$api_key:")
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to fetch devices. Please check your network connection and API key.${NC}"
    return 1
  fi

  echo "$response" | jq -r '.devices[] | "\(.id)\t\(.name)"' |
    while IFS=$'\t' read -r device_id device_name; do
      if [[ $device_name = *"$target"* ]]; then
        device_status="${RED}Removed${NC}"
        if [[ $dry_run == false ]]; then
          curl -s -X DELETE "https://api.tailscale.com/api/v2/device/$device_id" -u "$api_key:"
          if [[ $? -ne 0 ]]; then
            echo -e "${RED}Failed to delete device $device_id. Please check your network connection and API key.${NC}"
            return 1
          fi
        fi
      else
        device_status="${GREEN}Kept${NC}"
      fi
      echo -e "$(printf "%-20s %-10s %s" "$device_id" "$device_status" "$device_name")"
    done
}
