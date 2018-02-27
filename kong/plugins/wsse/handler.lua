local BasePlugin = require "kong.plugins.base_plugin"
local constants = require "kong.constants"
local responses = require "kong.tools.responses"

local WsseHandler = BasePlugin:extend()

WsseHandler.PRIORITY = 2000

function WsseHandler:new()
    WsseHandler.super.new(self, "wsse")
end

function WsseHandler:access(conf)
    WsseHandler.super.access(self)

    if (ngx.req.get_headers()["X-WSSE"]) then
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, nil)
        -- wsse_lib
    elseif (conf.anonymous == nil) then
        return responses.send(401, "WSSE header not found!")
    else
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
    end
end

return WsseHandler
