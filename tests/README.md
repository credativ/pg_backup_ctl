# pg_backup_ctl testing environment

This testing environment runs a series of tests for pg_backup_ctl with each PostgreSQL version specified in the command-line arguments (if none are specified, it will default to 8.4, 9.0, 9.1, 9.2, 9.3, 9.4 and 9.5).

If you want to pass a list of versions to *backup-test.sh*, you need to separate them by spaces, e.g.:

	$ ./backup-test.sh 9.1 9.4 9.5

See below for additional command-line arguments that you can specify.

The individual *tests* that are run for each PostgreSQL versions can be found in the directory *tests.d*. The test suite will scan this folder for files ending in *.sh*, build wrapper functions around them, and execute them in alphabetical order.

The test suite can be run either as *root* or as any unprivileged user. Running as root will automatically set the *-m* parameter, which enables all LVM-related tests and, furthermore, places all files in a ramdisk, which will significantly increase performance (see below for more information). If run as *root*, all PostgreSQL-related calls (e. g. *psql*) will be run as the *postgres* user.

If run as an unprivileged user, all files will be stored in the users *home* folder (unless *-m* is specified). In addition, all calls to *psql* and the likes will be run by the user that executed the script.

While the test suite is running, the status (successful/failed) of each test will be printed to standard output, while more detailed information will be written to a log file in the sub-folder *log*.

## Command-line arguments

Apart from the aformentioned versions, there are some additional parameters you can specify in order to control the behaviour of the test suite. These are as follows:

	-p PORT

If *-p* is set to the value *PORT*, then the test clusters created by *backup-test.sh* will listen to this port instead of the default port (which is 5432). This allows you to run several tests in parallel, e. g. by running

	$ ./backup-test.sh -p 5432 "9.5" &
	$ ./backup-test.sh -p 5433 "9.4"

Another parameter you can specify is 

	-d TESTSDIR

If this parameter is given, then tests are not loaded from *tests.d*, but from *TESTSDIR* instead.

Furthermore, you can specify the following argument:

	-c CLUSTER

This will use *CLUSTER* as the cluster base name (instead of *backuptest*). Note that no matter what you specify, the full cluster name will consist of not only the base name, but also a string of numbers (which are derived from the current time and a 5-digit random number).

If you want to run LVM-related tests (*lvmbasebackup*, *create-lvmsnapshot* and *remove-lvmsnapshot*) but wish to do so without running the script as *root*, you can specify the following:

	-m

Note that if you're doing so, the user you're running the script as needs passwordless *sudo* execution privileges for the following commands: *pvcreate*, *pvremove*, *vgcreate*, *vgremove*, *lvcreate*, *lvremove*, *lvdisplay*, *mount*, *umount*, *losetup*, *mkfs.ext4*, *chown* and *chmod*. Note that if you're running the test suite as *root*, LVM will be enabled by default and you don't need to specify this parameter (and you can't disable LVM either). If *-m* is specified (or when running as *root*), a ramdisk will be created, which will house all data files while the tests are being executed. Inside the ramdisk, a loop device will be created, on which LVM will be used to setup a volume group with a logical volume, which holds PostgreSQL's data dir. The ramdisk will, of course, offer better performance and has the advantage that if something goes wrong and the test suite is not able to clean up after running tests, no leftovers will remain after a reboot.

If you are running LVM tests, you may wish to have a larger (or smaller) logical volume (depending on the tests you run). The default value is *200M*, but you can override it by specifying:

	-L LVMSIZE

*LVMSIZE* can be any unit that LVM understands.

Since logical volumes are created inside a loop device, you need to increase the size of the loop device as your logical volume size increases. It would also make sense doing so if you wish to create multiple snapshots during tests. The default size is *350M*, but you may override this as well:

	-R LOOPSIZE

*LOOPSIZE* can be specified with SI or binary units, e. g. *300M* will be 300000000 bytes, while *300Mi* would be 314572800 bytes.

When executing the test suite, you'll be asked whether or not you want to continue. If you don't want to get asked, you could of course either type `yes | ./backup-test.sh`, or you simple append the following parameter:

	-y

If you wish to run only a single test inside the tests directory, you can do so by passing:

	-f FILENAME

The test suite will still read all other files from the tests dir, which means that you can still reference them in the single test you wish to run.

## Test cases

For a description of all test cases, please check [testcases.md](testcases.md).

## Creating new tests

If you want to write your own test, simply create a new file, name it *SOMETHING.sh* and place it in *tests.d*. You do not need to make the file executable, because it won't be called directly, but rather eval'd. If you want to get an overview of what a typical test file looks like, you can take a look at the existing tests. Here's an example (an early version of *100_restore_streambackup_t.sh*) that uses some of the test suite's features:

	min_version "9.2"
	assert 040_streambackup_tablespace
	local md5="$(assert pgdo "psql -qtAX -f check.sql")"
	assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} stop"
	assert do_clean_datadir
	assert pgbc -D ${test_datadir} -T ${test_tablespaces_to_dir} restore $(ls ${test_archive_dir}/base/)
	assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} start"
	assert test "${md5}" == "$(assert pgdo "psql -qtAX -f check.sql")"

