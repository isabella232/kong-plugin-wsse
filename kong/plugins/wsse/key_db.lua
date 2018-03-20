local singletons = require "kong.singletons"
local Object = require("classic")
local Logger = require "kong.plugins.wsse.logger"

local KeyDb = Object:extend()

function KeyDb.find_by_username(username)
    if username == nil then
        Logger.getInstance(ngx):logWarning({message = "Username is required."})
        error({msg = "Username is required."})
    end

    local rows, err = singletons.dao.wsse_keys:find_all {key = username}
    if err or rows[1] == nil then
        Logger.getInstance(ngx):logWarning({message = "WSSE key can not be found."})
        error({msg = "WSSE key can not be found."})
    end

    return rows[1]
end

return KeyDb