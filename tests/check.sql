\set ON_ERROR_STOP true

--SELECT md5(string_agg(x.word, chr(10))) FROM (SELECT word FROM words ORDER BY word ASC) AS x;

SELECT md5(array_to_string(array_agg(x.word), chr(10))) FROM (SELECT word FROM words ORDER BY word ASC) AS x; -- provides compatibility with 8.4
