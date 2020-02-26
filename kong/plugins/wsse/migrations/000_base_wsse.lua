return {
    postgres = {
        up = [[
            CREATE TABLE IF NOT EXISTS wsse_keys(
                id uuid,
                consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
                key text UNIQUE,
                secret text,
                strict_timeframe_validation boolean DEFAULT TRUE,
                key_lower text UNIQUE,
                PRIMARY KEY (id)
            );
            CREATE INDEX wssekeys_key_idx ON wsse_keys(key);
            CREATE INDEX wssekeys_consumer_idx ON wsse_keys(consumer_id);
            CREATE INDEX wssekeys_key_lower_idx ON wsse_keys(key_lower);
        ]]
    },
    cassandra = {
        up = [[
            CREATE TABLE IF NOT EXISTS wsse_keys(
                id uuid,
                consumer_id uuid,
                key text,
                secret text,
                strict_timeframe_validation boolean,
                key_lower text,
                PRIMARY KEY (id)
            );
            CREATE INDEX IF NOT EXISTS ON wsse_keys(key);
            CREATE INDEX IF NOT EXISTS wsse_key_consumer_id ON wsse_keys(consumer_id);
            CREATE INDEX IF NOT EXISTS ON wsse_keys(key_lower);
        ]]
    }
}