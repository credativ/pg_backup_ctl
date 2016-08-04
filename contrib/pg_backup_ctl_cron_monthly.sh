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

PGBACKUPCTL="pg_backup_ctl"
BACKUPMETHOD="rsyncbackup"
RETENTION="+1"

if [ $# -lt 2 ]; then
    echo "Usage: $1 [daily|monthly] <cluster> (<confdir>)" 1>&2
    exit 127
fi

TYPE=$1
CLUSTER=$2
CONFDIR=${3:-"/etc/pg_backup_ctl.d/"}

# Check the given type
if [ $TYPE != "daily" ] && [ $TYPE != "monthly" ]; then
    echo "ERROR: type not specified" 1>&2
    exit 1
fi

# Check if the confdir exists
if [ ! -d "$CONFDIR" ]; then
    echo "ERROR: configuration directory \"$CONFDIR\" does not exist" 1>&2
    exit 2
fi

# Check if a cluster conf exists
if [ ! -f "$CONFDIR/$CLUSTER.conf" ]; then
    echo "ERROR: configuration file \"$CONFDIR/$CLUSTER.conf\" does not exist" 1>&2
    exit 3
fi

# If we reach this point all needed files should be in place.

source "$CONFDIR/$CLUSTER.conf"
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: could not source \"$CONFDIR/$CLUSTER.conf\"" 1>&2
    exit 4
fi

if [ -z "$PGARCHIVEDIR" ]; then
    echo "ERROR: PGARCHIVEDIR not set" 1>&2
    exit 5
fi

# Do the backup
$PGBACKUPCTL -A $PGARCHIVEDIR $BACKUPMETHOD
rc=$?

if [ $rc -ne 0 ]; then
    echo "ERROR: backup failed" 1>&2
    exit 6
fi

# We do a monthly backup, this means we need to pin the current backup
# and unpin the latest backup.
if [ $TYPE = "monthly" ]; then
    $PGBACKUPCTL -A $PGARCHIVEDIR pin latest
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: pin backup failed" 1>&2
        exit 7
    fi

    $PGBACKUPCTL -A $PGARCHIVEDIR unpin earliest
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: unpin backup failed" 1>&2
        exit 8
    fi
fi

# Do the cleanup
$PGBACKUPCTL -A $PGARCHIVEDIR cleanup $RETENTION
rc=$?

if [ $rc -ne 0 ]; then
    echo "ERROR: cleanup failed" 1>&2
    exit 9
fi

exit 0
