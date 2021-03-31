local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"
local uuid = require "kong.tools.utils".uuid
local EasyCrypto = require "resty.easy-crypto"

describe("WSSE #plugin #api #e2e", function()

    local kong_sdk, send_admin_request
    local consumer
    local blueprints, db

    local function get_easy_crypto()
        local ecrypto = EasyCrypto:new({
            saltSize = 12,
            ivSize = 16,
            iterationCount = 10000
        })
        return ecrypto
    end

    local function load_encryption_key_from_file(file_path)
        local file = assert(io.open(file_path, "r"))
        local encryption_key = file:read("*all")
        file:close()
        return encryption_key
    end

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

        blueprints, db = kong_helpers.get_db_utils()

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

        it("should store the wsse key with encrypted secret using encryption key from file", function ()
            local service = kong_sdk.services:create({
                name = "testservice",
                url = "http://mockbin:8080/request"
            })

            local plugin = kong_sdk.plugins:create({
                service = { id = service.id },
                name = "wsse",
                config = { encryption_key_path = "/secret.txt" }
            })
            local ecrypto = get_easy_crypto()
            local response = send_admin_request({
                method = "POST",
                path = "/consumers/" .. consumer.id .. "/wsse_key",
                body = {
                    key = 'IRRELEVANT',
                    secret = 'secret'
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })

            local encryption_key = load_encryption_key_from_file(plugin.config.encryption_key_path)

            local row = assert(db.wsse_keys:select({ id = response.body.id }))

            assert.are.equals("secret", ecrypto:decrypt(encryption_key, row.secret))
        end)

        context("when no plugin is added", function()
            it("should return 412 status", function()
                local response = send_admin_request({
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key",
                    body = {
                        key = "irrelevant",
                        secret = "irrelevant"
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                assert.are.equals(412, response.status)
                assert.are.equals("Encryption key was not defined", response.body.message)
            end)
        end)

        it("should respond with error when encryption_key_path config param is empty", function()
            local _, response = pcall(function()
                kong_sdk.plugins:create({
                    name = "wsse",
                    config = { encryption_key_path = "" }
                })
            end)
            assert.are.equals(400, response.status)
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
            local plugin = kong_sdk.plugins:create({
                name = "wsse",
                config = { encryption_key_path = "/secret.txt" }
            })
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