As you see, the test file is a very simple shell script. Because it runs in the context of the test suite, it has access to functions and variables defined in *backup-test.sh*. First things first, so let's start with the following call:

	min_version "9.2"

This is pretty straightforward. As the function name already says, this function is used to specify the minimum PostgreSQL version in which this test should be run. Not all features might be supported by older versions, so naturally, you would want to skip those versions in order not to produce any unnecessary error messages.

Likewise, you can also use:

	max_version "9.2"

This will exclude all versions above *9.2* from your tests. Use this feature carefully, as it is unlikely that features will be removed in future versions; so you would want to test as much as possible by not defining a maximum version.

	assert 040_streambackup_tablespace

*assert* is the most important function in any test. `assert COMMAND` will execute *COMMAND* and then check its return value. If it's non-zero, the test will be marked as failed and subsequent calls to *assert* in the same test will not be called. As seen in the last line of the example, it can be easily combined with *test* in order to check any condition you like.

Now you might be wondering - what kind of command is *040_streambackup_tablespace*? As mentioned above, each test in *tests.d* will be wrapped into a function. This function retains the name of the file (minus the *.sh* extension), which means that it can easily be called from within another test. This way, you can "include" and extend tests you've written earlier, and thus save work and avoid redundancy.

*assert* will write the command that it executes as well as the output of said command into the log file; the original output of the command, however, is not redirected, but cloned, which means that you can still access the output of a command that's run by *assert*, as seen in this line:

	local md5="$(assert pgdo "psql -qtAX -f check.sql")"

*assert* will make sure that `pgdo "psql -qtAX -f check.sql"` runs without errors, while the output will be copied to the local variable *md5*.

Now, what does *pgdo* do? This function is invoked by `pgdo COMMAND` and will execute *COMMAND* as the user *postgres* when run by root; otherwise, it will be executed by the calling user.

	assert do_clean_datadir

*do_clean_datadir* is a built-in function that does as the name suggests - it cleans the data directory (and tablespace directories) for the current test cluster, so a backup can be restored into that folder.

Next, we encounter the following line:

	assert pgbc -D ${test_datadir} -T ${test_tablespaces_to_dir} restore $(ls ${test_archive_dir}/base/)

`pgbc X` is a shortcut for `pgdo "pg_backup_ctl -p ${test_port} -A ${test_archive_dir} X"`, which means that the above command translates to `assert pgdo "pg_backup_ctl -p ${test_port} -A ${test_archive_dir} -D ${test_datadir} -T ${test_tablespaces_to_dir} restore $(ls ${test_archive_dir}/base/)`. Not only will this shortcut save some space, but you also will not have to type the *-p* and *-A* parameters over and over again, since those do not change during a test anyway.

