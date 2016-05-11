require_lvm
assert 150_lvmbasebackup
local md5="$(assert pgdo "psql -XqtA -f check.sql")"
assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} stop"
assert do_clean_datadir
assert pgbc -D ${test_datadir} restore $(ls ${test_archive_dir}/base/ 2> /dev/null)
assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} start"
assert test "${md5}" == "$(assert pgdo "psql -XqtA -f check.sql")"
