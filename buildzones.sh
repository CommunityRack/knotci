#!/usr/bin/env bash
ZONESERIAL=$(date +"%s")
MAGICSTRING="SERIALAUTOUPDATE"

if [ "$1" == "allzones" ]; then
  echo "INFO acting on all *.zone files"
  CHANGEDFILES="*.zone"
elif [ -f .lasthash ]; then
  LASTHASH=$(cat .lasthash)
  echo "INFO .lasthash found: ${LASTHASH}"
  CHANGEDFILES=$(git diff --name-only HEAD "$LASTHASH" -- '*.zone')
else
  echo "INFO .lasthash not found"
  CHANGEDFILES=$(git diff --name-only HEAD HEAD~1 -- '*.zone')
fi

rm -f .oldserials.new && touch .oldserials.new
for file in $CHANGEDFILES; do
  # search for magic string - only do sed when found
  if grep -q "$MAGICSTRING" "$file"; then
    echo "INFO updating serial to $ZONESERIAL in $file"
    sed -i "s/1 ; SERIALAUTOUPDATE/$ZONESERIAL/" "$file"
    echo "${file%.zone}: $ZONESERIAL" >> .oldserials.new
  else
    echo "INFO ${MAGICSTRING} not found in $file"
  fi
done

# Re-construct old serials where auto-update requested
for file in *.zone ; do
  if grep -q "$MAGICSTRING" "$file"; then
    zone="${file%.zone}"
    old_serial="$( grep "^${zone}: " .oldserials | awk '{ print $2; }' | tr -cd 0-9 )"
    # If the file in question isn't known yet, try to restore the value quickly
    [ -z "$old_serial" ] && old_serial="$( date +"%s" -r "$file" )"
    echo "INFO resetting serial in $file to $old_serial"
    sed -i "s/1 ; SERIALAUTOUPDATE/${old_serial}/" "$file"
    echo "${file%.zone}: $old_serial" >> .oldserials.new
  fi
done

mv -f .oldserials.new .oldserials
