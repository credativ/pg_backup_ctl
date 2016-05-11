assert 020_basebackup
local count_wal="$(ls -1 ${test_archive_dir}/log/ | wc -l)"
assert pgbc cleanup
assert test "${count_wal}" -gt "$(ls -1 ${test_archive_dir}/log/ | wc -l)"
