local constants = require "kong.constants"
local responses = require "kong.tools.responses"
local BasePlugin = require "kong.plugins.base_plugin"
local ConsumerDb = require "kong.plugins.wsse.consumer_db"
local KeyDb = require "kong.plugins.wsse.key_db"
local Logger = require "logger"
local Wsse = require "kong.plugins.wsse.wsse_lib"
local singletons = require "kong.singletons"

local WsseHandler = BasePlugin:extend()

WsseHandler.PRIORITY = 1006

local function set_consumer(consumer, wsse_key)
    ngx.req.set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
    ngx.req.set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)

    ngx.ctx.authenticated_consumer = consumer

    if wsse_key then
        ngx.req.set_header(constants.HEADERS.CREDENTIAL_USERNAME, wsse_key.username)
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, nil)

        ngx.ctx.authenticated_credential = wsse_key
    else
        ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
    end
end

local function authenticate(auth_header, timeframe_threshold_in_minutes)
    local authenticator = Wsse:new(KeyDb(), timeframe_threshold_in_minutes)

    return authenticator:authenticate(auth_header)
end

local function anonymous_passthrough_is_enabled(plugin_config)
    return plugin_config.anonymous ~= nil
end

local function already_authenticated_by_other_plugin(plugin_config, authenticated_credential)
    return anonymous_passthrough_is_enabled(plugin_config) and authenticated_credential ~= nil
end

local function iterate_pages(dao)
    local page_size = 1000

    local from = 1
    local current_page = dao:find_page(nil, from, page_size)
    local index_on_page = 1

    return function()
        while #current_page > 0 do
            local element = current_page[index_on_page]

            if element then
                index_on_page = index_on_page + 1
                return element
            else
                from = from + page_size
                current_page = dao:find_page(nil, from, page_size)
                index_on_page = 1
            end
        end

        return nil
    end
end

local function identity(entity)
    return entity
end

local function cache_all_entities_in(dao, key_retriever)
    for entity in iterate_pages(dao) do
        local unique_identifier = key_retriever(entity)
        local cache_key = dao:cache_key(unique_identifier)
        
        singletons.cache:get(cache_key, nil, identity, entity)
    end
end

local function retrieve_id_from_consumer(consumer)
    return consumer.id
end

local function retrieve_wsse_key_name(wsse_key)
    return wsse_key.key
end

function WsseHandler:new()
    WsseHandler.super.new(self, "wsse")
end

function WsseHandler:init_worker()
    WsseHandler.super.init_worker(self)

    cache_all_entities_in(singletons.dao.consumers, retrieve_id_from_consumer)
    cache_all_entities_in(singletons.dao.wsse_keys, retrieve_wsse_key_name)
end 

function WsseHandler:access(conf)
    WsseHandler.super.access(self)

    if already_authenticated_by_other_plugin(conf, ngx.ctx.authenticated_credential) then
        return
    end

    local wsse_header_string = ngx.req.get_headers()["X-WSSE"]

    local successful_auth, error_or_wsse_key = pcall(
        authenticate,
        wsse_header_string,
        conf.timeframe_validation_treshhold_in_minutes
    )

    local success, result = pcall(function()
        if successful_auth then
            Logger.getInstance(ngx):logInfo({msg = "WSSE authentication was successful."})

            local consumer_db = ConsumerDb()
            local consumer = consumer_db.find_by_id(error_or_wsse_key.consumer_id)

            set_consumer(consumer, error_or_wsse_key)
        elseif anonymous_passthrough_is_enabled(conf) then
            Logger.getInstance(ngx):logInfo({msg = "WSSE authentication failed, allowing anonymous passthrough."})

            local consumer_db = ConsumerDb()
            local consumer = consumer_db.find_by_id(conf.anonymous, true)

            set_consumer(consumer)
        else
            Logger.getInstance(ngx):logInfo({status = 401, msg = error_or_wsse_key.msg})

            return responses.send(401, error_or_wsse_key.msg)
        end
    end)

    if not success then
        Logger.getInstance(ngx).logError(result)
        return responses.send(500, "An unexpected error occurred.")
    end

    return result
end

return WsseHandler
