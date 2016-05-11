min_version "9.1"
assert 000_setup
assert do_prepare_streaming
assert pgdo "mkdir -p ${test_tablespaces_from_dir}/idx ${test_tablespaces_from_dir}/log"
assert pgdo "psql -Xc \"CREATE TABLESPACE \\\"idx\\\" LOCATION '${test_tablespaces_from_dir}/idx'\""
assert pgdo "psql -Xc \"CREATE TABLESPACE \\\"log\\\" LOCATION '${test_tablespaces_from_dir}/log'\""
assert pgdo "psql -Xf schema-create-tblspc.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc streambackup
assert test "$(ls -1 "${test_archive_dir}/base" | wc -l)" -gt 0
