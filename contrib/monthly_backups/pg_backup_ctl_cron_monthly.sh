#!/bin/bash

# Copyright (c) 2016 credativ GmbH
#
# AUTHORS:
#    Adrian Vondendriesch <adrian.vondendriesch@credativ.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE

set -eu

function fail_with_message ()
{
    echo "$*" 1>&2
    exit 1
}

PGBACKUPCTL="pg_backup_ctl"
BACKUPMETHOD="rsyncbackup"
RETENTION="+1"
KEEPPINNED="+2 months"

# Set TZ to UTC
export TZ="UTC"

test $# -ge 2 || \
    fail_with_message "Usage: $0 <daily|monthly> <cluster> [<confdir>]"

TYPE=$1
CLUSTER=$2
CONFDIR=${3:-/etc/pg_backup_ctl.d/}

# Check the given type
if [ $TYPE != "daily" ] && [ $TYPE != "monthly" ]; then
    fail_with_message "ERROR: type must be 'daily' or 'monthly'"
fi

# Check if the confdir exists
test -d "$CONFDIR" || \
    fail_with_message "ERROR: configuration directory \"$CONFDIR\" does not exist"

# Check if a cluster conf exists
test -f "$CONFDIR/$CLUSTER.conf" || \
    fail_with_message "ERROR: configuration file \"$CONFDIR/$CLUSTER.conf\" does not exist"

# If we reach this point all needed files should be in place.

source "$CONFDIR/$CLUSTER.conf"
test $? -eq 0 || \
    fail_with_message "ERROR: could not source \"$CONFDIR/$CLUSTER.conf\""

# Export connection parameters so pg_backup_ctl use it for connections.
export PGPORT PGHOST PGUSER PGDATA

test -n "$PGARCHIVEDIR" || fail_with_message "ERROR: PGARCHIVEDIR not set"

# Do the backup
$PGBACKUPCTL -A $PGARCHIVEDIR $BACKUPMETHOD
test $? -eq 0 || fail_with_message "ERROR: backup failed"

if [ $TYPE = "monthly" ]; then
    # We do a monthly backup, this means we need to pin the current backup.
    $PGBACKUPCTL -A $PGARCHIVEDIR pin latest
    test $? -eq 0 || fail_with_message "ERROR: pin backup failed"

    # Get a list of all (existing) pinned backups.
    pinned=$($PGBACKUPCTL -A $PGARCHIVEDIR ls | grep "backup_" | \
        grep -v "N/A" | grep "Y" | awk '{print $1};')

    # Check each backup, if its older then 2 months unpin it.
    for backup in $pinned; do
        # rsync_backup_2016-08-05T143358 -> 2016-08-05 14:33:58
        backup_date=$(echo $backup | sed -n "s/.*_\(.*\)T\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\).*/\1 \2:\3:\4/p")
        if [ $(date -d "${backup_date}+UTC ${KEEPPINNED}" +"%s") -lt $(date +"%s") ]; then
            echo "UNPIN $backup (it's older than $KEEPPINNED)"
            $PGBACKUPCTL -A $PGARCHIVEDIR unpin $backup
        fi
    done
fi

# Do the cleanup
$PGBACKUPCTL -A $PGARCHIVEDIR cleanup $RETENTION
test $? -eq 0 || fail_with_message "ERROR: cleanup failed"

exit 0
