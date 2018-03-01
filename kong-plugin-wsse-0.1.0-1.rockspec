package = "kong-plugin-wsse"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}
source = {
  url = "git+https://github.com/emartech/kong-plugin-wsse.git",
  tag = "0.1.0"
}
description = {
  summary = "WSSE auth plugin for Kong API gateway.",
  homepage = "https://github.com/emartech/kong-plugin-wsse",
  license = "UNLICENSED"
}
dependencies = {
  "lua ~> 5.1",
  "lbase64 20120820-1",
  "sha1 0.5-1",
  "uuid 0.2-1"

}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.wsse.handler"] = "kong/plugins/wsse/handler.lua",
    ["kong.plugins.wsse.schema"] = "kong/plugins/wsse/schema.lua",
  }
}
