local json = require 'cjson'
local jwt = require 'resty.jwt'
local http = require 'resty.http'
local globtopattern = require 'globtopattern'.globtopattern

local auth_header = ngx.var.http_Authorization
local current_url = ngx.var.scheme .."://".. ngx.var.http_host .. ngx.var.request_uri

local public_key_prefix = "-----BEGIN PUBLIC KEY-----"
local public_key_suffix = "-----END PUBLIC KEY-----"
local new_line_string = "\n"

local required_issuer = os.getenv("SSO_ISSUER")
local authz_config = os.getenv("AUTHORIZATION_CONFIG")

if ngx.req.get_method() ~= "OPTIONS" then

    if auth_header == nil then
        ngx.log(ngx.WARN, "No Authorization header")
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local _, _, token = string.find(auth_header, "Bearer%s+(.+)")

    if token == nil then
        ngx.log(ngx.WARN, "No token found")
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local jwt_obj = jwt:load_jwt(token)
    local payload = jwt_obj["payload"]

    if payload == nil then
        ngx.log(ngx.WARN, "Payload not found in JWT")
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    if payload["typ"] ~= "Bearer" then
        ngx.log(ngx.WARN, "Only support bearer tokens" )
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local issuer = payload["iss"]
    if issuer == nil then
        ngx.log(ngx.WARN, "Issuer not found in JWT" )
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local token_issuers = ngx.shared.token_issuers

    local public_key = nil
    if (token_issuers ~= nil) then
        public_key = token_issuers:get(issuer)
    end

    -- get the host name out
    local token_issuer = jwt_obj["payload"]["iss"]:match('^%w+://([^/]+)')
    -- match it with what we have on env
    if token_issuer:gsub('-', '%-'):match(required_issuer:gsub('-', '%-') .. '$') == nil then
        ngx.log(ngx.WARN, "Token issuer verification failed: " .. token_issuer)
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    if public_key == nil then
        local httpc = http.new()
        local res, err = httpc:request_uri(issuer, {
            method = "GET",
            ssl_verify = false
        })

        if err then
            ngx.log(ngx.WARN, "JWT issuer verification failed: " .. err .. issuer)
            ngx.log(ngx.WARN, "Token: " .. token)
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end

        local encoded_response = json.decode(res.body)
        ngx.log(ngx.WARN, "Response for public key: " .. res.body )
        ngx.log(ngx.WARN, "ISS reponse: " .. encoded_response.public_key)

        public_key = public_key_prefix .. new_line_string .. encoded_response.public_key .. new_line_string .. public_key_suffix
        ngx.log(ngx.WARN, "Public key: " .. public_key)
        ngx.log(ngx.WARN, "Issuer URL: " .. issuer)
        token_issuers:set(issuer, public_key, 60)  -- expires in 60 sec
    end

    jwt:set_alg_whitelist({ RS256 = 1 })
    jwt_obj = jwt:verify(public_key, token)

    if not jwt_obj["verified"] then
        ngx.log(ngx.WARN, "Authentication failed: " .. jwt_obj["reason"])
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    -- Add support for roles


end

