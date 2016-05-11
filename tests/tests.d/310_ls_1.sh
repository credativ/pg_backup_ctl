assert 020_basebackup
assert test "$(assert pgbc ls | head -n -3 | tail -n +3 | wc -l)" -eq 1
