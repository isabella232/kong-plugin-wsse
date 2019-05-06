local singletons = require "kong.singletons"
local Object = require "classic"
local Logger = require "logger"

local KeyDb = Object:extend()

local function load_credential(username, strict_key_matching)
    local rows, err = singletons.dao.wsse_keys:find_all({ key = username })

    if (err ~= nil or #rows == 0) and not strict_key_matching then
        rows, err = singletons.dao.wsse_keys:find_all({ key_lower = username:lower() })
    end

    if err or #rows == 0 then
        return nil, err
    end

    return rows[1]
end

function KeyDb:new(strict_key_matching)
    self.strict_key_matching = strict_key_matching
end

function KeyDb:find_by_username(username)
    if username == nil then
        error({ msg = "Username is required." })
    end

    local wsse_cache_key = singletons.dao.wsse_keys:cache_key(username)
    local wsse_key, err = singletons.cache:get(wsse_cache_key, nil, load_credential, username, self.strict_key_matching)

    if err then
        Logger.getInstance(ngx):logError(err)
        error({ msg = "WSSE key could not be loaded from DB." })
    end

    if wsse_key == nil then
        error({ msg = "WSSE key can not be found." })
    end

    return wsse_key
end

return KeyDb