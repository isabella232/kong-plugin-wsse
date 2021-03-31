
return {
    postgres = {
        up = [[
            ALTER TABLE IF EXISTS ONLY "wsse_keys" DROP COLUMN IF EXISTS "encrypted_secret";
        ]]
    },
    cassandra = {
        up = [[
            ALTER TABLE wsse_keys DROP encrypted_secret text;
        ]]
    }
}
