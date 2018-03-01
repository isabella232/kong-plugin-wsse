local wsse_lib = require "kong.plugins.wsse.wsse_lib"

describe("wsse lib", function()

    local wsse = wsse_lib:new()
    local test_wsse_header = wsse:generate_header('test', 'test')

    describe("#authenticate", function()

        it("raise error when WSSE header is an empty string", function()
            assert.has_error(function() wsse:authenticate("") end, "error")
        end)

        it("do not raise error when WSSE header is a valid wsse header string", function()
            assert.has_no.errors(function() wsse:authenticate(test_wsse_header) end)
        end)

        it("raise error when PasswordDigest is missing from WSSE header", function()
            partial_test_wsse_header = string.gsub(test_wsse_header, "PasswordDigest=\"[^,]+\",", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end)
        end)

        it("raise error when Username is missing from WSSE header", function()
            partial_test_wsse_header = string.gsub(test_wsse_header, "Username=\"[^,]+\",", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end)
        end)

        it("raise error when Nonce is missing from WSSE header", function()
            partial_test_wsse_header = string.gsub(test_wsse_header, "Nonce=\"[^,]+\",", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end)
        end)

        it("raise error when Created is missing from WSSE header", function()
            partial_test_wsse_header = string.gsub(test_wsse_header, "Created=\"[^,]+\"", "")
            assert.has_error(function() wsse:authenticate(partial_test_wsse_header) end)
        end)

        it("do not raise error when WSSE header parameters have random casing ", function()
            assert.has_no.errors(function() wsse:authenticate('UsernameToken username="test", PasSwordDigest="ODM3MmJiN2U2OTA2ZDhjMDlkYWExY2ZlNDYxODBjYTFmYTU0Y2I0Mg==", NONCE="4603fcf8f0fb2ea03a41ff007ea70d25", cReAtEd="2018-02-27T09:46:22Z"') end)
        end)

    end)

    describe("#generate_header", function()

        it("raise error when no argument was given", function()
            assert.has_error(function() wsse:generate_header() end, "Username and secret are required!")
        end)

        it("return with a generated wsse header string when username, secret, created, and nonce was given", function()
            generated_wsse_header = wsse:generate_header('test', 'test', '2018-03-01T09:15:38Z', '44ab5733c8d764bc2712c62f77abeeec')
            excepted_wsse_header = 'UsernameToken Username="test", PasswordDigest="NTY0MzllMzJlMzM3NTFiNzQ2ZWVkMGEzZDRjNGQwODZiM2U2ZWJlYQ==", Nonce="44ab5733c8d764bc2712c62f77abeeec", Created="2018-03-01T09:15:38Z"'
            assert.are.equal(excepted_wsse_header, generated_wsse_header)
        end)

    end)

end)
