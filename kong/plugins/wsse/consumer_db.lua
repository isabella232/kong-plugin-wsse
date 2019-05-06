local singletons = require "kong.singletons"

local ConsumerDb = {}

local function load_consumer(consumer_id, is_anonymous)
    local result, err = singletons.dao.consumers:find({ id = consumer_id })

    if not result then
        if is_anonymous and not err then
            err = 'anonymous consumer "' .. consumer_id .. '" could not be found'
        end

        return nil, err
    end

    return result
end

local function find_by_id(consumer_id, is_anonymous)
    if not consumer_id then
        error({ msg = "Consumer id is required." })
    end

    local consumer_cache_key = singletons.dao.consumers:cache_key(consumer_id)
    local consumer, err = singletons.cache:get(consumer_cache_key, nil, load_consumer, consumer_id, is_anonymous)

    if err then
        error(err)
    end

    if not consumer then
        error({ msg = "Consumer could not be found." })
    end

    return consumer
end

function ConsumerDb.find_by_id(consumer_id)
    return find_by_id(consumer_id)
end

function ConsumerDb.find_anonymous(consumer_id)
    return find_by_id(consumer_id, true)
end

return ConsumerDb
