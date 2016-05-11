min_version "9.2"
max_version "9.4"
assert 040_streambackup_tablespace
local md5="$(assert pgdo "psql -XqtA -f check.sql")"
assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} stop"
assert do_clean_datadir
assert pgbc -D ${test_datadir} -T ${test_tablespaces_to_dir} restore $(ls ${test_archive_dir}/base/)
assert pgdo "pg_ctlcluster ${current_version} ${test_cluster} start"
assert test "${md5}" == "$(assert pgdo "psql -XqtA -f check.sql")"
