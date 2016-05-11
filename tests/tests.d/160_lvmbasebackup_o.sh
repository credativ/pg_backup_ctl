require_lvm
assert 000_setup
assert pgdo "psql -Xf schema-create.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc -L 90M -M "/dev/${id_vg}"/"${id_lv}" -n "pgsnap${id_number}" -N "data" -o noexec lvmbasebackup
# We cannot really check the mount options, because the snapshot will be unmounted by lvmbasebackup anyway; so we're just checking the exit code
assert test "$(ls -1 "${test_archive_dir}/base" 2>/dev/null | wc -l)" -gt 0
