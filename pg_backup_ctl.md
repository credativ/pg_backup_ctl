---
title: PG_BACKUP_CTL(1)
footer: PostgreSQL Tools
header: pg_backup_ctl
---

# NAME

pg_backup_ctl - Utility to back up and recover a running PostgresSQL database server

# SYNOPSIS

**pg_backup_ctl** **-A** _ARCHIVEDIR_ [_OPTIONS_...] _COMMAND_

# DESCRIPTION

**pg_backup_ctl** is a tool to simplify the steps needed to make a full transaction log archival backup of PostgreSQL clusters. All steps performed by this script can also be done manually. See http://www.postgresql.org/docs/current/static/continuous-archiving.html for details. Furthermore, this script implements several functions to prepare for backups using LVM snapshots.

Whenever you call **pg_backup_ctl**, you need to issue a _COMMAND_, which specifies what actions will be taken, and an _ARCHIVEDIR_, which specifies **pg_backup_ctl**'s working directory - which is where backups will be placed and from where they will be restored. Note that for almost all commands, the PostgreSQL server needs to be running.

**pg_backup_ctl** should be run as the **postgres** user (or any other user that runs the postgresql daemon). In addition, if the **LVM** features are used, the user needs the appropriate permissions (add **sudo** execution privileges for **postgres** to the following commands: **lvcreate**, **lvremove**, **lvdisplay**, **mount**, **umount**).

This script supports PostgreSQL 8.3 and above.

# COMMANDS

## setup

Adjust the server configuration for transaction log archival and set up the environment. **pg_backup_ctl** will make the following modifications to **postgresql.conf** (specified in **running_config**):

* **archive_command** will be set to copy archived WAL files to _ARCHIVEDIR_/log/
* **wal_level** will be set to **archive**, if isn't already at **archive** or **hot-standby**.
* **archive_mode** will be set to **on**

In order for these changes to take effect, the PostgreSQL instance needs to be restarted (if they were not already set beforehand). After that, you should be seeing files appearing in _ARCHIVEDIR_/log/.

Since this command provides the basic settings need for all other commands, you would want to make sure to run this before anything else.

## basebackup

Perform a base backup of the currently running PostgreSQL cluster.

You should run this command from a cron job (mind the postgres user)
once a night (once a week or other intervals are also conceivable,
but will lead to huge recovery times for your data volume).

You could replace this step by taking a file system snapshot. This
might save space and time but would otherwise be functionally
equivalent. You can also alter the script accordingly. Look into the
line that calls the **tar** program.

Note that **basebackup** will not work if the cluster uses tablespaces (see **streambackup** for an alternative which does support tablespaces).

## lvmbasebackup

Perform a base backup using an LVM snapshot (requires **-L**, **-M**, **-n**, **-N**).

## create-lvmsnapshot

Create an LVM snapshot for an external backup command like bacula (requires **-L**, **-M**, **-n**, **-N**).

## rsyncbackup

Perform a base backup with rsync.

This command **requires rsync** accessible via **PATH**.
Backups performed with rsyncbackup will save disk space between
multiple runs for unchanged files, since they are just hardlinked.
See the --link-dest parameter of the rsync command.

## streambackup

Perform a streaming base backup.

This command **requires PostgreSQL 9.1** and above and **pg_basebackup**
accessible via **PATH**. The server should be configured to allow
streaming replication connections.

## remove-lvmsnapshot

Remove an LVM snapshot created with create-lvmsnapshot (requires **-M** and **-n**).

## restore _BASEBACKUP_

Restores _BASEBACKUP_ into the directory specified by the **-D** parameter. This directory must already exist and be empty. In case the backup contains tablespaces, the respective target directories need to exist and be empty.

The destination directory will also contain a generated **recovery.conf**, suitable for starting a PostgreSQL instance for recovery immediately.

It is still possible to do the recovery process completely manually. The recovery process is detailed in the documentation.

## currentbackup

Back up the current WAL file and remove old WAL backups. This command should be called from a cronjob.

## cleanup [ _BASEBACKUP_ | _XLOG_ | _+N_ ]

Remove old, unneeded base backups and WAL files. This command sould also run by a cron job.

You would typically run this command from a cron job once a minute (depending on the desired backup frequency).

If _BASEBACKUP_ is specified, then all base backups and WAL files that are **older** than _BASEBACKUP_ will be removed, while _BASEBACKUP_ itself and all newer base backups and WAL files will not be touched. Likewise, you can specify a WAL backup file _XLOG_, in which case anything older than the base backup to which this WAL backup belongs will be removed.

If a positive number _N_ is specified, the cleanup command will treat it as its retention policy and keep at least this number of base backup files.

If no argument is specified, **cleanup** will use the latest base backup as its point of reference, i. e. all WAL files that are not needed by this base backup and all older base backups will be removed.

## ls[+]

Lists available base backups and their size in the current archive. When issued with **+**, the **ls** command will examine the WAL archive and display the minimum WAL segment file required to use the backup to perform a full recovery.

## pin _BASEBACKUP_ | _earliest_ | _latest_ | _+N_

The **pin** command pins the specified base backup. This causes
the cleanup command to keep all required files for restoring
this basebackup including WAL segment files, even if the
specified retention policy would have elected this backup
for eviction. If the base backup is already pinned, this 
command is a noop.

