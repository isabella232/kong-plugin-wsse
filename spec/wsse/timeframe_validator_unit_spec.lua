local wsse_timeframe_validator = require "kong.plugins.wsse.timeframe_validator"
local date = require "date"

describe("wsse timeframe validator", function()

    local timeframe_validator = wsse_timeframe_validator()

    describe("#validate", function()

        it("raises error when timestamp string is not in valid format", function()
            assert.has_error(function() timeframe_validator:validate("not valid timeframe string") end, "not valid timeframe format")
        end)

        local formats = {
            date(false):fmt('%Y-%m-%dT%H:%M:%S%z'),
            date(true):fmt('%Y-%m-%dT%H:%M:%SZ'),
            date(true):fmt('%Y-%m-%dT%H:%M:%\fZ'),
            date(true):addhours(2):fmt('%Y-%m-%dT%H:%M:%S+02:00'),
            date(true):addhours(-2):fmt('%Y-%m-%dT%H:%M:%S-02:00'),
        }

        for i, format in ipairs(formats) do
            it("should not raise error for format #" .. i .. " (" .. format .. ")", function()
                assert.has_no.errors(function() timeframe_validator:validate(format) end)
            end)
        end

        it("raises error when the given timestamp is more than 5 minutes ahead", function()
            local five_minutes_from_now = date(true):addseconds(301):fmt('${iso}Z')
            assert.has_error(function() timeframe_validator:validate(five_minutes_from_now) end, "timestamp is out of threshold")
        end)

        it("raises error when the given timestamp is more than 5 minutes behind", function()
            local five_minutes_from_now = date(true):addseconds(-301):fmt('${iso}Z')
            assert.has_error(function() timeframe_validator:validate(five_minutes_from_now) end, "timestamp is out of threshold")
        end)

        it("returns true when validation succeeds", function()
            local valid_timestamp = date(true):addseconds(-10):fmt('${iso}Z')
            assert.True(timeframe_validator:validate(valid_timestamp))
        end)

    end)

end)
