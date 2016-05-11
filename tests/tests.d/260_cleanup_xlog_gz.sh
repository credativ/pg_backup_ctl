assert 010_setup_z
assert pgdo "psql -Xf schema-create.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc basebackup
assert pgdo "psql -Xf content2.sql"
assert pgbc basebackup
assert pgdo "psql -Xf content3.sql"
assert pgbc basebackup
assert pgdo "psql -Xf content-tx.sql"
local count_wal="$(ls -1 ${test_archive_dir}/log/ | wc -l)"
local filename="$(ls -1t ${test_archive_dir}/log/ | grep -E "\.backup.gz$" | head -n2 | tail -n1)"
assert pgbc cleanup "${filename}"
assert test -e "${test_archive_dir}/log/${filename}"
assert test "${count_wal}" -gt "$(ls -1 ${test_archive_dir}/log/ | wc -l)"
