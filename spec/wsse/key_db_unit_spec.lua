local Logger = require "logger"
local KeyDb = require "kong.plugins.wsse.key_db"

Logger.getInstance = function()
    return {
        logError = function() end
    }
end

describe("KeyDb", function()

    local original_kong

    setup(function()
        original_kong = _G.kong
    end)

    teardown(function()
        _G.kong = original_kong
    end)

    describe("#find_by_username", function()

        context("when kong does not queries the database", function()
            before_each(function()
                _G.kong = {
                    db = {
                        wsse_keys = {
                            cache_key = function() end
                        }
                    },
                    cache = {
                        get = function() end
                    }
                }
            end)

            it("should throw error when username is nil", function()
                local strict_key_matching = false;
                local username = nil;
                local expected_error = {
                    msg = "Username is required.",
                }

                assert.has.errors(function()
                    KeyDb(strict_key_matching):find_by_username(username)
                end, expected_error)
            end)

            it("should throw error when username is injected", function()
                local strict_key_matching = false;
                local username = "' or 1=1;--";
                local expected_error = {
                    msg = "Username contains illegal characters.",
                }

                assert.has.errors(function()
                    KeyDb(strict_key_matching):find_by_username(username)
                end, expected_error)
            end)

            it("should throw error when username is not found", function()
                local strict_key_matching = false;
                local username = "non_existing";
                local expected_error = {
                    msg = "WSSE key can not be found.",
                }

                assert.has.errors(function()
                    KeyDb(strict_key_matching):find_by_username(username)
                end, expected_error)
            end)
        end)

        context("when kong queries the database and throws an error", function()
            before_each(function()
                _G.kong = {
                    db = {
                        wsse_keys = {
                            cache_key = function() end
                        }
                    },
                    cache = {
                        get = function()
                            return nil, "error"
                        end
                    }
                }
            end)

            it("should throw error when database error happens", function()
                local strict_key_matching = false;
                local username = "username";
                local expected_error = {
                    msg = "WSSE key could not be loaded from DB.",
                }

                assert.has.errors(function()
                    KeyDb(strict_key_matching):find_by_username(username)
                end, expected_error)
            end)
        end)

        context("when kong queries the database and returns a result", function()
            before_each(function()
                local counter = 0;
                local key = {
                    key = "username",
                    secret = "irrelevant",
                    consumer_id = "consumer"
                }

                _G.kong = {
                    db = {
                        wsse_keys = {
                            cache_key = function() end
                        },
                        connector = {
                            query = function()
                                local result = counter == 0 and {} or {key}
                                counter = counter + 1
                                return result
                            end
                        }
                    },
                    cache = {
                        get = function(self, key, opts, cb, param1, param2)
                            return cb(param1, param2)
                        end
                    }
                }
            end)

            it("should return a wsse key", function()
                local strict_key_matching = false;
                local username = "USERNAME";
                local expected_key = {
                    key = "username",
                    secret = "irrelevant",
                    consumer = {
                        id = "consumer"
                    }
                }

                local key = KeyDb(strict_key_matching):find_by_username(username);

                assert.are.same(expected_key, key)
            end)
        end)
    end)
end)
