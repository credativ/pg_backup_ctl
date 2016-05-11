assert 020_basebackup
local count="$(assert pgbc ls+ | head -n -3 | tail -n +3 | wc -l)"
assert pgdo "psql -Xf content2.sql"
assert pgbc basebackup
assert test "$(assert pgbc ls+ | head -n -3 | tail -n +3 | wc -l)" -gt "${count}"
