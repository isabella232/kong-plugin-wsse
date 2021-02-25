
return {
    postgres = {
        up = [[
            DO $$
            BEGIN
            ALTER TABLE IF EXISTS ONLY "wsse_keys" ADD "encryption_key_path" TEXT;
            EXCEPTION WHEN DUPLICATE_COLUMN THEN
            -- Do nothing, accept existing state
            END;
            $$;
        ]]
    },
    cassandra = {
        up = [[
            ALTER TABLE wsse_keys ADD encryption_key_path text;
        ]]
    }
}
