local cjson = require "cjson"
local Logger = require "logger"
local constants = require "kong.constants"
local responses = require "kong.tools.responses"
local ConsumerDb = require "kong.plugins.wsse.consumer_db"
local KeyDb = require "kong.plugins.wsse.key_db"
local Wsse = require "kong.plugins.wsse.wsse_lib"

local Access = {}

local function get_wsse_header_string(request_headers)
    local wsse_header_content = request_headers["X-WSSE"]

    if type(wsse_header_content) == "table" then
        return wsse_header_content[1]
    else
        return wsse_header_content
    end
end

local function anonymous_passthrough_is_enabled(plugin_config)
    return plugin_config.anonymous ~= nil
end

local function authenticate(auth_header, conf)
    local authenticator = Wsse:new(KeyDb(conf.strict_key_matching), conf.timeframe_validation_treshhold_in_minutes)

    return authenticator:authenticate(auth_header)
end

local function try_authenticate(auth_header, conf)
    local success, result = pcall(authenticate, auth_header, conf)

    if success then
        return result
    end

    return nil, result
end

local function find_anonymous_consumer(id)
    return ConsumerDb().find_by_id(id, true)
end

local function find_wsse_consumer(wsse_key)
    return ConsumerDb().find_by_id(wsse_key.consumer_id)
end

local function set_consumer(consumer)
    ngx.req.set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)

    ngx.ctx.authenticated_consumer = consumer
end

local function set_authenticated_access(wsse_key)
    ngx.req.set_header(constants.HEADERS.CREDENTIAL_USERNAME, wsse_key.key)
    ngx.req.set_header(constants.HEADERS.ANONYMOUS, nil)

    ngx.ctx.authenticated_credential = wsse_key
end

local function set_anonymous_access()
    ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
end

local function get_transformed_response(template, response_message)
    return cjson.decode(string.format(template, response_message))
end

function Access.execute(conf)
    local wsse_header_value = get_wsse_header_string(ngx.req.get_headers())

    local wsse_key, err = try_authenticate(wsse_header_value, conf)

    if wsse_key then
        Logger.getInstance(ngx):logInfo({ msg = "WSSE authentication was successful.", ["x-wsse"] = wsse_header_value })

        local consumer = find_wsse_consumer(wsse_key)

        set_consumer(consumer)

        set_authenticated_access(wsse_key)

        return
    end

    if anonymous_passthrough_is_enabled(conf) then
        Logger.getInstance(ngx):logWarning({
            ["msg"] = "WSSE authentication failed, allowing anonymous passthrough.",
            ["x-wsse"] = wsse_header_value,
            ["error"] = err
        })

        local consumer = find_anonymous_consumer(conf.anonymous)

        set_consumer(consumer)

        set_anonymous_access()

        return
    end

    local status_code = conf.status_code

    Logger.getInstance(ngx):logWarning({ status = status_code, msg = err.msg, ["x-wsse"] = wsse_header_value })

    return responses.send(status_code, get_transformed_response(conf.message_template, err.msg))
end

return Access
