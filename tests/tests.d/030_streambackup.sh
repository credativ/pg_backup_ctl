min_version "9.1"
assert 000_setup
assert do_prepare_streaming
assert pgdo "psql -Xf schema-create.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc streambackup
assert test "$(ls -1 "${test_archive_dir}/base" | wc -l)" -gt 0
