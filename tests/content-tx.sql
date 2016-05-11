\set ON_ERROR_STOP true

SELECT txid_current(), pg_switch_xlog(); 
SELECT txid_current(), pg_switch_xlog(); 
