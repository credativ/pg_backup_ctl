# Introduction: pg_backup_ctl

*man pg\_backup\_ctl* lists the following modes, which all need to be tested and thus provide the basis for the *test cases* (see below):

* setup
* basebackup
* streambackup
* currentbackup
* lvmbasebackup
* create-lvmsnapshot
* remove-lvmsnapshot
* rsyncbackup
* restore
* cleanup
* ls[+]

In order to cover all test cases, a test framework is needed, which sets up the testing environment and runs the desired tests.

# Test framework

The test framework is a *bash* script, which tests a specified number of PostgreSQL versions (8.4, 9.0, 9.1, 9.2, 9.3, 9.4 and 9.5 per default). Before these tests can be run, the script needs to provide a clean environment for testing, which includes cleaning up any clutter left from previous tests as well as setting up the test cluster. Note that all *pg_backup_ctl* commands should be run by the *postgres* user. After the environment is set up, the following test cases can be run:

# Test cases

## General notes

*pg_backup_ctl* has a lot of additional *parameters* (e. g. *-p* or *-D*) which can be specified in addition to the *commands* (e. g. *setup* or *currentbackup*). The meachnisms which check these parameters are always the same for each command, which means that you can test the *-p* parameter, e. g. by issuing `pg_backup_ctl -p 5432 -A /mnt/pg_backup basebackup` and then comparing the result with `pg_backup_ctl -A /mnt/pg_backup basebackup` (which *should* yield the same result, because 5432 is the default Postgres port and will be assumed if *-p* is not specified). If you then wish to test a different command, e. g. `pg_backup_ctl -A /mnt/pg_backup currentbackup`, it doesn't matter if you specify *-p*, because the inner workings that handle this parameter are the same for all commands, which means you've already tested it in the previous *basebackup* command.

These parameters are:

* *-A ARCHIVEDIR* is the directory to which backups will be saved. This must an existing and writable directory. This parameter is required for all commands.
* *-D DATADIR* is the PostgreSQL data directory. If this parameter is not specified, the *DATADIR* will be retrieved from a running PostgreSQL server. In either way, this directory should be at least readable. 
* *-h HOSTNAME* can optionally be used to specify the hostname of the running PostgreSQL server.
* *-p PORT* can optionally be used to specify the port of the running PostgreSQL server.
* *-U USERNAME* can optionally be used to specify the user name to connect to the PostgreSQL server.
* *-l LOCKFILE* can optionally be used to specify a path for a lock file. 

There are also parameters which are specific to certain commands, which will be specified in the individual test cases.

### Postconditions in case of errors

If the preconditions are not met and a test case is executed nonetheless (and if no other postconditions are described for that particular test case), the expected behaviour is that *pg_backup_ctl* prints an error message and returns a non-zero value.

## setup

### Preconditions

* A Postgres cluster (version 8.3 or higher) is up and running and can be reached via *USERNAME*@*HOSTNAME*:*PORT*.

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR setup

#### Notes

* *ARCHIVEDIR* is the directory in which *pg_backup_ctl* should save base backups and WAL backups. This directory does not need to exist prior to running the *setup* command

### Postconditions

The following options have been set in *postgresql.conf* (the exact location of the file can be found by running `SELECT current_setting('config_file');`):