The **pin** command supports three argument types: 

The first one is the name of the base backup to be pinned.

The second form uses a relative number _N_ to pin the nth current
base backup, regardless of its name. E.g, if the catalog
contains three basebackups, "pin +2" will pin the 2nd
basebackup in the list. Please note that the positional argument
requires the _+_ literal.

The last form accepts the argument string _earliest_ or
_latest_. The first pins the eldest existing base backup in the
archive, the latter the most recent one respectively.

## unpin _BASEBACKUP_ | _earliest_ | _latest_ | _+N_

The **unpin** command removes a previously added pin from
the specified base backup. unpin is a noop, if the specified
base backup wasn't pinned yet, though a warning is printed to
STDERR.

The **unpin** command supports three forms of argument types:

The first is the name of the basebackup to be unpinned.

The second format is a number _+N_ which will unpin the _N_th base
backup in the list. E.g. "unpin +2" will unpin the 2nd base
backup. Please note that the positional argument
requires the _+_ literal.

The last form accepts the argument string _earliest_ or
_latest_. The first unpins the eldest existing base backup
in the archive, the latter the most recent one respectively.


# OPTIONS

The following command-line options control actions done by **pg_backup_ctl**.

## -A _ARCHIVEDIR_

The directory which will contain all backup files, configuration files and history files. This parameter is required for all commands.

## -D _DATADIR_

PostgresSQL data directory. If this parameter is not specified, it will be retrieved from a running PostgreSQL instead.

## -T _TABLESPACES_

Target directory for tablespaces during restore. This directory must contain one subdirectory for each tablespace (with the corresponding name). These subdirectories must be empty. The original symlinks in the base backup will be replaced and all tablespaces will be restored to their corresponding folders inside _TABLESPACES_.

## -m

When specified with the **cleanup** command, old archive log files will be backed up before being deleted.

## -z

When specified with the **setup** command, **archive_command** will be configured to use **gzip** to compress archived WAL segments.

## -l _LOCKFILE_

Use lock file to protect against concurrent operation (default is _ARCHIVEDIR_**/.lock**).

## -L _LVMSIZE_

Sets the buffer size for an LVM snapshot. This will be passed directly to **lvcreate** and thus accepts the same units, e. g. "100M".

## -M _VOLUME_

LVM volume identifier from which the snapshot will be created. This needs to be a full path to the device (including "/dev"). Needed for LVM backups.

## -n _SNAPNAME_

LVM snapshot volume name. Needed for LVM backups. The **backup_label** will be named after it.

## -N _LVMDATADIR_

PostgreSQL data directory relative to partition (i. e. the path to _DATADIR_ inside the logical volume).

## -o _MOUNTOPTS_

Additional options for mounting the LVM snapshot. This will be passed to **mount** directly.

## -t _FSTYPE_

File system type of the LVM snapshot. This will be passed to **mount** directly.

## -h _HOSTNAME_

Specifies the host name of the machine on which the PostgreSQL server is running. If the value begins with a slash, it is used as the directory for the Unix domain socket. (See **psql**(1) for details)

## -p _PORT_

Specifies the TCP port or local Unix domain socket file extension on which the server is listening for connections. (See **psql**(1) for details)

## -U _USERNAME_

User name to connect as to the PostgreSQL server.

# EXAMPLES

Setting up the environment and PostgreSQL configuration settings for further cluster backups in /mnt/backup/pgsql:

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **setup**

Performing a base backup (note: the environment should have been setup by running the **setup** command earlier):

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **basebackup**

Performing a streaming base backup (note: the environment should have been setup by running the **setup** command earlier and by configuring the PostgreSQL server to allow streaming replication):

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **streambackup**

Performing a base backup with rsync (note: the environment should have been setup by running the **setup** command earlier, and **rsync** should be accessible via **PATH**):

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **rsyncbackup**

Performing an LVM base backup. PostgreSQL's data dir is the folder "data", which is located on the logical volume "lvpg", which belongs to the volume group "vgpg". Thus, the command is as follows (note: the environment should have been setup by running the **setup** command earlier, and **postgres** has the required privileges):

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **-L** 100M **-M** /dev/vgpg/lvpg **-n** pgsnap -N data **lvmbasebackup**

Copying the current log segment(s):

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **currentbackup**

Listing all available backups:

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **ls+**

Restoring a base backup (e. g. basebackup\_2013-01-04T1517.tar.gz) to the directory /recover/pgsql (the server may not run):

$ **pg_backup_ctl** **-A** /mnt/backup/pgsql **-D** /recovery/pgsql **restore** basebackup\_2013-01-04T1517.tar.gz

$ **pg_ctl** **start** **-D** /recovery/pgsql

# CAVEATS

pg_backup_ctl internally protects itself against concurrent execution
with the **flock** command line tool. This places a lock file into the
archive directory, which will hold an exclusive lock on it to prevent
another **pg_backup_ctl** to concurrently modify the archive. This doesn't
work on network filesystems like SMBFS or CIFS, especially when mounted
from a Windows(tm) server. In this case you should use the **-l** option
to place the lock file into a directory on a local filesystem.
Older distributions don't provide the **flock** command line tool, but you can work around this by commenting out the locking subscripts.

# SEE ALSO

**pg_dump**(1), **psql**(1), **pg_basebackup**(1), **flock**(1)
