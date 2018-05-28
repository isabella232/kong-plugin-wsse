local helpers = require "spec.helpers"
local cjson = require "cjson"
local Wsse = require "kong.plugins.wsse.wsse_lib"
local TestHelper = require "spec.test_helper"

local function get_response_body(response)
  local body = assert.res_status(201, response)
  return cjson.decode(body)
end

local function setup_test_env()
  helpers.dao:truncate_tables()

  local service = get_response_body(TestHelper.setup_service())
  local route = get_response_body(TestHelper.setup_route_for_service(service.id))
  local plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, 'wsse'))
  local consumer = get_response_body(TestHelper.setup_consumer('TestUser'))

  return service, route, plugin, consumer
end

describe("Plugin: wsse (access)", function()

  local service
  local route
  local plugin
  local consumer

  before_each(function()
    service, route, plugin, consumer = setup_test_env()
  end)

  setup(function()
    helpers.start_kong({ custom_plugins = 'wsse' })
  end)

  teardown(function()
    helpers.stop_kong(nil)
  end)

  describe("Admin API", function()
    it("registered the plugin globally", function()
      local res = assert(helpers.admin_client():send {
        method = "GET",
        path = "/plugins/" .. plugin.id,
      })
      local body = assert.res_status(200, res)
      local json = cjson.decode(body)

      assert.is_table(json)
      assert.is_not.falsy(json.enabled)
    end)

    it("registered the plugin for the api", function()
      local res = assert(helpers.admin_client():send {
        method = "GET",
        path = "/plugins/" ..plugin.id,
      })
      local body = assert.res_status(200, res)
      local json = cjson.decode(body)
      assert.is_equal(api_id, json.api_id)
    end)

    it("DELETE removes wsse_key", function()

      assert(helpers.admin_client():send {
        method = "POST",
        path = "/consumers/" .. consumer.id .. "/wsse_key",
        body = {
          key = 'test1234',
          secret = 'test1234'
        },
        headers = {
          ["Content-Type"] = "application/json"
        }
      })

      local res = assert(helpers.admin_client():send {
        method = "DELETE",
        path = "/consumers/" .. consumer.id .. "/wsse_key/test1234"
      })

      assert.res_status(204, res)
    end)

    it("returns with proper wsse key without secret when wsse key exists", function ()
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

      local res_get = assert(helpers.admin_client():send {
        method = "GET",
        path = "/consumers/" .. consumer.id .. "/wsse_key/test2",
      })

      local body = assert.res_status(200, res_get)
      local wsse_get = cjson.decode(body)
      assert.is_equal('test2', wsse_get.key)
      assert.is_nil(wsse_get.secret)
    end)

    it("reponds with status code 404 when wsse key does not exist", function ()
      local res_get = assert(helpers.admin_client():send {
        method = "GET",
        path = "/consumers/" .. consumer.id .. "/wsse_key/non_existing_key",
      })

      assert.res_status(404, res_get)
    end)
  end)

  describe("Authentication", function()
    it("responds with status 401 if request not has wsse header and anonymous not allowed", function()
      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/request",
        headers = {
          ["Host"] = "test1.com"
        }
      })

      local body = assert.res_status(401, res)
      assert.is_equal('{"message":"WSSE authentication header not found!"}', body)
    end)

    it("responds with status 401 when wsse header format is invalid", function()
      local res = assert(helpers.proxy_client():send {
        method = "GET",
        path = "/request",
        headers = {
          ["Host"] = "test1.com",
          ["X-WSSE"] = "some wsse header string"
        }
      })

      local body = assert.res_status(401, res)
      assert.is_equal('{"message":"The Username field is missing from WSSE authenticaion header."}', body)
    end)

    it("responds with status 200 when wsse header is valid", function()
      local header = Wsse.generate_header("test", "test")

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

      assert.res_status(200, res)
    end)

    it("responds with status 401 when wsse key not found", function()
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

      assert.res_status(401, res)
    end)

    it("responds with 200 when timeframe is invalid and non strict user", function ()
      local header = Wsse.generate_header("test2", "test2", "2017-02-27T09:46:22Z")

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
  end)

end)
