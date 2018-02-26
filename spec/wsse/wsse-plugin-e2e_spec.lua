local helpers = require "spec.helpers"
local cjson = require "cjson"

describe("Plugin: wsse (access)", function()
  local client
  local admin_client
  local dev_env = {
    custom_plugins = 'wsse'
  }

  local plugin
  local api_id

  setup(function()
    local api1 = assert(helpers.dao.apis:insert { name = "test-api", hosts = { "test1.com" }, upstream_url = "http://mockbin.com" })
    api_id = api1.id

    plugin = assert(helpers.dao.plugins:insert {
      api_id = api1.id,
      name = "wsse",
      config = {}
    })
    assert(helpers.start_kong(dev_env))
  end)

  teardown(function()
    helpers.stop_kong(nil)
  end)

  before_each(function()
    client = helpers.proxy_client()
    admin_client = helpers.admin_client()
  end)

  after_each(function()
    if client then client:close() end
    if admin_client then admin_client:close() end
  end)

  describe("Admin API", function()
    it("registered the plugin globally", function()
      local res = assert(admin_client:send {
        method = "GET",
        path = "/plugins/" .. plugin.id,
      })
      local body = assert.res_status(200, res)
      local json = cjson.decode(body)

      assert.is_table(json)
      assert.is_not.falsy(json.enabled)
    end)

    it("registered the plugin for the api", function()
      local res = assert(admin_client:send {
        method = "GET",
        path = "/plugins/" ..plugin.id,
      })
      local body = assert.res_status(200, res)
      local json = cjson.decode(body)
      assert.is_equal(api_id, json.api_id)
    end)
  end)

  describe("Authenticate", function()
    it("response with satus 401 if request not has wsse header and anonymous not allowed", function()
      local res = assert(client:send {
        method = "GET",
        path = "/request",
        headers = {
          ["Host"] = "test1.com"
        }
      })

      assert.res_status(401, res)
    end)

    it("response with satus 200 if request has wsse header", function()
      local res = assert(client:send {
        method = "GET",
        path = "/request",
        headers = {
          ["Host"] = "test1.com",
          ["X-WSSE"] = "some wsse header string"
        }
      })

      assert.res_status(200, res)
    end)
  end)

end)
