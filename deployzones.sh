#!/usr/bin/env bash

## Initialize
CURRENTHASH=$(git rev-parse HEAD)
FINALRC=0
RSYNCPARAMS="--itemize-changes --verbose --human-readable --times --checksum --recursive --delete --exclude-from=/etc/rsyncignore --delete-excluded"

if [ "$1" == "allzones" ]; then
  echo "INFO acting on all *.zone files"
  CHANGEDFILES="*.zone"
elif [ -f .lasthash ]; then
  CHANGEDFILES="$(git diff --name-only HEAD "$( < .lasthash )" -- '*.zone')"
else
  CHANGEDFILES="$(git diff --name-only HEAD HEAD~1 -- '*.zone')"
fi

if [ -z "$SSH_USER" ]; then
  SSH_USER="knot"
fi
if [ -z "$RSYNC_DEST_DIR" ]; then
  RSYNC_DEST_DIR="zones"
fi

if [ -z "$NS_HIDDENMASTER" ]; then
  echo "FAILED - NS_HIDDENMASTER not set - don't know where to sync to"
  exit 1
elif [ -z "$SSH_PRIVATE_KEY" ]; then
  echo "FAILED - SSH_PRIVATE_KEY not set - cannot sync without SSH key"
  exit 1
else
  echo "INFO Deploy zones with rsync and SSH key from SSH_PRIVATE_KEY environment variable"
  eval "$(ssh-agent -s)"
  ssh-add <(echo "$SSH_PRIVATE_KEY")
  mkdir -p ~/.ssh && echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config
  rsync $RSYNCPARAMS '.' "$SSH_USER"@"$NS_HIDDENMASTER":"$RSYNC_DEST_DIR"
  rc=$?; if [[ $rc != 0 ]]; then echo "rsync failed with $rc"; exit 1; fi
fi

echo "==="
if [ "$1" == "allzones" ]; then
  echo "INFO Reloading all zones"
  ssh "$SSH_USER"@"$NS_HIDDENMASTER" knotc reload
  ssh "$SSH_USER"@"$NS_HIDDENMASTER" knotc zone-status
else
  for file in $CHANGEDFILES; do
    zone=$(echo "$file" | cut -d"/" -f2 | sed "s/zone//")
    echo "INFO Reloading zone ${zone}"
    ssh "$SSH_USER"@"$NS_HIDDENMASTER" sudo knotc zone-reload "$zone"
    ssh "$SSH_USER"@"$NS_HIDDENMASTER" sudo knotc zone-status "$zone"
  done
fi

echo "==="
# save current hash for later execution
echo "INFO Saving ${CURRENTHASH} in .lasthash"
echo "$CURRENTHASH" > .lasthash

## End script
exit "$FINALRC"

