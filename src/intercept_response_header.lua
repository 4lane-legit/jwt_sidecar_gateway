local json = require "cjson"

ngx.var.metadata = ngx.header["X-Service-Metadata"]
ngx.header["X-Service-Metadata"] = nil  -- Don\'t want to expose internal data

if ngx.var.metadata then
    
    local metadata = json:decode(ngx.var.metadata)
    ngx.var.duration = metadata["duration"]
    ngx.var.request_id = metadata["request_id"]
    ngx.var.user_id = metadata["user_id"]
end
