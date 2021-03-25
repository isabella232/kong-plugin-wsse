local typedefs = require "kong.db.schema.typedefs"
local utils = require "kong.tools.utils"
local cjson = require "cjson"
local EncryptionKeyPathRetriever = require "kong.plugins.wsse.encryption_key_path_retriever"

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

local function ensure_file_exists(file_path)
    local file = io.open(file_path, "r")

    if file == nil then
        return false, "Encryption key file could not be found."
    end

    file:close()

    return true
end

local function ensure_same_encryption_key_is_used(encryption_key_path, db)
    local path = EncryptionKeyPathRetriever(db):find_key_path()

    if path and path ~= encryption_key_path then
        return false, "All Wsse plugins must be configured to use the same encryption file."
    end

    return true
end


return {
    name = "wsse",
    fields = {
        {
            consumer = typedefs.no_consumer
        },
        {
            config = {
                type = "record",
                fields = {
                    { anonymous = { type = "string", default = nil, custom_validator = ensure_valid_uuid_or_nil } },
                    { timeframe_validation_threshold_in_minutes = { type = "number", default = 5 } },
                    { strict_key_matching = { type = "boolean", default = true } },
                    { encryption_key_path = { type = "string", required = true } },
                    { message_template = { type = "string", default = '{"message": "%s"}', custom_validator = ensure_message_template_is_valid_json } },
                    { status_code = { type = "number", default = 401, custom_validator = validate_http_status_code } },
                    { use_encrypted_secret = { type = "string", one_of = { "yes", "no", "darklaunch" }, default = "no" } }
                },
                entity_checks = {
                    { custom_entity_check = {
                        field_sources = { "encryption_key_path" },
                        fn = function(entity)
                            if entity.encryption_key_path ~= ngx.null then
                                local valid, error_message = ensure_file_exists(entity.encryption_key_path)
                                if not valid then
                                    return false, error_message
                                end
                                valid, error_message = ensure_same_encryption_key_is_used(entity.encryption_key_path, kong.db)
                                if not valid then
                                    return false, error_message
                                end
                            end
                            return true
                        end
                    } }
                }
            }
        }
    }
}
