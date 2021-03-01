
return {
    postgres = {
        up = [[
            DO $$
            BEGIN
            ALTER TABLE IF EXISTS ONLY "wsse_keys" ADD "encrypted_secret" TEXT;
            EXCEPTION WHEN DUPLICATE_COLUMN THEN
            -- Do nothing, accept existing state
            END;
            $$;
        ]]
    },
    cassandra = {
        up = [[
            ALTER TABLE wsse_keys ADD encrypted_secret text;
        ]]
    }
}
