local BasePlugin = require "kong.plugins.base_plugin"
local constants = require "kong.constants"
local responses = require "kong.tools.responses"
local wsse_lib = require "kong.plugins.wsse.wsse_lib"
local KeyDb = require "kong.plugins.wsse.key_db"
local Logger = require "kong.plugins.wsse.logger"

local WsseHandler = BasePlugin:extend()

WsseHandler.PRIORITY = 1006

function WsseHandler:new()
    WsseHandler.super.new(self, "wsse")
end

function WsseHandler:access(conf)
    WsseHandler.super.access(self)
    local wsse_header_string = ngx.req.get_headers()["X-WSSE"]

    if (wsse_header_string) then
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, nil)
        local wsse = wsse_lib:new(KeyDb(), conf.timeframe_validation_treshhold_in_minutes)
        local success, err = pcall(function()
            wsse:authenticate(wsse_header_string)
        end)

        if not success then
            Logger.getInstance(ngx):logInfo({status = 401, message = err.msg})
            return responses.send(401, err.msg)
        else
            Logger.getInstance(ngx):logInfo({status = 200, message = "WSSE authentication was successful."})
        end
    elseif (conf.anonymous == nil) then
        local error_message = "WSSE authentication header not found!"
        Logger.getInstance(ngx):logInfo({status = 401, message = error_message})
        return responses.send(401, error_message)
    else
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
        Logger.getInstance(ngx):logInfo({msg = "WSSE authentication skipped."})
    end
end

return WsseHandler
