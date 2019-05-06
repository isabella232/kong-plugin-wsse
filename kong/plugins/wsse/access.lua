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

local function authenticate(auth_header, plugin_config)
    local key_db = KeyDb(plugin_config.strict_key_matching)
    local timeframe = plugin_config.timeframe_validation_threshold_in_minutes

    return Wsse(key_db, timeframe):authenticate(auth_header)
end

local function try_authenticate(auth_header, plugin_config)
    local success, result = pcall(authenticate, auth_header, plugin_config)

    if success then
        return result
    end

    return nil, result
end

local function find_anonymous_consumer(plugin_config)
    return ConsumerDb.find_anonymous(plugin_config.anonymous)
end

local function find_consumer_for(credentials)
    return ConsumerDb.find_by_id(credentials.consumer_id)
end

local function set_consumer(consumer)
    ngx.req.set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)

    ngx.ctx.authenticated_consumer = consumer
end

local function set_authenticated_access(credentials)
    ngx.req.set_header(constants.HEADERS.CREDENTIAL_USERNAME, credentials.key)
    ngx.req.set_header(constants.HEADERS.ANONYMOUS, nil)

    ngx.ctx.authenticated_credential = credentials
end

local function set_anonymous_access()
    ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
end

local function get_transformed_response(template, response_message)
    return cjson.decode(string.format(template, response_message))
end

function Access.execute(conf)
    local wsse_header_value = get_wsse_header_string(ngx.req.get_headers())

    local credentials, err = try_authenticate(wsse_header_value, conf)

    if credentials then
        Logger.getInstance(ngx):logInfo({ msg = "WSSE authentication was successful.", ["x-wsse"] = wsse_header_value })

        local consumer = find_consumer_for(credentials)

        set_consumer(consumer)

        set_authenticated_access(credentials)

        return
    end

    if anonymous_passthrough_is_enabled(conf) then
        Logger.getInstance(ngx):logWarning({
            msg = "WSSE authentication failed, allowing anonymous passthrough.",
            error = type(err) == "table" and err or { msg = err },
            ["x-wsse"] = wsse_header_value
        })

        local consumer = find_anonymous_consumer(conf)

        set_consumer(consumer)

        set_anonymous_access()

        return
    end

    local status_code = conf.status_code

    Logger.getInstance(ngx):logWarning({
        msg = "WSSE authentication failed.",
        error = type(err) == "table" and err or { msg = err },
        status = status_code,
        ["x-wsse"] = wsse_header_value
    })

    return responses.send(status_code, get_transformed_response(conf.message_template, err.msg))
end

return Access
