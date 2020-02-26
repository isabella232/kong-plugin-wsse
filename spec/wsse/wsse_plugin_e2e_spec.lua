local cjson = require "cjson"
local helpers = require "spec.helpers"
local TestHelper = require "spec.test_helper"
local Wsse = require "kong.plugins.wsse.wsse_lib"
local uuid = require "kong.tools.utils".uuid


local function get_response_body(response)
    local body = assert.res_status(201, response)
    return cjson.decode(body)
end

local function setup_test_env(db)
    db:truncate()

    local service = get_response_body(TestHelper.setup_service('testservice', 'http://mockbin:8080/request'))
    local route = get_response_body(TestHelper.setup_route_for_service(service.id, '/'))
    local plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, 'wsse', {}))
    local consumer = get_response_body(TestHelper.setup_consumer('TestUser'))

    return service, route, plugin, consumer
end

describe("Wsse Plugin", function()

    local db

    setup(function()
        local _
        helpers.start_kong({ plugins = 'wsse' })
        _, db = helpers.get_db_utils()
    end)

    teardown(function()
        helpers.stop_kong()
    end)

    describe("Config", function()
        local service

        before_each(function()
            db:truncate()

            service = get_response_body(TestHelper.setup_service("test-service", "http://mockbin:8080/request"))
        end)

        context("when config parameters are passed to the plugin", function()
            it("should set parameters value as given", function()
                local plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, "wsse", {
                    message_template = '{"almafa": "%s"}'
                }))
                local config = plugin.config

                assert.is_equal(config.message_template, '{"almafa": "%s"}')
            end)

            context("when message_template field is set", function()
                local test_cases = {'{"almafa": %s}', '""', '[{"almafa": "%s"}]'}
                for _, test_template in ipairs(test_cases) do
                    it("should throw error when message_template is not valid JSON object", function()
                        local plugin_response = TestHelper.setup_plugin_for_service(service.id, "wsse", {
                            message_template = test_template
                        })

                        local body = assert.res_status(400, plugin_response)
                        local plugin = cjson.decode(body)

                        assert.is_equal("message_template should be valid JSON object", plugin.fields.config.message_template)
                    end)
                end
            end)

            context("when status_code field is set", function()
                it("should throw error when it is lower than 100", function()
                    local plugin_response = TestHelper.setup_plugin_for_service(service.id, "wsse", {
                        status_code = 66
                    })

                    local body = assert.res_status(400, plugin_response)
                    local plugin = cjson.decode(body)

                    assert.is_equal("status code is invalid", plugin.fields.config.status_code)
                end)
                it("should throw error when it is higher than 600", function()
                    local plugin_response = TestHelper.setup_plugin_for_service(service.id, "wsse", {
                        status_code = 666
                    })

                    local body = assert.res_status(400, plugin_response)
                    local plugin = cjson.decode(body)

                    assert.is_equal("status code is invalid", plugin.fields.config.status_code)
                end)
                it("should succeed when it is within the range", function()
                    local plugin_response = TestHelper.setup_plugin_for_service(service.id, "wsse", {
                        status_code = 400
                    })

                    assert.res_status(201, plugin_response)
                end)
            end)

            context("when anonymous field is set", function()
                it("should throw error when anonymous is not a valid uuid", function()
                    local plugin_response = TestHelper.setup_plugin_for_service(service.id, "wsse", {
                        anonymous = "not-a-valid-uuid"
                    })

                    local body = assert.res_status(400, plugin_response)
                    local plugin = cjson.decode(body)

                    assert.is_equal("the anonymous user must be nil or a valid uuid", plugin.fields.config.anonymous)
                end)
            end)
        end)

        context("when config parameter is not given", function()
            it("should set default config values", function()
                local plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, "wsse", {}))
                local config = plugin.config

                assert.is_equal(config.timeframe_validation_threshold_in_minutes, 5)
                assert.is_equal(config.strict_key_matching, true)
                assert.is_equal(config.message_template, '{"message": "%s"}')
                assert.is_equal(config.status_code, 401)
            end)
        end)

    end)

    describe("Admin API", function()

        local service, route, plugin, consumer

        before_each(function()
            service, route, plugin, consumer = setup_test_env(db)
        end)

        context("POST collection", function()
            it("should respond with error when key field is missing", function ()
                local res = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/"
                })

                local body = assert.res_status(400, res)
                local message = cjson.decode(body)
                assert.is_equal("required field missing", message.fields.key)
            end)

            it("should respond with error when the consumer does not exist", function ()
                local res = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/1234/wsse_key/",
                    body = {
                        key = "irrelevant"
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body = assert.res_status(404, res)
                local message = cjson.decode(body)
                assert.is_equal("Not found", message.message)
            end)

            it("should store wsse credentials for the consumer", function ()
                local res = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'irrelevant',
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                assert.res_status(201, res)
            end)

            it("should store the lowercased key in the key_lower field", function ()
                local res = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'IRRELEVANT',
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body = assert.res_status(201, res)
                local wsse_key = cjson.decode(body)

                assert.is_equal("irrelevant", wsse_key.key_lower)
            end)
        end)

        context("PUT collection", function()
            it("should respond with error when key field is missing", function ()
                local res = assert(helpers.admin_client():send {
                    method = "PUT",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/"
                })

                local body = assert.res_status(400, res)
                local message = cjson.decode(body)
                assert.is_equal("required field missing", message.fields.key)
            end)

            it("should respond with error when the consumer does not exist", function ()
                local res = assert(helpers.admin_client():send {
                    method = "PUT",
                    path = "/consumers/1234/wsse_key/",
                    body = {
                        key = "irrelevant"
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body = assert.res_status(404, res)
                local message = cjson.decode(body)
                assert.is_equal("Not found", message.message)
            end)

            it("should store wsse credentials for the consumer", function ()
                local res = assert(helpers.admin_client():send {
                    method = "PUT",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'irrelevant',
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                assert.res_status(201, res)
            end)

            it("should store the lowercased key in the key_lower field", function ()
                local res = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'IRRELEVANT',
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body = assert.res_status(201, res)
                local wsse_key = cjson.decode(body)

                assert.is_equal("irrelevant", wsse_key.key_lower)
            end)
        end)

        context("DELETE entity", function()
            it("should respond with error when the consumer does not exist", function ()
                local res = assert(helpers.admin_client():send {
                    method = "DELETE",
                    path = "/consumers/" .. uuid() .. "/wsse_key/" .. uuid()
                })

                local body = assert.res_status(404, res)
                local message = cjson.decode(body)
                assert.is_equal("Not found", message.message)
            end)

            it("should respond with error when the wsse_key does not exist", function ()
                local res = assert(helpers.admin_client():send {
                    method = "DELETE",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/" .. uuid()
                })

                local body = assert.res_status(404, res)
                local message = cjson.decode(body)
                assert.is_equal("Not found", message.message)
            end)

            it("should remove the wsse_key", function()
                local res_create = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key",
                    body = {
                        key = 'irrelevant'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body_create = assert.res_status(201, res_create)
                local wsse_key = cjson.decode(body_create)

                local res = assert(helpers.admin_client():send {
                    method = "DELETE",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key.id
                })

                assert.res_status(204, res)
            end)

            it("should lookup the wsse_key by key name and remove it", function()
                local res_create = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key",
                    body = {
                        key = 'irrelevant'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body_create = assert.res_status(201, res_create)
                local wsse_key = cjson.decode(body_create)

                local res = assert(helpers.admin_client():send {
                    method = "DELETE",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key.key
                })

                assert.res_status(204, res)
            end)
        end)

        context("GET entity", function()
            it("should respond with error when the consumer does not exist", function ()
                local res = assert(helpers.admin_client():send {
                    method = "GET",
                    path = "/consumers/" .. uuid() .. "/wsse_key/" .. uuid()
                })

                local body = assert.res_status(404, res)
                local message = cjson.decode(body)
                assert.is_equal("Not found", message.message)
            end)

            it("should respond with error when the wsse_key does not exist", function ()
                local res = assert(helpers.admin_client():send {
                    method = "GET",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/" .. uuid()
                })

                local body = assert.res_status(404, res)
                local message = cjson.decode(body)
                assert.is_equal("Not found", message.message)
            end)

            it("should return with the wsse_key but should not return the secret", function ()
                local res_create = assert(helpers.admin_client():send {
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

                local body_create = assert.res_status(201, res_create)
                local wsse_key_created = cjson.decode(body_create)

                local res = assert(helpers.admin_client():send {
                    method = "GET",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key_created.id,
                })

                local body = assert.res_status(200, res)
                local wsse_key = cjson.decode(body)

                assert.is_equal(wsse_key_created.key, wsse_key.key)
                assert.is_nil(wsse_key.secret)
            end)

            it("should lookup the wsse_key by key name and return it", function()
                local res_create = assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key",
                    body = {
                        key = 'irrelevant'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local body_create = assert.res_status(201, res_create)
                local wsse_key_created = cjson.decode(body_create)

                local res = assert(helpers.admin_client():send {
                    method = "GET",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/" .. wsse_key_created.key,
                })

                assert.res_status(200, res)
            end)
        end)
    end)


    describe("#access", function()

        context("when no anonymous consumer was configured", function()

            local service, route, plugin, consumer

            before_each(function()
                service, route, plugin, consumer = setup_test_env(db)
            end)

            it("should reject request with HTTP 401 if X-WSSE header is not present", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com"
                    }
                })

                local body = assert.res_status(401, res)
                assert.is_equal('{"message":"WSSE authentication header is missing."}', body)
            end)

            it("should reject request with HTTP 401 if X-WSSE header is malformed", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = "some wsse header string"
                    }
                })

                local body = assert.res_status(401, res)
                assert.is_equal('{"message":"The Username field is missing from WSSE authentication header."}', body)
            end)

            it("should proxy the request to the upstream on successful auth", function()
                local header = Wsse.generate_header("test", "test", uuid())

                assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key",
                    body = {
                        key = 'test',
                        secret = 'test'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = header
                    }
                })

                assert.res_status(200, res)
            end)

            it("should reject the request with HTTP 401 when WSSE key could not be found", function()
                assert(helpers.admin_client():send {
                    method = "PUT",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'test001'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = 'UsernameToken Username="test003", PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"'
                    }
                })

                local body = assert.res_status(401, res)
                assert.is_equal('{"message":"Credentials are invalid."}', body)
            end)

            context("when timeframe validation fails", function()
                it("should proxy the request to the upstream if strict validation was disabled", function ()
                    local header = Wsse.generate_header("test2", "test2", uuid(), "2017-02-27T09:46:22Z")

                    assert(helpers.admin_client():send {
                        method = "POST",
                        path = "/consumers/" .. consumer.id .. "/wsse_key/",
                        body = {
                            key = 'test2',
                            secret = 'test2',
                            strict_timeframe_validation = false
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })

                    local res = assert(helpers.proxy_client():send {
                        method = "GET",
                        path = "/request",
                        headers = {
                            ["Host"] = "test1.com",
                            ["X-WSSE"] = header
                        }
                    })

                    assert.res_status(200, res)
                end)

                it("should reject the request with HTTP 401 when strict validation is on", function ()
                    local header = Wsse.generate_header("test2", "test2", uuid(), "2017-02-27T09:46:22Z")

                    assert(helpers.admin_client():send {
                        method = "POST",
                        path = "/consumers/" .. consumer.id .. "/wsse_key/",
                        body = {
                            key = 'test2',
                            secret = 'test2'
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })

                    local res = assert(helpers.proxy_client():send {
                        method = "GET",
                        path = "/request",
                        headers = {
                            ["Host"] = "test1.com",
                            ["X-WSSE"] = header
                        }
                    })

                    local body = assert.res_status(401, res)
                    assert.is_equal('{"message":"Timeframe is invalid."}', body)
                end)
            end)

        end)

        context("With anonymous user enabled", function()
            local service, route, anonymous, plugin, consumer

            before_each(function()
                db:truncate()

                service = get_response_body(TestHelper.setup_service('testservice', 'http://mockbin.org/request'))
                route = get_response_body(TestHelper.setup_route_for_service(service.id, '/'))

                anonymous = get_response_body(TestHelper.setup_consumer('anonymous'))
                plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, 'wsse', {["anonymous"] = anonymous.id}))

                consumer = get_response_body(TestHelper.setup_consumer('TestUser'))
            end)

            it("should proxy request with anonymous user if X-WSSE header is not present", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com"
                    }
                })

                local response = assert.res_status(200, res)
                local body = cjson.decode(response)
                assert.is_equal("anonymous", body.headers["x-consumer-username"])
            end)

            it("should proxy the request to the upstream when header is present two times", function()
                local header = Wsse.generate_header("test1", "test1", uuid())
                local other_header = Wsse.generate_header("test1", "test1", uuid())

                assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'test1',
                        secret = 'test1'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = {header, other_header},
                    }
                })

                local response = assert.res_status(200, res)
                local body = cjson.decode(response)
                assert.is_equal("TestUser", body.headers["x-consumer-username"])
            end)

            it("should proxy the request with anonymous user if X-WSSE header is malformed", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = "some wsse header string"
                    }
                })

                local response = assert.res_status(200, res)
                local body = cjson.decode(response)
                assert.is_equal("anonymous", body.headers["x-consumer-username"])
            end)

            it("should proxy the request to the upstream on successful auth", function()
                local header = Wsse.generate_header("test", "test", uuid())

                assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'test',
                        secret = 'test'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = header
                    }
                })

                local response = assert.res_status(200, res)
                local body = cjson.decode(response)
                assert.is_equal("TestUser", body.headers["x-consumer-username"])
            end)

            it("should proxy the request with anonymous user when WSSE key could not be found", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = 'UsernameToken Username="non-existing", PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"'
                    }
                })

                local response = assert.res_status(200, res)
                local body = cjson.decode(response)
                assert.is_equal("anonymous", body.headers["x-consumer-username"])
            end)

            context("when timeframe is invalid", function()
                it("should proxy the request to the upstream if strict validation was disabled", function ()
                    local header = Wsse.generate_header("test2", "test2", uuid(), "2017-02-27T09:46:22Z")

                    assert(helpers.admin_client():send {
                        method = "POST",
                        path = "/consumers/" .. consumer.id .. "/wsse_key/",
                        body = {
                            key = 'test2',
                            secret = 'test2',
                            strict_timeframe_validation = false
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })

                    local res = assert(helpers.proxy_client():send {
                        method = "GET",
                        path = "/request",
                        headers = {
                            ["Host"] = "test1.com",
                            ["X-WSSE"] = header
                        }
                    })

                    local response = assert.res_status(200, res)
                    local body = cjson.decode(response)
                    assert.is_equal("TestUser", body.headers["x-consumer-username"])
                end)

                it("should proxy the request with anonymous when strict validation is on", function ()
                    local header = Wsse.generate_header("test2", "test2", uuid(), "2017-02-27T09:46:22Z")

                    assert(helpers.admin_client():send {
                        method = "POST",
                        path = "/consumers/" .. consumer.id .. "/wsse_key/",
                        body = {
                            key = 'test2',
                            secret = 'test2'
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })

                    local res = assert(helpers.proxy_client():send {
                        method = "GET",
                        path = "/request",
                        headers = {
                            ["Host"] = "test1.com",
                            ["X-WSSE"] = header
                        }
                    })

                    local response = assert.res_status(200, res)
                    local body = cjson.decode(response)
                    assert.is_equal("anonymous", body.headers["x-consumer-username"])
                end)
            end)
        end)

        context('when strict key matching is disabled', function()

            local service, route, anonymous, plugin, consumer

            before_each(function()
                db:truncate()

                service = get_response_body(TestHelper.setup_service('testservice', 'http://mockbin.org/request'))
                route = get_response_body(TestHelper.setup_route_for_service(service.id, '/'))

                anonymous = get_response_body(TestHelper.setup_consumer('anonymous'))
                plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, 'wsse', {["strict_key_matching"] = false}))

                consumer = get_response_body(TestHelper.setup_consumer('TestUser'))
            end)

            it('should respond with 200 when wsse key casing is different', function()
                local header = Wsse.generate_header("testci", "test", uuid())

                assert(helpers.admin_client():send {
                    method = "POST",
                    path = "/consumers/" .. consumer.id .. "/wsse_key/",
                    body = {
                        key = 'TeStCi',
                        secret = 'test'
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request",
                    headers = {
                        ["Host"] = "test1.com",
                        ["X-WSSE"] = header
                    }
                })

                assert.res_status(200, res)
            end)

        end)

        context('when given status code for failed authentications', function()
            local service, route, plugin

            before_each(function()
                db:truncate()

                service = get_response_body(TestHelper.setup_service('testservice', 'http://mockbin.org/request'))
                route = get_response_body(TestHelper.setup_route_for_service(service.id, '/'))
                plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, 'wsse', {
                    status_code = 400
                }))
            end)

            it("should reject request with given HTTP status", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request"
                })

                assert.res_status(400, res)
            end)
        end)

        context("when message template is not default", function()
            local service, route, plugin

            before_each(function()
                db:truncate()

                service = get_response_body(TestHelper.setup_service('testservice', 'http://mockbin.org/request'))
                route = get_response_body(TestHelper.setup_route_for_service(service.id, '/'))
                plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, 'wsse', {
                    message_template = '{"custom-message": "%s"}'
                }))
            end)

            it("should return response message in the given format", function()
                local res = assert(helpers.proxy_client():send {
                    method = "GET",
                    path = "/request"
                })

                local response = assert.res_status(401, res)
                local body = cjson.decode(response)

                assert.is_nil(body.message)
                assert.not_nil(body['custom-message'])
                assert.is_equal("WSSE authentication header is missing.", body['custom-message'])
            end)

        end)
    end)

end)
