local utils = require "kong.tools.utils"

local function check_user(anonymous)
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

return {
  no_consumer = true,
  fields = {
    anonymous = {type = "string", default = nil, func = check_user},
    timeframe_validation_treshhold_in_minutes = { type = "number", default = 5 },
    strict_key_matching = { type = "boolean", default = true },
    message_template = { type = "string", default = '{"messsage": "%s"}' },
    status_code = { type = "number", default = 401, func = validate_http_status_code }
  }
}
