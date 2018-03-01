local KeyDb = require "kong.plugins.wsse.key_db"

describe("key db", function()

    local key_db = KeyDb()

    describe("#find_by_username", function()
        it("should raise error when username not given", function()
            assert.has_error(function() key_db:find_by_username() end, "Username is required!")
        end)

        it("should raise ane error when username could not be found", function ()
            assert.has_error(function() key_db:find_by_username("non existing user") end, "Username could not be found!")
        end)

        it("should return with the correct secret when username exists", function()
            assert.are.equal('test', key_db:find_by_username('test'))
        end)
    end)

end)