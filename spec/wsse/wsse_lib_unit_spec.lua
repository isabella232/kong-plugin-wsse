local uuid = require "uuid"
local Logger = require "logger"
local wsse_lib = require "kong.plugins.wsse.wsse_lib"

describe("wsse lib", function()

    Logger.getInstance = function()
        return {
            logWarning = function() end
        }
    end

    local key_db = {
        find_by_username = function(self, username)
            if username == nil then
                error({ msg = "Username is required." })
            end

            if username == "test" then
                return {
                    id = 1,
                    consumer_id = 1,
                    key = "test",
                    secret = "test",
                    strict_timeframe_validation = true
                }
            elseif username == "test2" then
                return {
                    id = 2,
                    consumer_id = 2,
                    key = "test2",
                    secret = "test2",
                    strict_timeframe_validation = false
                }
            else
                error({msg = "WSSE key could not be found."})
            end
         end
    }

    local wsse = wsse_lib(key_db, 5)
    local test_wsse_header = wsse_lib.generate_header('test', 'test', uuid())

    describe("#authenticate", function()

        it("raises error when WSSE header is an empty string", function()
            assert.has_error(function() wsse:authenticate("") end, { msg = "WSSE authentication header is empty." })
        end)

        it("does not raise error when WSSE header is a valid wsse header string", function()
            assert.has_no.errors(function() wsse:authenticate(test_wsse_header) end)
        end)

        it("raises error when PasswordDigest is missing from WSSE header", function()
            local partial_test_wsse_header = string.gsub(test_wsse_header, "PasswordDigest=\"[^,]+\",", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end, { msg = "The PasswordDigest field is missing from WSSE authentication header." })
        end)

        it("raises error when Username is missing from WSSE header", function()
            local partial_test_wsse_header = string.gsub(test_wsse_header, "Username=\"[^,]+\",", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end, { msg = "The Username field is missing from WSSE authentication header." })
        end)

        it("raises error when Nonce is missing from WSSE header", function()
            local partial_test_wsse_header = string.gsub(test_wsse_header, "Nonce=\"[^,]+\",", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end, { msg = "The Nonce field is missing from WSSE authentication header." })
        end)

        it("raises error when Created is missing from WSSE header", function()
            local partial_test_wsse_header = string.gsub(test_wsse_header, "Created=\"[^,]+\"", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end, { msg = "The Created field is missing from WSSE authentication header." })
        end)

        it("does not raise error when WSSE header parameters have random casing ", function()
            local header = string.gsub(test_wsse_header, "%w+=", {
                ["Username="] = "uSeRnAmE=",
                ["PasswordDigest="] = "passworddigest=",
                ["Nonce="] = "NONCE=",
                ["Created="] = "Created=",
            })

            assert.has_no.errors(function() wsse:authenticate(header) end)
        end)

        it("should not raise error when WSSE header parameters have extra spaces ", function()
            local header = string.gsub(test_wsse_header, "%w+=", {
                ["Username="] = "Username =",
                ["PasswordDigest="] = "PasswordDigest= ",
                ["Nonce="] = "Nonce=",
                ["Created="] = "Created = ",
            })

            assert.has_no.errors(function() wsse:authenticate(header) end)
        end)

        it("should not raise error when the UsernameToken string is missing", function()
            local header = string.gsub(test_wsse_header, "UsernameToken%s+", "")

            assert.has_no.errors(function() wsse:authenticate(header) end)
        end)

        it("should not raise error when there is no space between UsernameToken and Username", function()
            local header = string.gsub(test_wsse_header, "UsernameToken(%s+)Username", "UsernameTokenUsername")

            assert.has_no.errors(function() wsse:authenticate(header) end)
        end)

        it("should not raise error when WSSE header parameters have extra padding", function()
            local header = string.gsub(test_wsse_header, 'PasswordDigest%s*=%s*"([^",]+)",', 'PasswordDigest="%1=======",')

            assert.has_no.errors(function() wsse:authenticate(header) end)
        end)

        it("should not raise error when WSSE header parameters have invalid characters in the digest", function()
            local header = string.gsub(test_wsse_header, 'PasswordDigest%s*=%s*"([^",]+)",', 'PasswordDigest=".%1",')

            assert.has_no.errors(function() wsse:authenticate(header) end)
        end)

        it("should raise error when API user could not be found", function ()
            assert.has.errors(function() wsse:authenticate('UsernameToken Username="non existing user", PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"') end, {msg = "Credentials are invalid."})
        end)

        it("should raise error when wrong secret was given", function ()
            assert.has.errors(function() wsse:authenticate('UsernameToken Username="test", PasswordDigest="almafa", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"') end, {msg = "Credentials are invalid."})
        end)

        it("should raise error when timeframe is invalid and strict_timeframe_validation is true", function ()
            assert.has.errors(function() wsse:authenticate('UsernameToken Username="test", PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"') end, {msg = "Timeframe is invalid."})
        end)

        it("should not raise error when timeframe is invalid and strict_timeframe_validation is false", function ()
            local test_wsse_header_non_strict = wsse_lib.generate_header('test2', 'test2', uuid(), '2018-02-27T09:46:22Z')
            assert.has_no.errors(function() wsse:authenticate(test_wsse_header_non_strict) end)
        end)

        it("should return with the wsse key when authentication was successful", function()
            local expected_key = {
                id = 1,
                consumer_id = 1,
                key = "test",
                secret = "test",
                strict_timeframe_validation = true
            }

            local wsse_key = wsse:authenticate(test_wsse_header)

            assert.are.same(expected_key, wsse_key)
        end)

        it("should return wsse key when base64 padding is missing", function()
            local wsse_header = wsse_lib.generate_header("test2", "test2", "110118", "2019-02-22T13:09:00Z")
            local digest_without_padding = wsse_header:match('PasswordDigest="(.-)"'):gsub("=", "")

            assert.is_true(#digest_without_padding % 4 > 0)

            wsse_header = wsse_header:gsub('PasswordDigest="(.-)"', 'PasswordDigest="' .. digest_without_padding .. '"')

            local wsse_key = wsse:authenticate(wsse_header)

            assert.are.equal("test2", wsse_key.key)
        end)

    end)

    describe("#generate_header", function()

        it("raises error when no argument was given", function()
            assert.has_error(wsse_lib.generate_header, { msg = "Username, secret, and nonce are required." })
        end)

        it("returns with a generated wsse header string when username, secret, created, and nonce was given", function()
            local generated_wsse_header = wsse_lib.generate_header('test', 'test', '44ab5733c8d764bc2712c62f77abeeec','2018-03-01T09:15:38Z')
            local excepted_wsse_header = 'UsernameToken Username="test", PasswordDigest="NTY0MzllMzJlMzM3NTFiNzQ2ZWVkMGEzZDRjNGQwODZiM2U2ZWJlYQ==", Nonce="44ab5733c8d764bc2712c62f77abeeec", Created="2018-03-01T09:15:38Z"'

            assert.are.equal(excepted_wsse_header, generated_wsse_header)
        end)

    end)

end)
