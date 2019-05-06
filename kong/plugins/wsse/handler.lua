local Logger = require "logger"
local responses = require "kong.tools.responses"
local BasePlugin = require "kong.plugins.base_plugin"
local InitWorker = require "kong.plugins.wsse.init_worker"
local PluginConfig = require "kong.plugins.wsse.plugin_config"
local schema = require "kong.plugins.wsse.schema"
local Access = require "kong.plugins.wsse.access"

local WsseHandler = BasePlugin:extend()

WsseHandler.PRIORITY = 1006

function WsseHandler:new()
    WsseHandler.super.new(self, "wsse")
end

function WsseHandler:init_worker()
    WsseHandler.super.init_worker(self)

    InitWorker.execute()
end

local function anonymous_passthrough_is_enabled(plugin_config)
    return plugin_config.anonymous ~= nil
end

local function already_authenticated_by_other_plugin(plugin_config, authenticated_credential)
    return anonymous_passthrough_is_enabled(plugin_config) and authenticated_credential ~= nil
end

function WsseHandler:access(original_config)
    WsseHandler.super.access(self)

    local conf = PluginConfig(schema):merge_onto_defaults(original_config)

    if already_authenticated_by_other_plugin(conf, ngx.ctx.authenticated_credential) then
        return
    end

    local success, result = pcall(Access.execute, conf)

    if not success then
        Logger.getInstance(ngx):logError(result)

        return responses.send(500, "An unexpected error occurred.")
    end

    return result
end

return WsseHandler
