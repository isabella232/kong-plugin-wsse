local Object = require("kong.plugins.wsse.classic")
local date = require "date"
local threshold_in_seconds = 300

local TimeframeValidator = Object:extend()

local function is_valid_timestamp_format(timestamp)

    local success, time = pcall(function()
        return date(timestamp)
    end)

    return success
end

local function is_timestamp_in_threshold(timestamp)
    local current_date_time = os.date('%Y-%m-%dT%H:%M:%SZ')
    local given_timestamp = date(timestamp)
    local difference = math.abs(date.diff(given_timestamp, current_date_time):spanseconds())

    return difference > threshold_in_seconds
end

function TimeframeValidator:validate(timestamp)

    if not is_valid_timestamp_format(timestamp) then
        error("not valid timeframe format")
    end

    if (is_timestamp_in_threshold(timestamp)) then
        error("timestamp is out of threshold")
    end

    return true
end

return TimeframeValidator