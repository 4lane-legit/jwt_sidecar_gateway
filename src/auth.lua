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
     local placeholders = {}
    for key, value in pairs(payload) do
        if type(value) ~= "table" then
            placeholders["jwt." .. key] = value
        end
    end

    local roles = payload["access"]["roles"]
    ngx.log(ngx.WARN, "User roles: " .. inspect(roles))

--     this can be replaced with the logic where we get the AUTHZ CONFIG from REDIS instead.
    if not authz_config then
        ngx.log(ngx.WARN,"Authorization config is not defined")
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local authorization_rules = json.decode(authz_config)
    local matched = false

    for _, rule_value in ipairs(authorization_rules) do
        if matched then
            break
        end

        local role_matched = false
        if rule_value["role"] then
            for _, value in ipairs(roles) do
                ngx.log(ngx.WARN, "Checking role: " .. value .. " against: " .. rule_value["role"])
                if value ==  rule_value["role"] then
                    role_matched = true
                    break
                end
            end
        end

        if not rule_value["role"] or role_matched then
            for _, permission_value in ipairs(rule_value["permissions"]) do
                local permission_url = permission_value["url"]
                local url = string.gsub(permission_url, "%${(.-)}", function(w) return placeholders[w] end)
                local pattern = globtopattern(url)
                local result = string.match(current_url, pattern)

                if result == current_url then
                    matched = true
                    if permission_value["deny"] then
                        ngx.log(ngx.WARN, "Authorization failed: Permission denied")
                        ngx.log(ngx.WARN, "Token: " .. token)
                        ngx.exit(ngx.HTTP_FORBIDDEN)
                    end

                    if permission_value["method"] then
                        local method_matched = false
                        for method_key, method_value in pairs(permission_value["method"]) do
                            if method_value == ngx.var.request_method then
                                method_matched = true
                                break
                            end
                        end

                        if not method_matched then
                            ngx.log(ngx.WARN, "Authorization failed: Verb not allowed")
                            ngx.log(ngx.WARN, "Token: " .. token)
                            ngx.exit(ngx.HTTP_FORBIDDEN)
                        end
                    end
                    break
                end
            end
        end
    end

    if matched == false then
        ngx.log(ngx.WARN, "Authorization failed: No permission rule matched the request")
        ngx.log(ngx.WARN, "Token: " .. token)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    ngx.req.set_header("X-Auth-Tenant", payload["instance"])
    ngx.req.set_header("X-Auth-Role", payload["role"])

end

