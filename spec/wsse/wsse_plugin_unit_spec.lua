local constants = require "kong.constants"
local plugin_handler = require "kong.plugins.wsse.handler"
local ConsumerDb = require "kong.plugins.wsse.consumer_db"
local Wsse = require "kong.plugins.wsse.wsse_lib"

describe("wsse plugin", function()
    local old_ngx = _G.ngx
    local old_kong = _G.kong
    local mock_config= {
        anonymous = 'anonym123',
        timeframe_validation_threshold_in_minutes = 5
    }
    local handler

    local anonymous_consumer = {
        id = 'anonym123',
        custom_id = '',
        username = 'anonymous'
    }

    local test_consumer = {
        id = 'test123',
        custom_id = '',
        username = 'test'
    }

    ConsumerDb.find_by_id = function(consumer_id)
        return test_consumer
    end

    ConsumerDb.find_anonymous = function(anonymous)
        return anonymous_consumer
    end

    local test_wsse_key = {
        id = 1,
        consumer_id = 'test123',
        key = "test",
        secret = "test",
        strict_timeframe_validation = true
    }

    before_each(function()
        Wsse.authenticate = function()
            return test_wsse_key
        end

        local stubbed_ngx = {
            ctx = {},
            log = function() end,
            var = {}
        }

        local kong_service_request_headers = {}

        local stubbed_kong = {
            service = {
                request = {
                    set_header = function(header_name, header_value)
                        kong_service_request_headers[header_name] = header_value
                    end,
                    clear_header =  function() end
                }
            },
            request = {
                get_path = function()
                    return "request_uri"
                end,
                get_method = function()
                    return "GET"
                end,
                get_headers = function()
                    return kong_service_request_headers
                end,
                get_body = function() end
            }
        }

        _G.ngx = stubbed_ngx
        _G.kong = stubbed_kong

        handler = plugin_handler()
    end)

    after_each(function()
        _G.ngx = old_ngx
        _G.kong = old_kong
    end)

    describe("#access", function()

        it("should indicate anonymous consumer when WSSE auth fails and anonymous passthrough is enabled", function()
            Wsse.authenticate = function()
                error("Some error...")
            end

            handler:access(mock_config)

            assert.are.equal(true, kong.request.get_headers()[constants.HEADERS.ANONYMOUS])
        end)

        it("set anonymous header to nil when wsse header exists", function()
            kong.service.request.set_header("X-WSSE", "some wsse header string")

            handler:access(mock_config)

            assert.are.equal(nil, kong.request.get_headers()[constants.HEADERS.ANONYMOUS])
        end)

        it("set consumer specific request headers when authentication was successful", function()
            kong.service.request.set_header("X-WSSE", "wsse header string")

            handler:access(mock_config)

            assert.are.equal('test123', kong.request.get_headers()[constants.HEADERS.CONSUMER_ID])
            assert.are.equal('', kong.request.get_headers()[constants.HEADERS.CONSUMER_CUSTOM_ID])
            assert.are.equal('test', kong.request.get_headers()[constants.HEADERS.CONSUMER_USERNAME])
        end)

        it("set consumer specific ngx context variables when authentication was successful", function()
            kong.service.request.set_header("X-WSSE", "wsse header string")

            handler:access(mock_config)

            assert.are.equal(test_consumer, ngx.ctx.authenticated_consumer)
            assert.are.equal(test_wsse_key, ngx.ctx.authenticated_credential)
        end)

        it("should clear authenticated credentials and set anonymous as consumer when auth failed", function()
            Wsse.authenticate = function()
                error("Some error...")
            end

            handler:access(mock_config)

            assert.are.equal(anonymous_consumer, ngx.ctx.authenticated_consumer)
            assert.are.equal(nil, ngx.ctx.authenticated_credential)
        end)

    end)

end)
