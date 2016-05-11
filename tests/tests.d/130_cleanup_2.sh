assert 020_basebackup
assert pgdo "psql -Xf content2.sql"
assert pgbc basebackup
local count_base="$(ls -1 ${test_archive_dir}/base/ | wc -l)"
local count_wal="$(ls -1 ${test_archive_dir}/log/ | wc -l)"
local filename="$(ls -1t ${test_archive_dir}/base/ | head -n1)"
assert pgbc cleanup
assert test -e "${test_archive_dir}/base/${filename}" # the newest base backup must still be there
assert test "${count_base}" -gt "$(ls -1 ${test_archive_dir}/base/ | wc -l)"
assert test "${count_wal}" -gt "$(ls -1 ${test_archive_dir}/log/ | wc -l)"
