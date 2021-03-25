local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

describe("WSSE #plugin #schema #e2e", function()

    local kong_sdk
    local service

    setup(function()
        kong_helpers.start_kong({ plugins = "wsse" })

        kong_sdk = test_helpers.create_kong_client()
    end)

    teardown(function()
        kong_helpers.stop_kong()
    end)

    before_each(function()
        kong_helpers.db:truncate()

        service = kong_sdk.services:create({
            name = "testservice",
            url = "http://mockbin:8080/request"
        })
    end)

    it("should use dafaults when config values are not provided", function()
        local plugin = kong_sdk.plugins:create({
            service = { id = service.id },
            name = "wsse",
            config = { encryption_key_path = "/secret.txt" }
        })

        assert.are.equals(plugin.config.anonymous, ngx.null)
        assert.are.equals(plugin.config.use_encrypted_secret, "no")
        assert.are.equals(plugin.config.timeframe_validation_threshold_in_minutes, 5)
        assert.are.equals(plugin.config.strict_key_matching, true)
        assert.are.equals(plugin.config.message_template, '{"message": "%s"}')
        assert.are.equals(plugin.config.status_code, 401)
        assert.are.equals(plugin.config.encryption_key_path, "/secret.txt")
    end)

    it("should not allow invalid values in 'use_encrypted_secret'", function()
        local _, response = pcall(function()
            kong_sdk.plugins:create({
                service = { id = service.id },
                name = "wsse",
                config = {
                    encryption_key_path = "/secret.txt",
                    use_encrypted_secret = "xxx"
                }
            })
        end)

        assert.are.equals(400, response.status)
        assert.are.equals("expected one of: yes, no", response.body.fields.config.use_encrypted_secret)
    end)

    context("when anonymous field is set", function()
        it("should throw error when anonymous is not a valid uuid", function()
            local _, response = pcall(function()
                kong_sdk.plugins:create({
                    service = { id = service.id },
                    name = "wsse",
                    config = {
                        encryption_key_path = "/secret.txt",
                        anonymous = "not-a-valid-uuid"
                    }
                })
            end)

            assert.are.equals(400, response.status)
            assert.are.equals("the anonymous user must be nil or a valid uuid", response.body.fields.config.anonymous)
        end)
    end)

    context("when message_template field is set", function()
        local test_cases = {'{"almafa": %s}', '""', '[{"almafa": "%s"}]'}
        for _, test_template in ipairs(test_cases) do
            it("should throw error when message_template is not valid JSON object", function()
                local _, response = pcall(function()
                    kong_sdk.plugins:create({
                        service = { id = service.id },
                        name = "wsse",
                        config = {
                            encryption_key_path = "/secret.txt",
                            message_template = test_template
                        }
                    })
                end)

                assert.are.equals(400, response.status)
                assert.are.equals("message_template should be valid JSON object", response.body.fields.config.message_template)
            end)
        end
    end)

    context("when status_code field is set", function()
        it("should throw error when it is lower than 100", function()
            local _, response = pcall(function()
                kong_sdk.plugins:create({
                    service = { id = service.id },
                    name = "wsse",
                    config = {
                        encryption_key_path = "/secret.txt",
                        status_code = 66
                    }
                })
            end)

            assert.are.equals(400, response.status)
            assert.are.equals("status code is invalid", response.body.fields.config.status_code)
        end)

        it("should throw error when it is higher than 600", function()
            local _, response = pcall(function()
                kong_sdk.plugins:create({
                    service = { id = service.id },
                    name = "wsse",
                    config = {
                        encryption_key_path = "/secret.txt",
                        status_code = 666
                    }
                })
            end)

            assert.are.equals(400, response.status)
            assert.are.equals("status code is invalid", response.body.fields.config.status_code)
        end)

        it("should succeed when it is within the range", function()
            local success, _ = pcall(function()
                return kong_sdk.plugins:create({
                    service = { id = service.id },
                    name = "wsse",
                    config = {
                        encryption_key_path = "/secret.txt",
                        status_code = 400
                    }
                })
            end)

            assert.are.equals(true, success)
        end)
    end)

    it("should respond 400 when encryption file does not exist", function()
        local _, response = pcall(function()
            kong_sdk.plugins:create({
                service = { id = service.id },
                name = "wsse",
                config = { encryption_key_path = "/non-existing-file.txt" }
            })
        end)

        assert.are.equals(400, response.status)
        assert.are.equals("Encryption key file could not be found.", response.body.fields.config["@entity"][1])
    end)

    it("should respond 400 when encryption file path does not equal with the other wsse plugin configurations", function()
        local other_service = kong_sdk.services:create({
            name = "second",
            url = "http://mockbin:8080/request"
        })

        local f = io.open("/tmp/other_secret.txt", "w")
        f:close()

        kong_sdk.plugins:create({
            service = { id = service.id },
            name = "wsse",
            config = { encryption_key_path = "/secret.txt" }
        })

        local _, response = pcall(function()
            kong_sdk.plugins:create({
                service = { id = other_service.id },
                name = "wsse",
                config = { encryption_key_path = "/tmp/other_secret.txt" }
            })
        end)

        assert.are.equals(400, response.status)
        assert.are.equals("All Wsse plugins must be configured to use the same encryption file.", response.body.fields.config["@entity"][1])
    end)

end)
