local base64 = require "base64"
local sha1 = require "sha1"
local uuid = require("uuid")

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

local function parse_header(header_string)
    if (header_string == "") then
        error("error")
    end

    local wsse_params = {
        username = parse_field(header_string, 'Username'),
        password_digest = parse_field(header_string, 'PasswordDigest'),
        nonce = parse_field(header_string, 'Nonce'),
        created = parse_field(header_string, 'Created')
    }

    return wsse_params
end

function Wsse:new(key_db)
    self.__index = self
    local self = setmetatable({}, self)
    self.key_db = key_db
    return self
end

function Wsse:authenticate(header_string)
    local wsse_params = parse_header(header_string)

    check_required_params(wsse_params)
    self.key_db:find_by_username(wsse_params['username'])
end

function Wsse:generate_header(username, secret, created, nonce)
    if username == nil or secret == nil then
        error("Username and secret are required!")
    end

    created = created or os.date("!%Y-%m-%dT%TZ")
    nonce = nonce or uuid()
    local digest = base64.encode(sha1(nonce .. created .. secret))

    return string.format('UsernameToken Username="%s", PasswordDigest="%s", Nonce="%s", Created="%s"', username, digest, nonce, created)
end

return Wsse