local wsse_lib = require "kong.plugins.wsse.wsse_lib"
local base64 = require "base64"
local sha1 = require "sha1"
local uuid = require("uuid")

describe("wsse lib", function()

    local wsse = wsse_lib:new()

    local function generate_wsse_header(username, secret, created)
        if created == nil then
            created = os.date("!%Y-%m-%dT%TZ")
        end

        local nonce = uuid()
        local digest = base64.encode(sha1(nonce .. created .. secret))

        return string.format('UsernameToken Username="%s", PasswordDigest="%s", Nonce="%s", Created="%s"', username, digest, nonce, created)
    end

    describe("#check_header", function()

        it("raise error when WSSE header is an empty string", function()
            assert.has_error(function() wsse:authenticate("") end, "error")
        end)

        it("do not raise error when WSSE header is a valid wsse header string", function()
            assert.has_no.errors(function() wsse:authenticate(generate_wsse_header('test', 'test')) end)
        end)

        it("raise error when PasswordDigest is missing from WSSE header", function()
            assert.has_error(function() wsse:authenticate('UsernameToken Username="test", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"') end)
        end)

        it("raise error when Username is missing from WSSE header", function()
            assert.has_error(function() wsse:authenticate('UsernameToken PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25", Created="2018-02-27T09:46:22Z"') end)
        end)

        it("raise error when Nonce is missing from WSSE header", function()
            assert.has_error(function() wsse:authenticate('UsernameToken Username="test", PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Created="2018-02-27T09:46:22Z"') end)
        end)

        it("raise error when Created is missing from WSSE header", function()
            assert.has_error(function() wsse:authenticate('UsernameToken Username="test", PasswordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", Nonce="4603fcf8f0fb2ea03a41ff007ea70d25"') end)
        end)

        it("do not raise error when WSSE header parameters have random casing ", function()
            assert.has_no.errors(function() wsse:authenticate('UsernameToken username="test", PasSwordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", NONCE="4603fcf8f0fb2ea03a41ff007ea70d25", cReAtEd="2018-02-27T09:46:22Z"') end)
        end)

    end)

end)
