#!/bin/bash
# Sync changed blocks from one btrfs part to another
# todo:
#  snapshot cleanup
#  test if its efficient

src=/mnt/testsrc
dst=/mnt/testdst
time=$(date '+%F_%H%M')
if [[ ! -e $src/.snapshot ]]
then
    echo "Creating $src/.snapshot"
    mkdir $src/.snapshot
fi
echo "Creating snapshot $time at $src/.snapshot"
btrfs subvolume snapshot -r $src/ $src/.snapshot/$time
sync
if [[ ! -e $dst/.snapshot ]]
then
    echo "Creating $dst/.snapshot"
    mkdir $dst/.snapshot
fi
# find last snapshot in dst
last=$(ls -t $dst/.snapshot/ | head -1)
tempfile=$(mktemp)
starttime="$(date -u +%s)"
if [[ -z $last ]]
then	# snapshot not found. full sync required
    echo "Snapshot not found. Starting full sync from $src/.snapshot/$time to $dst/.snapshot/"
    echo "Press any key to cancel (3 sec)"
    read -t 3 -n 1
    if [ $? = 0 ]; then echo "Cancelling"; exit; fi
    echo "Continuing"
    sleep 3
    btrfs send $src/.snapshot/$time | tee >(wc -c >$tempfile) | btrfs receive $dst/.snapshot/
else	# snapshot found. only syncing changes
    echo "Snapshot found at $last. Syncing changed blocks from $src/.snapshot/$time to $dst/.snapshot/"
    echo "Press any key to cancel (3 sec)"
    read -t 3 -n 1
    if [ $? = 0 ]; then echo "Cancelling"; exit; fi
    echo "Continuing"
    sleep 3
    btrfs send -p $src/.snapshot/$last $src/.snapshot/$time | tee >(wc -c >$tempfile) | btrfs receive $dst/.snapshot/
fi
endtime="$(date -u +%s)"
elapsed="$(($endtime - $starttime))"
bytes="$(cat $tempfile)"
echo "$bytes bytes transferred in $elapsed seconds"