* *archive_command* will be set to a command that copies WAL files into the */log* subdirectory of the specified *ARCHIVEDIR*
* *wal_level* will be set to *archive* (if it wasn't *hot-standby* before)
* *archive_mode* will be set to *on*

In order to apply those changes, the cluster needs to be manually restarted, e. g. by `systemctl restart postgresql@9.5-backuptest` (with *9.5* being your PostgreSQL server version and *backuptest* being the name of the cluster you would like to use).

## setup -z

### Preconditions

* A Postgres cluster (version 8.3 or higher) is up and running and can be reached via *USERNAME*@*HOSTNAME*:*PORT*.

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -z -A ARCHIVEDIR setup

#### Notes

* *-z* enables GZip compression
* *ARCHIVEDIR* is the directory in which *pg_backup_ctl* should save base backups and WAL backups.

### Postconditions

The following options have been set in *postgresql.conf*:

* *archive_command* will be set to a command that copies and compresses WAL files into the */log* subdirectory of the specified *ARCHIVEDIR*
* *wal_level* will be set to *archive* (if it wasn't *hot-standby* before)
* *archive_mode* will be set to *on*

In order to apply those changes, the cluster needs to be manually restarted, e. g. by `systemctl restart postgresql@9.5-backuptest`.

## basebackup

### Preconditions

* A Postgres cluster (version 8.3 or higher) is up and running and can be reached via *USERNAME*@*HOSTNAME*:*PORT*.
* *ARCHIVEDIR/base* is an existing, writable directory (preferably created by executing *setup* prior to creating the base backup).
* The cluster does not use tablespaces 
* A base backup with the same name (i. e. the current date including hours and minutes, and seconds) does not exist

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR basebackup

#### Notes

* *ARCHIVEDIR* is the directory in which *pg_backup_ctl* should save the base backup

### Postconditions

* A base backup is saved in *ARCHIVEDIR/base*.

## streambackup

### Preconditions

* A Postgres cluster (version 8.3 or higher) is up and running and can be reached via *USERNAME*@*HOSTNAME*:*PORT*.
* *ARCHIVEDIR/base* is an existing, writable directory (preferably created by executing *setup* prior to creating the base backup).
* A streaming backup with the same name (i. e. the current date including hours and minutes, and seconds) does not exist

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR streambackup

#### Notes

* *ARCHIVEDIR* is the directory in which *pg_backup_ctl* should save the base backup

### Postconditions

* A streaming base backup is saved in *ARCHIVEDIR/base*. This should include a base backup as well as backups for the table spaces, if there were any.

## currentbackup

### Preconditions

* A Postgres cluster (version 8.3 or higher) is up and running and can be reached via *USERNAME*@*HOSTNAME*:*PORT*.
* *DATADIR* is an existing directory

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR currentbackup

### Postconditions

* All WAL files currently in use by Postgres have been copied to *ARCHIVEDIR*/current
* If there have been WAL files from a previous *currentbackup* in *ARCHIVEDIR*/current, those have been removed now

## rsyncbackup

### Preconditions

* A Postgres cluster (version 8.3 or higher) is up and running and can be reached via *USERNAME*@*HOSTNAME*:*PORT*.
* *rsync* is available on the system and accessible via *PATH*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR rsyncbackup

### Postconditions

* An rsync base backup is saved in *ARCHIVEDIR/base*. This should include a base backup as well as backups for the table spaces, if there were any.

## lvmbasebackup

### Preconditions

* *LVMSIZE* is a valid size for the snapshot
* *VOLUME* is the logical volume from which the snapshot should be taken
* *NAME* is a valid name for the snapshot
* *LVMDATADIR* is relative path of PostgreSQL's data directory inside the LVM volume
* The user executing this command (preferably *postgres*) has passwordless *sudo* privileges for the following commands: *lvcreate*, *lvremove*, *lvdisplay*, *mount* and *umount*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -L LVMSIZE -M VOLUME -n NAME -N LVMDATADIR lvmbasebackup

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* A backup of the contents of the LVM snapshot is saved inside *ARCHIVEDIR*

## lvmbasebackup -o

### Preconditions

* *LVMSIZE* is a valid size for the snapshot
* *VOLUME* is the logical volume from which the snapshot should be taken
* *NAME* is a valid name for the snapshot
* *LVMDATADIR* is relative path of PostgreSQL's data directory inside the LVM volume
* *MOUNTOPTIONS* are valid mount options
* The user executing this command (preferably *postgres*) has passwordless *sudo* privileges for the following commands: *lvcreate*, *lvremove*, *lvdisplay*, *mount* and *umount*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -L LVMSIZE -M VOLUME -n NAME -N LVMDATADIR -o MOUNTOPTIONS lvmbasebackup

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* A backup of the contents of the LVM snapshot is saved inside *ARCHIVEDIR*

## lvmbasebackup -t

### Preconditions

* *LVMSIZE* is a valid size for the snapshot
* *VOLUME* is the logical volume from which the snapshot should be taken
* *NAME* is a valid name for the snapshot
* *LVMDATADIR* is relative path of PostgreSQL's data directory inside the LVM volume
* *FSTYPE* is the filesystem type of the logical volume, and is recognized by *mount*
* The user executing this command (preferably *postgres*) has passwordless *sudo* privileges for the following commands: *lvcreate*, *lvremove*, *lvdisplay*, *mount* and *umount*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -L LVMSIZE -M VOLUME -n NAME -N LVMDATADIR -t FSTYPE lvmbasebackup

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* A backup of the contents of the LVM snapshot is saved inside *ARCHIVEDIR*

## create-lvmsnapshot

### Preconditions

* *LVMSIZE* is a valid size for the snapshot
* *VOLUME* is an existing LVM volume group on which the snapshot can be created
* *NAME* is a valid name for the snapshot
* *LVMDATADIR* is relative path of PostgreSQL's data directory inside the LVM volume

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -L LVMSIZE -M VOLUME -n NAME -N LVMDATADIR create-lvmsnapshot

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* An LVM snapshot of the volume containing the database is mounted in *ARCHIVEDIR*

## create-lvmsnapshot -o

### Preconditions

* *LVMSIZE* is a valid size for the snapshot
* *VOLUME* is an existing LVM volume group on which the snapshot can be created
* *NAME* is a valid name for the snapshot
* *LVMDATADIR* is relative path of PostgreSQL's data directory inside the LVM volume
* *MOUNTOPTIONS* are valid mount options
* The user executing this command (preferably *postgres*) has passwordless *sudo* privileges for the following commands: *lvcreate*, *lvremove*, *lvdisplay*, *mount* and *umount*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -L LVMSIZE -M VOLUME -n NAME -N LVMDATADIR -o MOUNTOPTIONS create-lvmsnapshot

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* An LVM snapshot of the volume containing the database is mounted in *ARCHIVEDIR*

## create-lvmsnapshot -t

### Preconditions

* *LVMSIZE* is a valid size for the snapshot
* *VOLUME* is an existing LVM volume group on which the snapshot can be created
* *NAME* is a valid name for the snapshot
* *LVMDATADIR* is relative path of PostgreSQL's data directory inside the LVM volume
* *FSTYPE* is the filesystem type of the logical volume, and is recognized by *mount*
* The user executing this command (preferably *postgres*) has passwordless *sudo* privileges for the following commands: *lvcreate*, *lvremove*, *lvdisplay*, *mount* and *umount*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -L LVMSIZE -M VOLUME -n NAME -N LVMDATADIR -t FSTYPE create-lvmsnapshot

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* An LVM snapshot of the volume containing the database is mounted in *ARCHIVEDIR*

## remove-lvmsnapshot

### Preconditions

* *VOLUME* is an existing LVM volume group on which the snapshot can be created
* *NAME* is an existing LVM snapshot

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -M VOLUME -n NAME remove-lvmsnapshot

#### Notes

* *VOLUME* should be the full device path to the logical volume, e. g. */dev/yourvg/yourlv*

### Postconditions

* The LVM snapshot has been removed

## restore

### Preconditions

* A base backup named *BASEBACKUP* exists in *ARCHIVEDIR*
* *DATADIR* is an existing, empty and writable directory
* If the base backup contains tablespaces, the respective target directories need to exist and be empty

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -D DATADIR restore BASEBACKUP
	
#### Notes

* *ARCHIVEDIR* is the directory from which *pg_backup_ctl* should restore the base backup
* *DATADIR* is the directory into which the base backup will be restored
* *BASEBACKUP* is the name of the base backup. In case of a simple base backup, this can be a a gzip compress tarball; in case of a streaming backup, for instance, it could be a folder

### Postconditions

* The contents of *BASEBACKUP* have been restored to *DATADIR*
* *DATADIR* contains a *recovery.conf* file, containing a recovery command, which will be executed by Postgres in order to restore all backed up WAL files
* If the backup contained tablespaces, these will be restored to their respective folders

## restore -T

### Preconditions

* A base backup named *BASEBACKUP* exists in *ARCHIVEDIR*
* *DATADIR* is an existing and empty directory
* If the base backup contains tablespaces, *TABLESPACES* needs to contain one subfolder for each tablespace. These folders must be empty.

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -D DATADIR restore -T TABLESPACES BASEBACKUP
	
#### Notes

* *ARCHIVEDIR* is the directory from which *pg_backup_ctl* should restore the base backup
* *DATADIR* is the directory into which the base backup will be restored
* *BASEBACKUP* is the name of the base backup. In case of a simple base backup, this can be a a gzip compress tarball; in case of a streaming backup, for instance, it could be a folder

### Postconditions

* The contents of *BASEBACKUP* have been restored to *DATADIR*
* *DATADIR* contains a *recovery.conf* file, containing a recovery command, which will be executed by Postgres in order to restore all backed up WAL files
* If the backup contained tablespaces, these will be restored to the respective subfolders in *TABLESPACES*
* The symbolic links in *DATADIR*/pg_tblspc link to the tablespaces located in *TABLESPACES*

## cleanup 0

### Preconditions

* *ARCHIVEDIR* is an existing, empty directory

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup

### Postconditions

* *ARCHIVEDIR* is still empty, and no error message is shown

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## cleanup 1

### Preconditions

* *ARCHIVEDIR* is an existing directory that contains a single base backup

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup

### Postconditions

* *ARCHIVEDIR* does not contain WAL files that are older than the aforementioned base backup

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## cleanup 2

### Preconditions

* *ARCHIVEDIR* is an existing directory that contains two base backups

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup

### Postconditions

* *ARCHIVEDIR* does not contain WAL files that are older than the last base backup
* *ARCHIVEDIR* does not contain any base backups that are older than the last base backup

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## cleanup FILENAME

### Preconditions

* *ARCHIVEDIR* is an existing directory
* *FILENAME* is the name of a file or folder in *ARCHIVEDIR*, containing a base backup

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup FILENAME

#### Notes

* This and the following *cleanup* test cases should be called with 0, 1 and 2 base backups in *ARCHIVEDIR* (just like the *cleanup* test cases described above). While those are, of course, three different test cases, only one has been mentioned to keep the list short (and because the descriptions would be rather redundant).

### Postconditions

* *ARCHIVEDIR* does not contain WAL files that are older than the base backup specified in *FILENAME*
* *ARCHIVEDIR* does not contain any base backups that are older than the base backup specified in *FILENAME*

## cleanup XLOG (uncompressed)

### Preconditions

* *ARCHIVEDIR* is an existing directory
* *XLOG* is the name of an uncompressed WAL file in *ARCHIVEDIR*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup XLOG

### Postconditions

* *ARCHIVEDIR* does not contain WAL files that are older than the WAL file specified in *FILENAME*

## cleanup XLOG.gz

### Preconditions

* *ARCHIVEDIR* is an existing directory
* *XLOG* is the name of a gzip-compressed WAL file in *ARCHIVEDIR*

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup XLOG

### Postconditions

* *ARCHIVEDIR* does not contain WAL files that are older than the WAL file specified in *FILENAME*

## cleanup +n

### Preconditions

* *ARCHIVEDIR* is an existing directory
* *RP* (short for *retention policy*) is a numerical value greater than 0

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR cleanup +RP

#### Notes

* Values that should be tested for RP are the boundary cases, i. e. 0 (which is an invalid value), 1, and a higher value. e. g. 3

### Postconditions

* *ARCHIVEDIR* contains the *RP* newest base backups (in case there were less than *RP* before running cleanup, the number of base backup files should not have changed) 
* *ARCHIVEDIR* does not contain WAL files that are older than the oldest remaining base backup

## cleanup -m

### Preconditions

* *ARCHIVEDIR* is an existing directory

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR -m cleanup

#### Notes

* The *-m* parameter can be added to any other *cleanup* call, which would result in 5 additional test cases for the aforementioned methods (cleanup FILENAME, cleanup XLOG, ...). However, the inner workings of *-m* are the same no matter what is specified after *cleanup* - *FILENAME*, *XLOG*, etc. only define which files will be declared as "old", and *-m* will archive all files that have been declared as *old* beforehand. This means that for convenience sake, you may test *-m* only once in total.

### Postconditions

* *ARCHIVEDIR* contains a gzipped tarball of all old WAL files. The original WAL files are removed based on what you specified after *cleanup*

## ls 0a

### Preconditions

* *ARCHIVEDIR* is an existing, empty directory

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR ls

### Postconditions

* *pg_backup_ctl* does not print any files to the standard output

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## ls 0b

### Preconditions

* *ARCHIVEDIR* is an existing directory that contains some files, but no base backups

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR ls

### Postconditions

* *pg_backup_ctl* does not print any files to the standard output

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## ls 1

### Preconditions

* *ARCHIVEDIR* is an existing directory that contains a single base backup

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR ls

### Postconditions

* A list containing only the aforementioned base backup and its file size is printed to the standard output

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## ls 2

### Preconditions

* *ARCHIVEDIR* is an existing directory that contains two base backups

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR ls

### Postconditions

* A list containing exactly those base backups and their file sizes is printed to the standard output

### Postconditions (error)

* An error message is printed if *ARCHIVEDIR* does not exist

## ls+

### Preconditions

* *ARCHIVEDIR* is an existing directory

### Execution

This test case is executed by running the following command:

	pg_backup_ctl -A ARCHIVEDIR ls+

#### Notes

* This command lists more information than a simple *ls*. You can use the same test cases as with *ls*, i. e. in a folder with 0, 1 or 2 base backups. These cases are not individually listed for *ls+* to keep the list short.

### Postconditions

* A list containing all base backups and their file sizes as well as the minimum WAL file required to do a full recovery is printed to the standard output