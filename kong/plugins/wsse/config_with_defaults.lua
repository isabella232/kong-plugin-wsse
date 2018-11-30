local SchemaDefaults = require "kong.plugins.wsse.schema_defaults"

local ConfigWithDefaults = {}

function ConfigWithDefaults.merge(plugin_schema, plugin_config)
    local config_with_defaults = SchemaDefaults.collect(plugin_schema)

    for field, value in pairs(plugin_config) do
        config_with_defaults[field] = value
    end

    return config_with_defaults
end

return ConfigWithDefaults
