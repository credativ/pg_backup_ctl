assert 000_setup
mkdir -p "${test_archive_dir}/base" "${test_archive_dir}/current" "${test_archive_dir}/log" "${test_archive_dir}/lvm_snapshot"
assert test -z "$(assert pgbc ls+ | head -n -3 | tail -n +3)"
