local BasePlugin = require "kong.plugins.base_plugin"

local WsseHandler = BasePlugin:extend()

WsseHandler.PRIORITY = 2000

function WsseHandler:new()
  WsseHandler.super.new(self, "wsse")
end

function WsseHandler:access(conf)
  WsseHandler.super.access(self)

  if conf.say_hello then
    ngx.log(ngx.ERR, "============ Hey World! ============")
    ngx.header["Hello-World"] = "Hey!"
  else
    ngx.log(ngx.ERR, "============ Bye World! ============")
    ngx.header["Hello-World"] = "Bye!"
  end

end

return WsseHandler
