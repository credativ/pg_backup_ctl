require_lvm
assert 000_setup
assert pgdo "psql -Xf schema-create.sql"
assert pgdo "psql -Xf content1.sql"
assert pgbc -L 90M -M "/dev/${id_vg}"/"${id_lv}" -n "pgsnap${id_number}" -N "data" create-lvmsnapshot
assert grep -Eq '^[^ ]+ '"${test_archive_dir}"'/lvm_snapshot[ $]' /proc/mounts
assert test "$(ls -1 "${test_archive_dir}/base" 2>/dev/null | wc -l)" -gt 0
assert pgbc -M "/dev/${id_vg}"/"${id_lv}" -n "pgsnap${id_number}" remove-lvmsnapshot
assert test "$(grep -Eq '^[^ ]+ '"${test_archive_dir}"'/lvm_snapshot[ $]' /proc/mounts; echo $?)" -ne 0
