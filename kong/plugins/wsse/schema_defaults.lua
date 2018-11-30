local SchemaDefaults = {}

function SchemaDefaults.collect(plugin_schema)
    local result = {}

    for key, value in pairs(plugin_schema.fields or {}) do
        result[key] = value.default
    end

    return result
end

return SchemaDefaults
