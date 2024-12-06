package = "kong-plugin-correlation-id"
version = "1.0.0-1"
source = {
   url = "git://github.com/yourusername/kong-plugin-correlation-id",
   tag = "1.0.0"
}
description = {
   summary = "A Kong plugin that adds correlation IDs to requests",
   detailed = [[
      This plugin adds correlation IDs to requests to help with request tracing
      across microservices.
   ]],
   homepage = "http://github.com/yourusername/kong-plugin-correlation-id",
   license = "Apache 2.0"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.correlation-id.handler"] = "kong/plugins/correlation-id/handler.lua",
      ["kong.plugins.correlation-id.schema"] = "kong/plugins/correlation-id/schema.lua"
   }
}
