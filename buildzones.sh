#!/usr/bin/env bash
. lib.sh

ZONESERIAL=$(date +"%s")
if [ -z "$MAGICSTRING" ]; then
  MAGICSTRING="1 ; SERIALAUTOUPDATE"
fi

if [ "$1" == "allzones" ]; then
  log_info1 "acting on all *.zone files"
  CHANGEDFILES="*.zone"
elif [ -f .lasthash ]; then
  LASTHASH=$(cat .lasthash)
  log_info1 ".lasthash found: ${LASTHASH}"
  CHANGEDFILES=$(git diff --name-only HEAD "$LASTHASH" -- '*.zone')
else
  log_info1 ".lasthash not found"
  CHANGEDFILES=$(git diff --name-only HEAD HEAD~1 -- '*.zone')
fi

rm -f .oldserials.new && touch .oldserials.new
for file in $CHANGEDFILES; do
  # search for magic string - only do sed when found
  if grep -q "$MAGICSTRING" "$file"; then
    log_info2 "updating serial to $ZONESERIAL in $file"
    sed -i "s/${MAGICSTRING}/${ZONESERIAL}/" "$file"
    echo "${file%.zone}: ${ZONESERIAL}" >> .oldserials.new
  else
    log_info2 "${MAGICSTRING} not found in ${file}"
  fi
done

# Re-construct old serials where auto-update requested
for file in *.zone ; do
  if grep -q "$MAGICSTRING" "$file"; then
    zone="${file%.zone}"
    old_serial="$( grep "^${zone}: " .oldserials | awk '{ print $2; }' | tr -cd 0-9 )"
    # If the file in question isn't known yet, try to restore the value quickly
    [ -z "$old_serial" ] && old_serial="$( date +"%s" -r "$file" )"
    log_info2 "resetting serial in $file to $old_serial"
    sed -i "s/${MAGICSTRING}/${old_serial}/" "$file"
    echo "${file%.zone}: ${old_serial}" >> .oldserials.new
  fi
done

mv -f .oldserials.new .oldserials
