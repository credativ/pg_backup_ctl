assert 000_setup
assert pgdo "psql -Xf schema-create.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc rsyncbackup
assert test "$(ls -1 "${test_archive_dir}/base" | wc -l)" -gt 0
