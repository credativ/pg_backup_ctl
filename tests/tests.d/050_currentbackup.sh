assert 000_setup
local content="$(assert ls -1 "${test_archive_dir}/current")"
assert pgdo "psql -Xf schema-create.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc currentbackup
assert test "${content}" != "$(assert ls -1 "${test_archive_dir}/current")"
