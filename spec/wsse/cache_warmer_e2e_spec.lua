local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

describe("CacheWarmer #e2e", function()

    local send_admin_request
    local consumer

    before_each(function()
        kong_helpers.db:truncate()

        consumer = kong_helpers.db.consumers:insert({
            username = "CacheTestUser"
        })

        kong_helpers.start_kong({ plugins = "wsse" })

        send_admin_request = test_helpers.create_request_sender(kong_helpers.admin_client())
    end)

    after_each(function()
        kong_helpers.stop_kong()
    end)

    context("cache_all_entities", function()
        it("should store consumer in cache", function()
            local cache_key = kong_helpers.db.consumers:cache_key(consumer.id)
            local response = send_admin_request({
                method = "GET",
                path = "/cache/" .. cache_key
            })

            assert.are.equals(200, response.status)
            assert.are.equals("CacheTestUser", response.body.username)
        end)

        it("should store wsse_key in cache", function()
            local wsse_credential = kong_helpers.db.wsse_keys:insert({
                key = "cache_test_user001",
                key_lower = "cache_test_user001",
                consumer = { id = consumer.id }
            })

            local cache_key = kong_helpers.db.wsse_keys:cache_key(wsse_credential.key)
            local response = send_admin_request({
                method = "GET",
                path = "/cache/" .. cache_key
            })

            assert.are.equals(200, response.status)
            assert.are.same(
                {
                    consumer = { id = consumer.id },
                    id = wsse_credential.id,
                    secret = wsse_credential.secret,
                    strict_timeframe_validation = wsse_credential.strict_timeframe_validation,
                    key = "cache_test_user001",
                    key_lower = "cache_test_user001"
                },
                response.body
            )
        end)
    end)
end)