local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"
local EncryptionKeyPathRetriever = require "kong.plugins.wsse.encryption_key_path_retriever"

describe("EncryptionKeyPathRetriever #e2e", function()

    local kong_sdk
    local service

    setup(function()
        kong_helpers.start_kong({ plugins = "wsse" })

        kong_sdk = test_helpers.create_kong_client()
    end)

    before_each(function()
        kong_helpers.db:truncate()

        service = kong_sdk.services:create({
            name = "testservice",
            url = "http://mockbin:8080/request"
        })
    end)

    teardown(function()
        kong_helpers.stop_kong()
    end)

    describe("#find_key_path", function()
        it("should return nil when no wsse plugin is added", function()
            local key_retriever = EncryptionKeyPathRetriever(kong_helpers.db)

            assert.is_nil(key_retriever:find_key_path())
        end)

        it("should return the encryption_key_path of the first wsse plugin found", function()
            kong_sdk.plugins:create({
                service = { id = service.id },
                name = "wsse",
                config = { encryption_key_path = "/secret.txt" }
            })
            local key_retriever = EncryptionKeyPathRetriever(kong_helpers.db)

            assert.is.equal("/secret.txt", key_retriever:find_key_path())
        end)
    end)
end)