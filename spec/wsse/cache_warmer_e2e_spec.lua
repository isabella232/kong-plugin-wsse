local helpers = require "spec.helpers"
local cjson = require "cjson"

describe("CacheWarmer", function()

    local consumer

    before_each(function()
        helpers.db:truncate()

        consumer = helpers.db.daos.consumers:insert({
            username = "CacheTestUser"
        })
    end)

    after_each(function()
        helpers.stop_kong()
    end)

    context("cache_all_entities", function()
        it("should store consumer in cache", function()
            helpers.start_kong({ plugins = "wsse" })

            local cache_key = helpers.db.daos.consumers:cache_key(consumer.id)

            local raw_response = assert(helpers.admin_client():send {
                method = "GET",
                path = "/cache/" .. cache_key,
            })

            local body = assert.res_status(200, raw_response)
            local response = cjson.decode(body)

            assert.is_equal(response.username, "CacheTestUser")
        end)

        it("should store wsse_key in cache", function()
            local wsse_credential = helpers.dao.wsse_keys:insert({
                key = "cache_test_user001",
                key_lower = "cache_test_user001",
                consumer_id = consumer.id
            })

            helpers.start_kong({ plugins = "wsse" })

            local cache_key = helpers.dao.wsse_keys:cache_key(wsse_credential.key)

            local raw_response = assert(helpers.admin_client():send {
                method = "GET",
                path = "/cache/" .. cache_key,
            })

            local body = assert.res_status(200, raw_response)
            local response = cjson.decode(body)

            assert.is_equal(response.key, "cache_test_user001")
        end)
    end)
end)