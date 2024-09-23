#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Function to check if the latest snapshot is older than one week
is_snapshot_older_than_one_week() {
  latest_snapshot_date=$(sudo timeshift --list | grep "On-demand" | tail -n 1 | awk '{print $3}')
  if [ -z "$latest_snapshot_date" ]; then
    return 0  # No snapshots exist, so we should create one
  fi
  latest_snapshot_timestamp=$(date -d "$latest_snapshot_date" +%s)
  one_week_ago_timestamp=$(date -d '1 week ago' +%s)
  if [ $latest_snapshot_timestamp -lt $one_week_ago_timestamp ]; then
    return 0  # Latest snapshot is older than one week
  else
    return 1  # Latest snapshot is not older than one week
  fi
}

# Check if the latest snapshot is older than one week
if is_snapshot_older_than_one_week; then
  echo "Latest snapshot is older than one week. Proceeding with the script."

  # Step 1: Start a local timeshift snapshot
  echo "Creating a local timeshift snapshot..."
  sudo timeshift --create --comments "Automated snapshot" --verbose
  
  # Step 2: Delete older snapshots except the latest three
  echo "Deleting older snapshots except the latest three..."
 sudo timeshift --list | grep "On-demand" | head -n -3 | awk '{print $1}' | xargs -I {} sudo timeshift --delete --snapshot-id {}
else
  echo "Latest snapshot is not older than one week. Will not create new snapshots."
fi

# Step 3: Open VPN connection
echo "Opening VPN connection..."
sudo wg-quick up $VPN_CONFIG

# Step 4: Check connectivity to $REMOTE_IP
echo "Checking connectivity to $REMOTE_IP..."
if ping -c 1 $REMOTE_IP &> /dev/null
then
  echo "Connectivity to $REMOTE_IP established."
else
  echo "Unable to reach $REMOTE_IP. Exiting."
  exit 1
fi

# Step 5: Upload to remote $REMOTE_IP with rsync and show progress
echo "Uploading snapshots to remote server..."
rsync -av --progress /timeshift/snapshots/ $REMOTE_USER@$REMOTE_IP:$REMOTE_SNAPSHOTS_PATH

# Step 6: Close VPN connection
echo "Closing VPN connection..."
sudo wg-quick down $VPN_CONFIG

echo "Script completed."


