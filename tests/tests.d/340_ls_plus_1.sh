assert 020_basebackup
assert test -n "$(assert pgbc ls+ | head -n -3 | tail -n +3)"
