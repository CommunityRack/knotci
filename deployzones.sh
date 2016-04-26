#!/usr/bin/env bash
. lib.sh

## Initialize
CURRENTHASH=$(git rev-parse HEAD)
FINALRC=0
RSYNCPARAMS="--itemize-changes --verbose --human-readable --times --checksum --recursive --delete --exclude-from=/etc/rsyncignore --delete-excluded"

if [ "$1" == "allzones" ]; then
  log_info1 "acting on all *.zone files"
  CHANGEDFILES="*.zone"
elif [ -f .lasthash ]; then
  CHANGEDFILES="$(git diff --name-only HEAD "$( < .lasthash )" -- '*.zone')"
else
  CHANGEDFILES="$(git diff --name-only HEAD HEAD~1 -- '*.zone')"
fi

log_info1 "Deploying zonefiles to hidden master"

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
  log_info2 "rsync to ${SSH_USER}@${NS_HIDDENMASTER}:${RSYNC_DEST_DIR} using a temporary SSH agent"
  eval "$(ssh-agent -s)" > /dev/null 2>&1
  ssh-add <(echo "$SSH_PRIVATE_KEY") > /dev/null 2>&1
  mkdir -p ~/.ssh && echo -e "Host *\n\tStrictHostKeyChecking no\n\tLogLevel=quiet\n\n" > ~/.ssh/config
  rsync $RSYNCPARAMS '.' "$SSH_USER"@"$NS_HIDDENMASTER":"$RSYNC_DEST_DIR"
  rc=$?; if [[ $rc != 0 ]]; then echo "rsync failed with $rc"; exit 1; fi
fi

if [ "$1" == "allzones" ]; then
  log_info2 "Reloading all zones with knotc"
  ssh "$SSH_USER"@"$NS_HIDDENMASTER" knotc reload
  ssh "$SSH_USER"@"$NS_HIDDENMASTER" knotc zone-status
else
  for file in $CHANGEDFILES; do
    zone=$(echo "$file" | cut -d"/" -f2 | sed "s/zone//")
    log_info2 "Reloading zone ${zone} with knotc"
    ssh "$SSH_USER"@"$NS_HIDDENMASTER" sudo knotc zone-reload "$zone"
    ssh "$SSH_USER"@"$NS_HIDDENMASTER" sudo knotc zone-status "$zone"
  done
fi

# save current hash for later execution
log_info1 "Saving ${CURRENTHASH} in .lasthash"
echo "$CURRENTHASH" > .lasthash

## End script
exit "$FINALRC"

