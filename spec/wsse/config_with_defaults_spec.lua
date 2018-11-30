local ConfigWithDefaults = require "kong.plugins.wsse.config_with_defaults"

describe("ConfigWithDefaults", function()
    describe(".merge", function()
        it("should return an empty table for an empty schema and empty config", function()
            local test_schema = {}
            local test_config = {}

            assert.are.same({}, ConfigWithDefaults.merge(test_schema, test_config))
        end)

        it("should return merged copy of schema defaults and config", function()
            local test_schema = {
                fields = {
                    my_config = { type = "string" },
                    with_default = { type = "string", default = "some other value" }
                }
            }

            local test_config = {
                my_config = "some value"
            }

            assert.are.same({
                my_config = "some value",
                with_default = "some other value"
            }, ConfigWithDefaults.merge(test_schema, test_config))
        end)
    end)
end)
