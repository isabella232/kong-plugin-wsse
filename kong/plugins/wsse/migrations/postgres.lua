return {
    {
        name = "2018-03-01-130000_init_wssekeys",
        up = [[
              CREATE TABLE IF NOT EXISTS wsse_keys(
                id uuid,
                consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
                key text UNIQUE,
                secret text,
                PRIMARY KEY (id)
              );
              CREATE INDEX wssekeys_key_idx ON wsse_keys(key);
              CREATE INDEX wssekeys_consumer_idx ON wsse_keys(consumer_id);
            ]],
        down = [[
              DROP TABLE wsse_keys;
            ]]
    },
    {
        name = "2018-03-09-162200_add_strict_timeframe_validation_defaults",
        up = [[
               ALTER TABLE wsse_keys ADD COLUMN strict_timeframe_validation boolean DEFAULT TRUE;
            ]],
        down = [[
              ALTER TABLE wsse_keys DROP COLUMN strict_timeframe_validation;
            ]]
    },
    {
        name = "2018-06-27-141100_add_lower_case_key_to_wssekeys",
        up = [[
               ALTER TABLE wsse_keys ADD COLUMN key_lower text UNIQUE;
               CREATE INDEX wssekeys_key_lower_idx ON wsse_keys(key_lower);
               UPDATE wsse_keys SET key_lower = lower(key);
            ]],
        down = [[
              ALTER TABLE wsse_keys DROP COLUMN key_lower;
            ]]
    },
}