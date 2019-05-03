local Object = require "classic"
local date = require "date"

local TimeframeValidator = Object:extend()

function TimeframeValidator:new(threshold_in_seconds)
    self.threshold_in_seconds = threshold_in_seconds
end

local function is_valid_timestamp_format(timestamp)
    local success = pcall(date, timestamp)

    return success
end

local function remove_fragment_seconds(datetime_string)
    return string.gsub(datetime_string, "(%.%d+)(([-+])(%d%d):?(%d?%d?))$", "%2")
end

local function has_timezone_info(str)
    if str:sub(-1) == "Z" then
        return true
    end

    return str:find("([-+])(%d%d):?(%d?%d?)$") or false
end

local function is_dst_transition()
    local one_day_in_seconds = 86400
    local yesterday = os.date("*t", os.time() - one_day_in_seconds)
    local today = os.date("*t", os.time())

    return yesterday.isdst ~= today.isdst
end

local function is_timestamp_within_threshold(timestamp, threshold_in_seconds)
    local current_date_time = date(os.time())
    local x = remove_fragment_seconds(timestamp)
    local given_timestamp = date(x)

    if not has_timezone_info(timestamp) then
        given_timestamp:toutc()
    end

    local difference = math.abs(date.diff(given_timestamp, current_date_time):spanseconds())
    local dst_correction = 0

    if is_dst_transition() then
        local one_hour_in_seconds = 60 * 60

        dst_correction = one_hour_in_seconds
    end

    return difference > threshold_in_seconds + dst_correction
end

function TimeframeValidator:validate(timestamp)
    if not is_valid_timestamp_format(timestamp) then
        return false, "Invalid timestamp format"
    end

    if is_timestamp_within_threshold(timestamp, self.threshold_in_seconds) then
        local now = date(os.time()):fmt("${iso}Z")
        local given = date(timestamp):fmt("${iso}Z")

        return false, string.format("Timestamp is outside the acceptable threshold (current time: '%s', wsse header time: '%s')", now, given)
    end

    return true
end

return TimeframeValidator
