#!/bin/zsh

# Define the path to the timestamp file
timestamp_file="${HOME}/.last_update_timestamp"

# Get the current timestamp in seconds
current_time=$(date +%s)

# Initialize the last update time to 0 if the file doesn't exist
if [[ -f "$timestamp_file" ]]; then
    last_update=$(<"$timestamp_file")
else
    last_update=0
fi

# Calculate the difference in days within an explicit arithmetic context
diff_days=$(( ($current_time - $last_update) / 86400 ))

# Check if it has been a week or more
if (( diff_days >= 7 )); then
    echo "It has been $diff_days day(s) since the last run. Running updates..."
    # Place the command to update zinit plugins or any other update logic here
    zinit update --all

    # Update the timestamp in the file
    echo "$current_time" > "$timestamp_file"
else
    echo "Last checked $diff_days day(s) ago. No need to update."
fi
