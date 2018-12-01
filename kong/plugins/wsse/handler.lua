local BasePlugin = require "kong.plugins.base_plugin"
local constants = require "kong.constants"
local ConsumerDb = require "kong.plugins.wsse.consumer_db"
local cjson = require "cjson"
local InitWorker = require "kong.plugins.wsse.init_worker"
local KeyDb = require "kong.plugins.wsse.key_db"
local Logger = require "logger"
local responses = require "kong.tools.responses"
local PluginConfig = require "kong.plugins.wsse.plugin_config"
local schema = require "kong.plugins.wsse.schema"
local Wsse = require "kong.plugins.wsse.wsse_lib"

local WsseHandler = BasePlugin:extend()

WsseHandler.PRIORITY = 1006

local function set_consumer(consumer, wsse_key)
    ngx.req.set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)

    ngx.ctx.authenticated_consumer = consumer

    if wsse_key then
        ngx.req.set_header(constants.HEADERS.CREDENTIAL_USERNAME, wsse_key.key)
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, nil)

        ngx.ctx.authenticated_credential = wsse_key
    else
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
    end
end

local function authenticate(auth_header, conf)
    local authenticator = Wsse:new(KeyDb(conf.strict_key_matching), conf.timeframe_validation_treshhold_in_minutes)

    return authenticator:authenticate(auth_header)
end

local function anonymous_passthrough_is_enabled(plugin_config)
    return plugin_config.anonymous ~= nil
end

local function already_authenticated_by_other_plugin(plugin_config, authenticated_credential)
    return anonymous_passthrough_is_enabled(plugin_config) and authenticated_credential ~= nil
end

function WsseHandler:new()
    WsseHandler.super.new(self, "wsse")
end

function WsseHandler:init_worker()
    WsseHandler.super.init_worker(self)

    InitWorker.execute()
end

local function get_wsse_header_string(request_headers)
    local wsse_header_content = request_headers["X-WSSE"]

    if type(wsse_header_content) == "table" then
        return wsse_header_content[1]
    else
        return wsse_header_content
    end
end

local function get_transformed_response(template, response_message)
    return cjson.decode(string.format(template, response_message))
end

function WsseHandler:access(original_config)
    WsseHandler.super.access(self)

    local conf = PluginConfig(schema):merge_onto_defaults(original_config)

    if already_authenticated_by_other_plugin(conf, ngx.ctx.authenticated_credential) then
        return
    end

    local wsse_header_string = get_wsse_header_string(ngx.req.get_headers())

    local successful_auth, error_or_wsse_key = pcall(
        authenticate,
        wsse_header_string,
        conf
    )

    local success, result = pcall(function()
        if successful_auth then
            Logger.getInstance(ngx):logInfo({ msg = "WSSE authentication was successful.", ["x-wsse"] = wsse_header_string })

            local consumer_db = ConsumerDb()
            local consumer = consumer_db.find_by_id(error_or_wsse_key.consumer_id)

            set_consumer(consumer, error_or_wsse_key)
        elseif anonymous_passthrough_is_enabled(conf) then
            Logger.getInstance(ngx):logWarning({
                ["msg"] = "WSSE authentication failed, allowing anonymous passthrough.",
                ["x-wsse"] = wsse_header_string,
                ["error"] = error_or_wsse_key
            })

            local consumer_db = ConsumerDb()
            local consumer = consumer_db.find_by_id(conf.anonymous, true)

            set_consumer(consumer)
        else
            local status_code = conf.status_code

            Logger.getInstance(ngx):logWarning({ status = status_code, msg = error_or_wsse_key.msg, ["x-wsse"] = wsse_header_string })

            return responses.send(status_code, get_transformed_response(conf.message_template, error_or_wsse_key.msg))
        end
    end)

    if not success then
        Logger.getInstance(ngx).logError(result)
        return responses.send(500, "An unexpected error occurred.")
    end

    return result
end

return WsseHandler
