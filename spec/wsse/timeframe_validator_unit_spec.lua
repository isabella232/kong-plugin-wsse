local date = require "date"
local Logger = require "logger"
local TimeframeValidator = require "kong.plugins.wsse.timeframe_validator"

describe("wsse timeframe validator", function()

    local timeframe_validator = TimeframeValidator(5 * 60)

    Logger.getInstance = function()
        return {
            logWarning = function() end
        }
    end

    describe("#validate", function()

        it("raises error when timestamp string is not in valid format", function()
            local is_valid, err = timeframe_validator:validate("not valid timeframe string")

            assert.is_false(is_valid)
            assert.is_equal("Invalid timestamp format", err)
        end)

        local formats = {
            date(false):fmt("%Y-%m-%dT%H:%M:%S%z"),
            date(true):fmt("%Y-%m-%dT%H:%M:%SZ"),
            date(true):fmt("%Y-%m-%dT%H:%M:%\fZ"),
            date(true):addhours(2):fmt("%Y-%m-%dT%H:%M:%S+02:00"),
            date(true):addhours(-2):fmt("%Y-%m-%dT%H:%M:%S-02:00"),
        }

        for i, format in ipairs(formats) do
            it("should not raise error for format #" .. i .. " (" .. format .. ")", function()
                local is_valid, err = timeframe_validator:validate(format)

                assert.is_true(is_valid)
                assert.is_nil(err)
            end)
        end

        local function strip_info_in_brackets(msg)
            return string.gsub(msg, " %(.*%)", "")
        end

        it("raises error when the given timestamp is more than 5 minutes ahead", function()
            local five_minutes_from_now = date(true):addseconds(301):fmt("${iso}Z")

            local is_valid, err = timeframe_validator:validate(five_minutes_from_now)

            assert.is_false(is_valid)
            assert.is_equal("Timestamp is outside the acceptable threshold", strip_info_in_brackets(err))
        end)

        it("raises error when the given timestamp is more than 5 minutes behind", function()
            local five_minutes_behind = date(true):addseconds(-301):fmt("${iso}Z")

            local is_valid, err = timeframe_validator:validate(five_minutes_behind)

            assert.is_false(is_valid)
            assert.is_equal("Timestamp is outside the acceptable threshold", strip_info_in_brackets(err))
        end)

        it("returns true when validation succeeds", function()
            local valid_timestamp = date(true):addseconds(-10):fmt("${iso}Z")

            local is_valid, err = timeframe_validator:validate(valid_timestamp)

            assert.is_true(is_valid)
            assert.is_nil(err)
        end)

        it("returns true when datetime is valid local time without timezone info", function()
            local valid_timestamp = date(false):addseconds(-10):fmt("${iso}")

            local is_valid, err = timeframe_validator:validate(valid_timestamp)

            assert.is_true(is_valid)
            assert.is_nil(err)
        end)

        it("returns true when datetime is valid local time without timezone info", function()
            local valid_timestamp = date(false):addseconds(-10):fmt("${iso}.000%z")

            local is_valid, err = timeframe_validator:validate(valid_timestamp)

            assert.is_true(is_valid)
            assert.is_nil(err)
        end)

        it("returns true when datetime is valid time with timezone info", function()
            local valid_timestamp = date(false):addseconds(-10):fmt("${iso}%z")

            local is_valid, err = timeframe_validator:validate(valid_timestamp)

            assert.is_true(is_valid)
            assert.is_nil(err)
        end)

        it("returns true when created date is greater than actual date more then threshold but less than 1 hour plus threshold and actual date is daylight saving day", function()
            local valid_timestamp = date(2017, 10, 29, 1, 59, 17):fmt("${iso}Z")
            local now = os.time({ year = 2017, month = 10, day = 29, hour = 4, min = 1, sec = 35 })
            local old_time = os.time

            os.time = function()
                return now
            end

            local is_valid, err = timeframe_validator:validate(valid_timestamp)

            assert.is_true(is_valid)
            assert.is_nil(err)

            os.time = old_time
        end)

        it("raises error when created date is greater than actual date more then threshold plus 1 hour and actual date is daylight saving day", function()
            local invalid_timestamp = date(2017, 10, 29, 1, 59, 17):fmt("${iso}Z")
            local now = os.time({ year = 2017, month = 10, day = 29, hour = 4, min = 5, sec = 35 })
            local old_time = os.time

            os.time = function()
                return now
            end

            local is_valid, err = timeframe_validator:validate(invalid_timestamp)

            assert.is_false(is_valid)
            assert.is_equal("Timestamp is outside the acceptable threshold", strip_info_in_brackets(err))

            os.time = old_time
        end)

    end)

end)
