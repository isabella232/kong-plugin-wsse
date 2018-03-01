local Object = require("kong.plugins.wsse.classic")

local KeyDb = Object:extend()

function KeyDb:find_by_username(username)
    if username == nil then
        error("Username is required!")
    end

    if username == "test" then
        return "test"
    else
        error("Username could not be found!")
    end
end

return KeyDb