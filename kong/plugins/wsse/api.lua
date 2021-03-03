local endpoints = require "kong.api.endpoints"
local Crypt = require "kong.plugins.wsse.crypt"
local EncryptionKeyPathRetriever = require "kong.plugins.wsse.encryption_key_path_retriever"

local wsse_keys_schema = kong.db.wsse_keys.schema
local consumers_schema = kong.db.consumers.schema

local function create_wsse_key(self, db, helpers)
    local request_body = self.args.post
    
    if request_body.key then
        request_body.key_lower = request_body.key:lower()
    end

    if request_body.secret then
        local path = EncryptionKeyPathRetriever(db):find_key_path()
        if not path then
            return kong.response.exit(412, {
                message = "Encryption key was not defined"
            })
        end
        local crypt = Crypt(path)
        local encrypted_secret = crypt:encrypt(request_body.secret)
        request_body.encrypted_secret = encrypted_secret
    end

    return endpoints.post_collection_endpoint(wsse_keys_schema, consumers_schema, "consumer")(self, db, helpers)
end

return {
    ["/consumers/:consumers/wsse_key"] = {
        schema = wsse_keys_schema,
        methods = {
            POST = create_wsse_key,
            PUT = create_wsse_key
        }
    },
    ["/consumers/:consumers/wsse_key/:wsse_keys"] = {
        schema = wsse_keys_schema,
        methods = {
            before = function(self, db, helpers)
                local consumer, _, err_t = endpoints.select_entity(self, db, consumers_schema)
                if err_t then
                  return endpoints.handle_error(err_t)
                end
                if not consumer then
                  return kong.response.exit(404, { message = "Not found" })
                end
                self.consumer = consumer

                local cred, _, err_t = endpoints.select_entity(self, db, wsse_keys_schema)
                if err_t then
                  return endpoints.handle_error(err_t)
                end

                if not cred or cred.consumer.id ~= consumer.id then
                  return kong.response.exit(404, { message = "Not found" })
                end
                self.wsse_key = cred
            end,
            DELETE = endpoints.delete_entity_endpoint(wsse_keys_schema),
            GET = function(self, db, helpers)
                return kong.response.exit(200, {
                    id = self.wsse_key.id,
                    consumer_id = self.wsse_key.consumer.id,
                    key = self.wsse_key.key,
                    strict_timeframe_validation = self.wsse_key.strict_timeframe_validation,
                    key_lower = self.wsse_key.key_lower
                })
            end
        }
    }
}