local endpoints = require "kong.api.endpoints"

local wsse_keys_schema = kong.db.wsse_keys.schema
local consumers_schema = kong.db.consumers.schema

return {
    ["/consumers/:consumers/wsse_key"] = {
        schema = wsse_keys_schema,
        methods = {
            POST = function(self, db, helpers)
                if self.args.post.key then
                    self.args.post.key_lower = self.args.post.key:lower()
                end
                return endpoints.post_collection_endpoint(wsse_keys_schema, consumers_schema, "consumer")(self, db, helpers)
            end,
            PUT = function(self, db, helpers)
                if self.args.post.key then
                    self.args.post.key_lower = self.args.post.key:lower()
                end
                return endpoints.post_collection_endpoint(wsse_keys_schema, consumers_schema, "consumer")(self, db, helpers)
            end
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