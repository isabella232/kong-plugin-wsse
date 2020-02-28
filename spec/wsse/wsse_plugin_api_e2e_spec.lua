local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"
local uuid = require "kong.tools.utils".uuid

describe("WSSE #plugin #api #e2e", function()

    local kong_sdk, send_admin_request
    local consumer

    setup(function()
        kong_helpers.start_kong({ plugins = "wsse" })

        kong_sdk = test_helpers.create_kong_client()
        send_admin_request = test_helpers.create_request_sender(kong_helpers.admin_client())
    end)

    teardown(function()
        kong_helpers.stop_kong()
    end)

    before_each(function()
        kong_helpers.db:truncate()

        consumer = kong_sdk.consumers:create({
            username = "TestUser"
        })
    end)

    context("POST collection", function()
        it("should respond with error when key field is missing", function ()
            local response = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key"
            })

            assert.are.equals(400, response.status)
            assert.are.equals("required field missing", response.body.fields.key)
        end)

        it("should respond with error when the consumer does not exist", function ()
            local response = send_admin_request({
                method = "POST",
                path = "/consumers/1234/wsse_key",
                body = {
                    key = "irrelevant"
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(404, response.status)
            assert.are.equals("Not found", response.body.message)
        end)

        it("should store wsse credentials for the consumer", function ()
            local response = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'irrelevant',
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response.status)
        end)

        it("should store the lowercased key in the key_lower field", function ()
            local response = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'IRRELEVANT',
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response.status)
            assert.are.equals("irrelevant", response.body.key_lower)
        end)
    end)

    context("PUT collection", function()
        it("should respond with error when key field is missing", function ()
            local response = send_admin_request({
                method = "PUT",
                path = "/consumers/" .. consumer.id .. "/wsse_key"
            })

            assert.are.equals(400, response.status)
            assert.are.equals("required field missing", response.body.fields.key)
        end)

        it("should respond with error when the consumer does not exist", function ()
            local response = send_admin_request({
                method = "PUT",
                path = "/consumers/1234/wsse_key",
                body = {
                    key = "irrelevant"
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(404, response.status)
            assert.are.equals("Not found", response.body.message)
        end)

        it("should store wsse credentials for the consumer", function ()
            local response = send_admin_request({
                method = "PUT",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'irrelevant',
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response.status)
        end)

        it("should store the lowercased key in the key_lower field", function ()
            local response = send_admin_request({
                method = "PUT",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'IRRELEVANT',
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response.status)
            assert.are.equals("irrelevant", response.body.key_lower)
        end)
    end)

    context("DELETE entity", function()
        it("should respond with error when the consumer does not exist", function ()
            local response = send_admin_request({
                method = "DELETE",
                path = "/consumers/" .. uuid() .. "/wsse_key/" .. uuid()
            })

            assert.are.equals(404, response.status)
            assert.are.equals("Not found", response.body.message)
        end)

        it("should respond with error when the wsse_key does not exist", function ()
            local response = send_admin_request({
                method = "DELETE",
                path = "/consumers/" .. consumer.id .. "/wsse_key/" .. uuid()
            })

            assert.are.equals(404, response.status)
            assert.are.equals("Not found", response.body.message)
        end)

        it("should remove the wsse_key", function()
            local response_create = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'irrelevant'
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response_create.status)
            local wsse_key = response_create.body

            local response = send_admin_request({
                method = "DELETE",
                path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key.id
            })

            assert.are.equals(204, response.status)
        end)

        it("should lookup the wsse_key by key name and remove it", function()
            local response_create = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'irrelevant'
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response_create.status)
            local wsse_key = response_create.body

            local response = send_admin_request({
                method = "DELETE",
                path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key.key
            })

            assert.are.equals(204, response.status)
        end)
    end)

    context("GET entity", function()
        it("should respond with error when the consumer does not exist", function ()
            local response = send_admin_request({
                method = "GET",
                path = "/consumers/" .. uuid() .. "/wsse_key/" .. uuid()
            })

            assert.are.equals(404, response.status)
            assert.are.equals("Not found", response.body.message)
        end)

        it("should respond with error when the wsse_key does not exist", function ()
            local response = send_admin_request({
                method = "GET",
                path = "/consumers/" .. consumer.id .. "/wsse_key/" .. uuid()
            })

            assert.are.equals(404, response.status)
            assert.are.equals("Not found", response.body.message)
        end)

        it("should return with the wsse_key but should not return the secret", function ()
            local response_create = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'irrelevant',
                    secret = 'irrelevant'
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response_create.status)
            local wsse_key_created = response_create.body

            local response = send_admin_request({
                method = "GET",
                path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key_created.id
            })

            assert.are.equals(200, response.status)
            local wsse_key = response.body

            assert.are.equals(wsse_key_created.key, wsse_key.key)
            assert.is_nil(wsse_key.secret)
        end)

        it("should lookup the wsse_key by key name and return it", function()
            local response_create = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'irrelevant'
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            assert.are.equals(201, response_create.status)
            local wsse_key_created = response_create.body

            local response = send_admin_request({
                method = "GET",
                path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key_created.key
            })

            assert.are.equals(200, response.status)
        end)
    end)
end)
