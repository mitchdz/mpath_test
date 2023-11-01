#!/bin/bash

targetname="iqn.2016-11.foo.com:target.iscsi"
cwd=$(pwd)
testdir="/mnt/tgtmpathtest"
localhost="127.0.0.1"
portal="${localhost}:3260"
maxpaths=4
backfn="backingfile"
expectwwid="60000000000000000e00000000010001"
testdisk="/dev/disk/by-id/wwn-0x${expectwwid}"

### Setup mpath devices

# Restart tgtd to make sure modules are all loaded
service tgt restart || echo "Failed to restart tgt" >&2

# prep SINGLE test file
truncate --size 100M ${backfn}

# create target
tgtadm --lld iscsi --op new --mode target --tid 1 -T "${targetname}"
# allow all to bind the target
tgtadm --lld iscsi --op bind --mode target --tid 1 -I ALL
# set backing file
tgtadm --lld iscsi --op new --mode logicalunit --tid 1 --lun 1 -b "${cwd}/${backfn}"

# scan for targets (locally)
iscsiadm --mode discovery --type sendtargets --portal ${localhost}

# login
echo "login #1"
iscsiadm --mode node --targetname "${targetname}" --portal ${portal} --login
# duplicate this session (always 1)
for i in $(seq 2 ${maxpaths})
do
    echo "extra login #${i}"
    iscsiadm --mode session -r 1 --op new
done

udevadm settle
sleep 5 # sleep a bit to allow device to be created.

# status summary
echo "Status after initial setup"
tgtadm --lld iscsi --mode target --op show
tgtadm --lld iscsi --op show --mode conn --tid 1
iscsiadm --mode session -P 1
lsscsi -liv
multipath -v3 -ll
dmsetup table

echo "Test WWN should now point to DM"
readlink "${testdisk}" | grep dm
