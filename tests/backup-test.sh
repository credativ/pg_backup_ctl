#!/bin/bash
# This script tests pg_backup_ctl. Take a look at the README file for further information!

if [ "$EUID" -eq 0 ]; then
	is_root=1
else
	is_root=0
fi

function append_to_file() { # Does what it says on the tin; we need this because 'assert command>>file' would redirect the output of 'assert command', not of 'command'
	# NOTE: In hindsight, we might not actually need this due to the changes to assert
	echo "$2">> "$1"
}

function log() {
	echo -e "$1" | sed -e 's/^[[:space:]]*//' >> "${logpath}"
}

function log_output() {
	echo -e "$1"
	log "$1"
}

function ftimestamp() {
	echo "[$(date +"%Y-%m-%d %H:%M:%S")]"
}

function gen_identifier() {
	echo "$(date +"%Y%m%d%H%M%S")$(printf %05d $RANDOM)"
}

function create_snapshot() {
	lvcreate -L 60M -s -n "${id_lv_snap}" "/dev/mapper/${id_vg}-${id_lv}"
}

function final_cleanup() {
	set +e
	rm -f ${id_ipcfile}
	if [ "$finalized" -eq 0 ]; then # this check is obsolete right now, but might make a comeback
		if [ "$1" != "1" ]; then
			pgdo "pg_dropcluster --stop ${current_version} ${test_cluster}"
		fi
		if [ $test_lvm_enabled -eq 1 ]; then
			sudo umount "${id_mnt}"
			sudo lvremove -f "${id_vg}"/"${id_lv}"
			sudo vgremove "${id_vg}"
			sudo pvremove "${id_lodevice}"
			sudo losetup -d "${id_lodevice}"
			sudo umount "${id_ramdisk}"
		fi
		rm -rf "${id_mnt}"/ "${id_ramdisk}"/
		if [ "$1" == "1" ]; then
			local res="Done"
		else
			local res="Aborted"
		fi
		log_output "\n$(ftimestamp) ${res}. Ran ${tests} tests in $(($(date +"%s") - ${start_time})) seconds."
		if [ -n "${failed_versions}" ]; then
			log_output "Not working:${failed_versions}"
		fi
		if [ ${#failed_tests[@]} -eq 0 ]; then
			log_output "All tests passed!"
		else
			log_output "Failed tests (${failed_tests_count}):"
			for ver in "${!failed_tests[@]}"
			do
				log_output "Version ${ver}:"
				log_output "${failed_tests[$ver]}"
			done
		fi
		if [ ${skipped_tests_count} -gt 0 ]; then
			echo "${skipped_tests_count} tests skipped."
		fi
		echo "A log has been saved in ${logpath}"
	fi
	finalized=1
	test "${failed_versions}" && exit 1
	test "${failed_tests_count}" -gt 0 && exit 1
	exit 0
}

function pgdo() {
	if [ $is_root -eq 1 ]; then
		su postgres -c "$@"
	else
		eval "$@" # eval is not evil if it helps with quoting/escaping issues
	fi
	return $?
}

function pgbc() {
	pgdo "pg_backup_ctl -p ${test_port} -A ${test_archive_dir} $*" #&>> "${logpath}"
	return $?
}

function min_version() { # This function can be used at the start of any test so specify the minimum version
	current_min_version="$1"
}

function max_version() { # Use with caution.
	current_max_version="$1"
}

function require_lvm() {
	test_lvm_required=1
}

function assert() {
	assert_equals 0 "$@"
}

function assert_false() {
	assert_op -ne 0 "$@"
}

function assert_equals() {
	assert_op -eq "$@"
}

function assert_op() {
	local do_exec=0
	local assertion_failed=0
	local exit_code=0
	local op="$1"
	shift
	local val="$1"
	shift
	((assert_depth++))
	if [ -z "${current_min_version}" ]; then # No minimum version specified - therefore, run this command for all versions
		do_exec=1
	else
		test "$(echo -e "${current_version}\n${current_min_version}" | sort -V | tail -n 1)" == "${current_version}" && do_exec=1
	fi
	if [ ${test_lvm_enabled} -lt ${test_lvm_required} ]; then
		do_exec=0
	fi
	test -n "${current_max_version}" && test "$(echo -e "${current_version}\n${current_max_version}" | sort -V | head -n 1)" != "${current_version}" && do_exec=0
	if [ ${do_exec} -eq 1 ]; then
		cleanup_required=1 # We're executing something, so we need to clean up later
		if [ -z "$(cat "${id_ipcfile}")" ]; then #If another assertion failed during the current test, we don't need to run any other command either
			echo "$@" >> "${logpath}"
			if [ "${assert_depth}" -gt 1 ]; then # We don't want to split our output everytime one assert runs another one (which can happen!), so we need to check if we're inside a nested assert
				"$@" 2>&1
				exit_code="$?"
			else
				"$@" |& tee -a "${logpath}"
				exit_code="${PIPESTATUS[0]}"
			fi
			if [ ! "${exit_code}" "${op}" "${val}" ]; then
				assertion_failed=1
				test -z "$(cat "${id_ipcfile}")" && echo "$@" > "${id_ipcfile}" # check it again, because nested calls might have failed and changed it in the meantime
			fi
		else
			assertion_failed=1
		fi
	
	fi
	((assert_depth--))
	return ${assertion_failed}
}

function run_test() { # Runs a test function and checks its return value
	local fn="$*"
	current_min_version=""
	current_max_version=""
	test_lvm_required=0
	echo "" > "${id_ipcfile}"
	current_test="${fn}"
	echo -e "\n$(ftimestamp) Starting test \"${fn}\" for PostgreSQL version ${current_version}." >> "${logpath}"
	if [ $cleanup_required -ne 0 ]; then
		#Restore our clean testing environment
		pgdo "pg_ctlcluster ${current_version} ${test_cluster} stop" > /dev/null
		pgdo "rm -rf ${test_archive_dir}/* ${test_tablespaces_from_dir}/* ${test_tablespaces_to_dir}/* ${setting_datadir}/"
		pgdo "rm -f ${setting_config_file} ${setting_hba_file} ${setting_ident_file}"
		cp -a "${default_settings_dir}/$(basename "${setting_datadir}")" "${setting_datadir}"
		cp -a "${default_settings_dir}/$(basename "${setting_config_file}")" "${setting_config_file}"
		cp -a "${default_settings_dir}/$(basename "${setting_hba_file}")" "${setting_hba_file}"
		cp -a "${default_settings_dir}/$(basename "${setting_ident_file}")" "${setting_ident_file}"
		assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} start"
		cleanup_required=0
	fi
	$fn #Run the test
	if [ ${cleanup_required} -ne 0 ]; then # this means we've run some commands
		((tests++))
		local assertion_failed_command="$(cat "${id_ipcfile}")"
		if [ -z "${assertion_failed_command}" ]; then
			# Test successful
			log_output "  $(ftimestamp) Test \"${fn}\" passed."
		else
			# Test failed
			((failed_tests_count++))
			failed_tests["${current_version}"]="${failed_tests["${current_version}"]}  ${fn}\n    -> ${assertion_failed_command}\n"
			print_error "  $(ftimestamp) Test \"${fn}\" failed for version ${current_version}."
		fi
	else
		((skipped_tests_count++))
		log_output "  $(ftimestamp) Test \"${fn}\" skipped, because it is not supported."	
	fi
}

function do_clean_datadir() { # cleans up datadir and tablespaces without removing the folders themselves
	assert rm -rf "${test_tablespaces_from_dir}"/* "${setting_datadir}"/*
	return $?
}

function do_prepare_streaming() {
	assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} stop"
	assert sed -i -e 's/\#max_wal_senders\ =\ 0/max_wal_senders\ =\ 2/g' ${setting_config_file}
	if [ $is_root -eq 1 ]; then
		local pguser="postgres"
	else
		local pguser="${LOGNAME:-$USER}"
	fi
	assert append_to_file "${setting_hba_file}" "local   replication     $pguser                                 trust
host    replication     $pguser         localhost               trust
host    replication     $pguser         127.0.0.1/32            trust"
	assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} start"
	test -z "$(cat ${id_ipcfile})" && return 0
	return 1
}

function do_post_setup() {
	assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} restart"
	assert test "$(pgdo "psql -tAX -c \"SELECT current_setting('archive_command');\"")" != "(disabled)"
	local archive_mode="$(pgdo "psql -tAX -c \"SELECT current_setting('archive_mode');\"")"
	assert test -n "${archive_mode}"
	assert test "${archive_mode}" != "off"
	min_version "9.0"
	local wal_level="$(pgdo "psql -tAX -c \"SELECT current_setting('wal_level');\"")"
	if [ "${wal_level}" != "archive" ] && [ "${wal_level}" != "hot_standby" ] && [ "${wal_level}" != "replica" ] && [ "${wal_level}" != "logical" ]; then # this is such an ugly construct
		log "wal_level was not set correctly!"
		assert false
	fi
	min_version ""
	test -z "$(cat ${id_ipcfile})" && return 0
	return 1
}

function fatal_error() {
	print_error "FATAL: $2"
	failed_versions="$failed_versions $1"
}

function print_error() {
	>&2 echo -e "\e[1;31m$1\e[0m"
	log "$1"
}

failed_versions=""
declare -A failed_tests
failed_tests_count=0
skipped_tests_count=0
test_functions=""
current_version=""
current_test=""
current_min_version=""
current_max_version=""
cleanup_required=0 # specifies whether or not we have to revert everything back to our initial state before running the next test
setting_datadir=""
setting_config_file=""
setting_hba_file=""
setting_ident_file=""
default_settings_dirname="settings"
default_settings_dir=""
id_number=$(gen_identifier)
id_ramdisk="rampg${id_number}"
id_lofile=""
id_lodevice=""
id_vg="vgpg${id_number}"
id_lv="lvpglive${id_number}"
id_mnt="pgdata${id_number}"
id_ipcfile=""
id_logfile="${id_number}.log"
logdirname="log"
logdir="$(pwd)/${logdirname}"
logpath="${logdir}/${id_logfile}"
test_cluster="backuptest${id_number}"
test_port=5432
test_archive_dir=""
test_archive_dirname="backups"
test_datadir=""
test_tablespaces_from_dirname="tablespaces_from"
test_tablespaces_from_dir=""
test_tablespaces_to_dirname="tablespaces_to"
test_tablespaces_to_dir=""
test_live_settings_dirname="livesettings"
test_live_settings_dir=""
test_config_dirname="config"
test_config_dir=""
test_lvm_enabled="${is_root}"
test_lvm_required=0
test_lvmsize="200M"
test_ramdisksize="350M"
test_lvmvolume="pgvg"
test_lvmsnapshotname="pgsnapshotlv"
test_lvmdatadir=""
test_file=""
testsdir="tests.d"
tests=0
finalized=0
assert_depth=0
verbose=0 # TODO: Implement this
interactive=1

set -e # Abort on errors during the initial setup

set -- $(getopt p:d:c:f:L:R:my "$@")

while :; do
	case $1 in
		-p) test_port="$2"; shift;;
		-d) testsdir="$2"; shift;;
		-c) test_cluster="$2${id_number}"; shift;;
		-f) test_file="$2"; shift;;
		-L) test_lvmsize="$2"; shift;;
		-R) test_ramdisksize="$2"; shift;;
		-m) test_lvm_enabled=1;;
		-y) interactive=0;;
		--) shift; break;;
	esac
	shift
done

if [ -z "$*" ]; then
	versions="9.5 9.4 9.3 9.2 9.1 9.0 8.4"
else
	versions="$*"
	shift
fi

if [ ${interactive} -gt 0 ]; then
	read -p "Welcome to the automated pg_backup_ctl testing environment! Note: this script will overwrite the Postgres cluster \"${test_cluster}\". Continue? (y/n) " confirm
	if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
		exit
	fi
fi

mkdir -p "${logdir}"

trap final_cleanup INT TRAP QUIT ABRT TERM EXIT

if [ ${is_root} -eq 1 ]; then
	id_ramdisk="/mnt/${id_ramdisk}"
else
	id_ramdisk="$HOME/${id_ramdisk}"
fi

if [ ${test_lvm_enabled} -eq 1 ]; then
	id_ipcfile="${id_ramdisk}/ipc"
	id_lofile="${id_ramdisk}/pgpv.img"
	id_mnt="${id_ramdisk}/${id_mnt}"
else
	id_ipcfile="$(mktemp)"
	id_mnt="$HOME/${id_mnt}"
fi

mkdir -p "${id_ramdisk}"

if [ ${test_lvm_enabled} -eq 1 ]; then
	sudo mount -t tmpfs -o size=75% none "${id_ramdisk}"
	sudo chown -R postgres:postgres "${id_ramdisk}"
	sudo chmod -R 0700 "${id_ramdisk}"
fi

mkdir -p "${id_mnt}" # the folder in which we mount the volume is located inside the ramdisk, so we can't create it any earleir

if [ ${test_lvm_enabled} -eq 1 ]; then
	dd if=/dev/zero of="${id_lofile}" bs=4096 count="$(($(numfmt --from=auto "${test_ramdisksize}")/4096))"
	id_lodevice=$(sudo losetup -f "${id_lofile}" --show)
	sudo pvcreate "${id_lodevice}"
	sudo vgcreate "${id_vg}" "${id_lodevice}"
	sudo lvcreate -L"${test_lvmsize}" -n"${id_lv}" "${id_vg}"
	sudo mkfs.ext4 "/dev/mapper/${id_vg}-${id_lv}"
	sudo mount "/dev/mapper/${id_vg}-${id_lv}" "${id_mnt}"
	sudo chown -R postgres:postgres "${id_mnt}"
	sudo chmod -R 0700 "${id_mnt}"
fi

# Read all tests in ${testsdir}
test_functions="$(ls -1 "${testsdir}"/ | grep -e "^.*\.sh$" | sed 's/\.[^.]*$//')"
while read -r testfunc; do
	eval "function ${testfunc} {
	$(cat "${testsdir}/${testfunc}.sh")
}"
done <<< "$(echo "${test_functions}")"

if [ -n "${test_file}" ]; then
	test_functions="$(echo "${test_file}" | sed 's/\.[^.]*$//')"
fi

# Let's not abort on errors - we WANT TO provoke errors in our tests, after all
set +e
start_time=$(date +"%s")
log_output "$(ftimestamp) Starting tests for the following versions: ${versions}"

for current_version in ${versions}; do 
	log_output "\nStarting test for PostgreSQL version ${current_version}:"
	test_config_dir="${id_ramdisk}/${test_config_dirname}"
	export PGCLUSTER=${current_version}/${test_cluster}
	export PG_CLUSTER_CONF_ROOT=${test_config_dir}
	#((test_port++))
	pgdo "rm -rf ${id_mnt}/*" # clear our LV; do this as postgres just in case something goes wrong and ${id_mnt} is empty
	pgdo "pg_createcluster ${current_version} ${test_cluster} -d ${id_mnt}/data --logfile ${id_mnt}/${current_version}.log --port ${test_port} --locale de_DE.UTF-8" &>> "${logpath}" #running as root
	if [ $? -ne 0 ]; then
		fatal_error ${current_version} "Creating cluster for ${current_version} failed - skipping this version."
		continue #If this fails already, no need to try and run any tests
	fi
	pgdo "pg_ctlcluster ${current_version} ${test_cluster} start"
	setting_datadir=$(pgdo "psql -tAX -c \"SELECT current_setting('data_directory');\"")
	if [ $? -ne 0 ]; then
		fatal_error ${current_version} "Cannot connect to server for version ${current_version} - skipping this version."
		continue
	fi
	setting_config_file=$(pgdo "psql -tAX -c \"SELECT current_setting('config_file');\"")
	setting_hba_file=$(pgdo "psql -tAX -c \"SELECT current_setting('hba_file');\"")
	setting_ident_file=$(pgdo "psql -tAX -c \"SELECT current_setting('ident_file');\"")
	test_datadir="${setting_datadir}" #This can be set to the same value
	test_archive_dir="${id_ramdisk}/${test_archive_dirname}"
	test_tablespaces_from_dir="${id_ramdisk}/${test_tablespaces_from_dirname}" # placing those in ${id_mnt} might also work
	test_tablespaces_to_dir="${id_ramdisk}/${test_tablespaces_to_dirname}"
	test_live_settings_dir="${id_ramdisk}/${test_live_settings_dirname}"
	default_settings_dir="${id_ramdisk}/${default_settings_dirname}"
	pgdo "mkdir -p ${test_archive_dir} ${test_tablespaces_to_dir} ${test_live_settings_dir} ${default_settings_dir}"
	pgdo "pg_ctlcluster ${current_version} ${test_cluster} stop"
	#Copy our "clean" settings and data directory, so we can restore it for each test
	pgdo "mkdir -p ${default_settings_dir}"
	pgdo "rm -rf ${default_settings_dir}/*"
	cp -a "${setting_datadir}" "${default_settings_dir}"
	cp -a "${setting_config_file}" "${default_settings_dir}"
	cp -a "${setting_hba_file}" "${default_settings_dir}"
	cp -a "${setting_ident_file}" "${default_settings_dir}"
	cleanup_required=1
	#Run the tests we've loaded earlier
 	while read -r testfunc; do
 		run_test "${testfunc}"
 	done <<< "$(echo "${test_functions}")"
	pgdo "pg_dropcluster --stop ${current_version} ${test_cluster}" #Drop this cluster, since we don't need it anymore
done

# Clean up everything
final_cleanup 1
