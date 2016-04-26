#!/usr/bin/env bash
. lib.sh

## Initialize
FINALRC=0
CURRENTHASH=$(git rev-parse HEAD)

## Basic sanity check for ALL zones
log_info1 "Check zone syntax of all zones with named-checkzone"

for zone in *.zone; do
  log_info2 "Checking zone ${zone}..."
  named-checkzone -i local "${zone%.zone}" "$zone";
  [ $? -eq 0 ] || FINALRC=1
done

## Check that the zone serial of the updated zones
#  is higher than the currently active one
log_info1 "Compare serial numbers of changed zones"

if [ "$1" == "allzones" ]; then
  log_info1 "acting on all *.zone files"
  CHANGEDFILES="*.zone"
elif [ -f .lasthash ]; then
  CHANGEDFILES="$(git diff --name-only HEAD "$( < .lasthash )" -- '*.zone')"
else
  CHANGEDFILES="$(git diff --name-only HEAD HEAD~1 -- '*.zone')"
fi

if [ -z "$NS_HIDDENMASTER" ]; then
  log_info2 "SKIPPING - NS_HIDDENMASTER not set"
else
  for file in $CHANGEDFILES; do
    log_info2 "Checking ${file}..."
    if [ ! -f $file ]; then
      echo "SKIPPING - ${file} - file not found"
      continue
    fi
    zone="${file%.zone}"

    # Find current active serial on hidden master - skip check if not there
    current_serial="$(dig +short "$zone" soa @$NS_HIDDENMASTER | awk '{print $3}')"
    if [ -z "$current_serial" ]; then echo "SKIPPING - ${zone} - current serial not found"; continue; fi

    # Find new serial
    new_serial="$(named-checkzone -i none "$zone" "$file" | grep "loaded serial" | awk '{print $5}' | tr -cd 0-9)"
    if [ "$new_serial" == "" ]; then echo "NOT PASSED - ${zone} - new serial not found"; FINALRC=1; continue; fi

    # Compare new and active serial
    if [ "$new_serial" -gt "$current_serial" ]; then
      echo "PASSED - ${zone} - new serial ${new_serial} is higher than currently active serial ${current_serial}."
    elif [ $(( $current_serial + 2147483647 )) -ge 4294967296 ] && [ $(( ($current_serial + 2147483647) % 4294967296 )) -ge "$new_serial" ]; then
      echo "PASSED - ${zone} - new serial ${new_serial} rolled over from current serial ${current_serial}."
    else
      echo "NOT PASSED - ${zone} - new serial ${new_serial} is NOT higher than currently active serial ${current_serial}."
      FINALRC=1
    fi
  done
fi

log_info2 "Checking zonefiles: Final RC ${FINALRC}"

## End script
exit $FINALRC

