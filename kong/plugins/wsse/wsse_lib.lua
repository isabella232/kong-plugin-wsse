local Object = require "classic"
local base64 = require "base64"
local sha1 = require "sha1"
local uuid = require "uuid"
local Logger = require "logger"
local TimeframeValidator = require "kong.plugins.wsse.timeframe_validator"

local Wsse = Object:extend()

local function throw_error_and_log(message)
    Logger.getInstance(ngx):logWarning({ msg = message })
    error({ msg = message })
end

local param_to_field_name = {
    username = "Username",
    password_digest = "PasswordDigest",
    nonce = "Nonce",
    created = "Created"
}

local function ensure_param_exists(wsse_params, param_name)
    if not wsse_params[param_name] then
        local msg = "The " .. param_to_field_name[param_name] .. " field is missing from WSSE authentication header."
        throw_error_and_log(msg)
    end
end

local required_params = {
    "username",
    "password_digest",
    "nonce",
    "created"
}

local function check_required_params(wsse_params)
    for _, param_name in ipairs(required_params) do
        ensure_param_exists(wsse_params, param_name)
    end
end

local function parse_field(header_string, field_name)
    local field_name_case_insensitive = field_name:gsub("(.)", function(letter)
        return string.format("[%s%s]", letter:lower(), letter:upper())
    end)

    return string.match(header_string, field_name_case_insensitive .. '%f[%A]%s*=%s*"(.-)"')
end

local function ensure_header_is_present(header_string)
    if not header_string then
        throw_error_and_log("WSSE authentication header is missing.")
    end
end

local function ensure_header_is_not_empty(header_string)
    if header_string == "" then
        throw_error_and_log("WSSE authentication header is empty.")
    end
end

local function parse_header(header_string)
    ensure_header_is_present(header_string)
    ensure_header_is_not_empty(header_string)

    local wsse_params = {
        username = parse_field(header_string, "Username"),
        password_digest = parse_field(header_string, "PasswordDigest"),
        nonce = parse_field(header_string, "Nonce"),
        created = parse_field(header_string, "Created")
    }

    return wsse_params
end

local function generate_password_digest(nonce, created, secret)
    return sha1(nonce .. created .. secret)
end

local function validate_credentials(wsse_params, secret)
    local expected_digest = generate_password_digest(
        wsse_params.nonce,
        wsse_params.created,
        secret
    )

    local encoded_digest = wsse_params.password_digest

    if encoded_digest then
        encoded_digest = encoded_digest:gsub("^[^A-Za-z0-9+/=]+", "")
    end

    if expected_digest ~= base64.decode(encoded_digest) then
        throw_error_and_log("Credentials are invalid.")
    end
end

function Wsse:new(key_db, timeframe_validation_treshhold_in_minutes)
    local timeframe_validation_treshhold_in_seconds = timeframe_validation_treshhold_in_minutes * 60 or 300

    self.key_db = key_db
    self.timeframe_validator = TimeframeValidator(timeframe_validation_treshhold_in_seconds)
end

function Wsse:authenticate(header_string)
    local wsse_key
    local secret
    local strict_timeframe_validation
    local wsse_params = parse_header(header_string)

    check_required_params(wsse_params)

    local status, err = pcall(function()
        wsse_key = self.key_db:find_by_username(wsse_params.username)
        strict_timeframe_validation = wsse_key.strict_timeframe_validation
        secret = wsse_key.secret
    end)

    if not status then
        throw_error_and_log("Credentials are invalid.")
    end

    validate_credentials(wsse_params, secret)

    self.timeframe_validator:validate(wsse_params.created, strict_timeframe_validation)

    return wsse_key
end

function Wsse.generate_header(username, secret, created, nonce)
    if not username or not secret then
        throw_error_and_log("Username and secret are required.")
    end

    created = created or os.date("!%Y-%m-%dT%TZ")
    nonce = nonce or uuid()

    local encoded_digest = base64.encode(generate_password_digest(nonce, created, secret))

    return string.format('UsernameToken Username="%s", PasswordDigest="%s", Nonce="%s", Created="%s"', username, encoded_digest, nonce, created)
end

return Wsse
