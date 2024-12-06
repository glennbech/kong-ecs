local kong = kong

local CorrelationIdHandler = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
}

function CorrelationIdHandler:access(conf)
  -- Get correlation ID from header or generate new one
  local correlation_id = kong.request.get_header(conf.header_name)
  if not correlation_id then
    -- Using a simple timestamp-based ID since we don't have uuid module
    correlation_id = string.format("%d-%d", os.time(), math.random(1000000))
  end
  
  -- Set the correlation ID in headers for both request and response
  kong.service.request.set_header(conf.header_name, correlation_id)
  kong.response.set_header(conf.header_name, correlation_id)
end

return CorrelationIdHandler
