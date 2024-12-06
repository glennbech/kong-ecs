local BasePlugin = require "kong.plugins.base_plugin"
local uuid = require "resty.jit-uuid"

local CorrelationIdHandler = BasePlugin:extend()

CorrelationIdHandler.PRIORITY = 1000
CorrelationIdHandler.VERSION = "1.0.0"

function CorrelationIdHandler:new()
  CorrelationIdHandler.super.new(self, "correlation-id")
end

function CorrelationIdHandler:access(conf)
  CorrelationIdHandler.super.access(self)
  
  -- Get correlation ID from header or generate new one
  local correlation_id = kong.request.get_header(conf.header_name)
  if not correlation_id then
    correlation_id = uuid.generate_v4()
  end
  
  -- Set the correlation ID in headers for both request and response
  kong.service.request.set_header(conf.header_name, correlation_id)
  kong.response.set_header(conf.header_name, correlation_id)
end

return CorrelationIdHandler
