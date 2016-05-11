assert 020_basebackup
assert pgdo "psql -Xf content2.sql"
assert pgdo "psql -Xf content-tx.sql"
assert pgbc basebackup
assert pgdo "psql -Xf content3.sql"
assert pgdo "psql -Xf content-tx.sql"
assert pgbc basebackup
assert pgdo "psql -Xf content-tx.sql"
assert pgbc basebackup
local count_wal="$(ls -1 ${test_archive_dir}/log/ | wc -l)"
assert pgbc cleanup +3
assert test "$(ls -1 ${test_archive_dir}/base/ | wc -l)" -eq 3
assert test "${count_wal}" -gt "$(ls -1 ${test_archive_dir}/log/ | wc -l)"
