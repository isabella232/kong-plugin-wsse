local utils = require "kong.tools.utils"
local cjson = require "cjson"

local function ensure_valid_uuid_or_nil(anonymous)
    if anonymous == nil or utils.is_valid_uuid(anonymous) then
        return true
    end

    return false, "the anonymous user must be nil or a valid uuid"
end

local function validate_http_status_code(status_code)
    if status_code >= 100 and status_code < 600 then
        return true
    end

    return false, "status code is invalid"
end

local function decode_json(message_template)
    return cjson.decode(message_template)
end

local function is_object(message_template)
    local first_char = message_template:sub(1, 1)
    local last_char = message_template:sub(-1)
    return first_char == "{" and last_char == "}"
end

local function ensure_message_template_is_valid_json(message_template)
    local ok = pcall(decode_json, message_template)

    if not ok or not is_object(message_template) then
        return false, "message_template should be valid JSON object"
    end

    return true
end

return {
    no_consumer = true,
    fields = {
        anonymous = { type = "string", default = nil, func = ensure_valid_uuid_or_nil },
        timeframe_validation_threshold_in_minutes = { type = "number", default = 5 },
        strict_key_matching = { type = "boolean", default = true },
        message_template = { type = "string", default = '{"message": "%s"}', func = ensure_message_template_is_valid_json },
        status_code = { type = "number", default = 401, func = validate_http_status_code }
    }
}
