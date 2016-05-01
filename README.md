# Automation Script for Knot CI

## CI/CD Flow

The scripts available in this Docker image can do the following tasks:

1. `buildzones.sh`: Substitute `1 ; SERIALAUTOUPDATE` with the current Unix
   timestamp on all changed *.zone files since last push.
2. `checkzones.sh`: Validate zonefiles:
  1. Check all *.zone files with `named-checkzone` for errors
  2. Compare currently active serial with new serial on all changed zonefiles
3. `deployzones.sh`:
  1. Rsync all changed zonefiles to hidden master defined in environment variable `NS_HIDDENMASTER`
  2. Reload all changed zones and show currently loaded zone info
  3. Save current git hash into `.lasthash`

The CI process is configured in the hidden file `.gitlab-ci.yml`. (see example below)
All scripts are reading the hidden file `.lasthash` to find out which was the last `HEAD`
checked out. The content of this file will be used to find the changed files to act upon.

### Example `.gitlab-ci.yml`

```
image: communityrack/knotci

zonedelivery:
  script:
    - buildzones.sh
    - checkzones.sh
    - deployzones.sh
  artifacts:
    paths:
      - '*.zone'
  cache:
    paths:
      - .lasthash
      - .oldserials
  only:
    - master
```

## Manually running scripts

The CI tasks are executed in a Docker container, therefore just start a Docker image and
run the scripts in there:

`docker run --rm -it -v FULLPATHTOZONEFILES:/zones communityrack/knotci bash`

All scripts accept the argument `allzones`. If set, it will act on all zones, not only
on the changed ones.

### buildzones.sh

When executed without parameters, it updates the serial on all files changed since last HEAD
(`HEAD HEAD~1`) or since last push when `.lasthash` exists. The parameter `allzones` can be used
to update the serial on all zone files which contain the string `1 ; SERIALAUTOUPDATE`.
It also restores the last serials which it gets from the cached file `.oldserials`.

Environment variables used:

* `MAGICSTRING`: Magicstring for updating zone serial. Default: `1 ; SERIALAUTOUPDATE`

### checkzones.sh

This scripts validates the zonefiles with `named-checkzone` and compares the serial
to the hidden master. The hidden master is configured in the environment variable `NS_HIDDENMASTER`.
To run this script manually, set `NS_HIDDENMASTER` to the address of the hidden master. F.e.:

`NS_HIDDENMASTER=myns.myzone.tld checkzones.sh`

Environment variables used:

* `NS_HIDDENMASTER`: name of the DNS hidden master

### deployzones.sh

Rsyncs all changed files to the hidden master and cleans up the remote (`--delete` option).
The SSH key is taken from the envionment variable `SSH_PRIVATE_KEY` and the hidden master
from `NS_HIDDENMASTER`.

After a successfull sync, all changed zones are reloaded (same mechanism to detect changed zones
as in `buildzones.sh`). To make a full sync and reload all zones, use the `allzones` command line
parameter.

Environment variables used:

* `NS_HIDDENMASTER`: name of the DNS hidden master
* `SSH_USER`: name of the remote SSH user. Default: knot
* `SSH_PRIVATE_KEY`: Private key of the remote SSH user
* `RSYNC_DEST_DIR`: destination directory to sync zonefiles to. Default: zones

