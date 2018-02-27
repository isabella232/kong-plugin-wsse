local Wsse = {}

local function check_required_params(wsse_params)
    if wsse_params["username"] == nil
    or wsse_params["password_digest"] == nil
    or wsse_params["nonce"] == nil
    or wsse_params["created"] == nil
    then
        error("error")
    end
end

local function parse_field(header_string, field_name)
    field_name_case_insensitive = field_name:gsub("(.)", function(letter)
        return string.format("[%s%s]", letter:lower(), letter:upper())
    end)

    return string.match(header_string, '[, ]' .. field_name_case_insensitive .. '%s*=%s*"(.-)"')
end

function Wsse:new()
    self.__index = self
    local self = setmetatable({}, self)
    return self
end

function Wsse:check_header(header_string)
    if (header_string == "") then
        error("error")
    end

    local wsse_params = {
        username = parse_field(header_string, 'Username'),
        password_digest = parse_field(header_string, 'PasswordDigest'),
        nonce = parse_field(header_string, 'Nonce'),
        created = parse_field(header_string, 'Created')
    }

    check_required_params(wsse_params)
end

return Wsse