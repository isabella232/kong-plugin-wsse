local SchemaDefaults = require "kong.plugins.wsse.schema_defaults"
local plugin_schema = require "kong.plugins.wsse.schema"

describe("SchemaDefaults", function()
    describe(".collect", function()
        it("should return an empty table for an empty schema", function()
            local test_schema = {}
            assert.are.same({}, SchemaDefaults.collect(test_schema))
        end)

        it("should return default values", function()
            local test_schema = {
                fields = {
                    my_config = { type = "string", default = "some value" },
                    without_default = { type = "string" },
                    is_a_table = { type = "table", schema = { fields = {} } }
                }
            }
            assert.are.same({
                my_config = "some value"
            }, SchemaDefaults.collect(test_schema))
        end)

        it("should parse the plugin schema correctly", function()
            assert.are.same({
                timeframe_validation_treshhold_in_minutes = 5,
                strict_key_matching = true,
                message_template = '{"message": "%s"}',
                status_code = 401
            }, SchemaDefaults.collect(plugin_schema))
        end)
    end)
end)