### Function reference

Built-in functions that might be worth looking into; as a rule of thumb, functions starting with *do_* are macros that you might want to use inside tests, whereas other functions are also used internally or have a more specialized task (like *min_version*).

#### log

*Usage*: `log STR`

Writes *STR* into the log file. This is useful for debugging or for just providing additional information.

#### log_output

*Usage*: `log_output STR`

Offers the same functionality as *log*, but writes *STR* to the standard output as well.

#### ftimestamp

*Usage*: `ftimestamp`

Prints a formatted timestamp (`[YYYY-mm-dd HH:MM:SS]`, including the square brackets) to the standard output.

#### pgdo

*Usage*: `pgdo CMD`

Executes *CMD* as *postgres* user. Discussed above.

#### pgbc

*Usage*: `pgbc ARGS`

Cals *pg_backup_ctl* with *ARGS*. Discussed above.

#### min_version

*Usage*: `min_version VERSION`

Specifies *VERSION* as the minimum PostgreSQL version for which this test should be run. Discussed above.

#### max_version

*Usage*: `max_version VERSION`

Specifies *VERSION* as the maximum PostgreSQL version for which this test should be run. Discussed above.

#### assert

*Usage*: `assert CMD`

Executes *CMD*, logs its output to the log file and aborts the test if it is not successful. Discussed above.

#### assert_false

*Usage*: `assert_false CMD`

Like *assert*, but fails the test if *CMD* is successful (rather than unsuccessful).

#### assert_equals

*Usage*: `assert_equals VAL CMD`

Like *assert*, but fails the test if the exit code of *CMD* does not equal *VAL*.

#### assert_op

*Usage*: `assert_op OPERATOR VAL CMD`

Like *assert_equals*, but uses *OPERATOR* to compare the exit code of *CMD* to *VAL*. *OPERATOR* can be any operator that *test* understands, e. g. *-eq*.

#### do_clean_datadir

*Usage*: `do_clean_datadir`

Cleans up PostgreSQL's data directory. Discussed above.

#### do_prepare_streaming

*Usage*: `do_prepare_streaming`

Makes changes to *postgresql.conf* and *pg_hba.conf* to allow streaming replication, and restarts the server afterwards. This is necessary if you invoke a *streambackup*.

#### do_post_setup

*Usage*: `do_post_setup`

Restarts the PostgreSQL cluster and checks if the changes made in a *setup* call were successful.

#### print_error

*Usage*: `print_error STR`

Similar to *log_output*, but colors *STR* red and writes it to standard error rather than standard output.

### Variable reference

Pre-defined variables that you can read, but should very cautious about writing (and honestly, only a handful of those make sense when used within a test):

* *failed_versions*
* *failed_tests*
* *test_functions*
* *current_version*
* *current_test*
* *current_min_version*
* *current_max_version*
* *cleanup_required=0*
* *setting_datadir*
* *setting_config_file*
* *setting_hba_file*
* *setting_ident_file*
* *default_settings_dirname*
* *default_settings_dir*
* *id_number*
* *id_ramdisk*
* *id_lofile*
* *id_lodevice*
* *id_vg*
* *id_lv*
* *id_mnt*
* *id_ipcfile*
* *id_logfile*
* *logdirname*
* *logdir*
* *logpath*
* *test_cluster*
* *test_port*
* *test_archive_dir*
* *test_archive_dirname*
* *test_datadir*
* *test_tablespaces_from_dirname*
* *test_tablespaces_from_dir*
* *test_tablespaces_to_dirname*
* *test_tablespaces_to_dir*
* *test_live_settings_dirname*
* *test_live_settings_dir*
* *test_config_dirname*
* *test_config_dir*
* *test_lvmsize*
* *test_lvmvolume*
* *test_lvmsnapshotname*
* *test_lvmdatadir*
* *tests*
* *finalized*
* *assert_depth*
