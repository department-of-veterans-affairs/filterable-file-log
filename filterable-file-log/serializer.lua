-- Modified from https://github.com/Kong/kong/blob/0.14.1/kong/plugins/log-serializers/basic.lua
local tablex = require "pl.tablex"
local list = require "pl.List"
local stringx = require "pl.stringx"
local cjson = require "cjson.safe"

local _M = {}

local EMPTY = tablex.readonly({})

function _M.serialize(ngx, filters)
  local authenticated_entity
  if ngx.ctx.authenticated_credential ~= nil then
    authenticated_entity = {
      id = ngx.ctx.authenticated_credential.id,
      consumer_id = ngx.ctx.authenticated_credential.consumer_id
    }
  end

  local request_uri = ngx.var.request_uri or ""

  local req_headers = ngx.req.get_headers()
  local jwt_claims = get_jwt_claims(req_headers)
  
  local error_message
  if type(cjson.decode(ngx.var.resp_body)) ~= "nil" then
    local og_message = cjson.decode(ngx.var.resp_body).message
    if og_message then
      error_message = convert_error_message(og_message)
    end
  end

  if filters.request_headers_blacklist then
    req_headers = blacklist_filter(req_headers, filters.request_headers_blacklist)
  elseif filters.request_headers_whitelist then
    req_headers = whitelist_filter(req_headers, filters.request_headers_whitelist)
  end

  resp_headers = ngx.resp.get_headers()
  if filters.response_headers_blacklist then
    resp_headers = blacklist_filter(resp_headers, filters.response_headers_blacklist)
  elseif filters.response_headers_whitelist then
    resp_headers = whitelist_filter(resp_headers, filters.response_headers_whitelist)
  end

  return {
    request = {
      uri = request_uri,
      url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. request_uri,
      querystring = query_params, -- parameters, as a table
      method = ngx.req.get_method(), -- http method
      headers = req_headers,
      size = ngx.var.request_length
    },
    upstream_uri = ngx.var.upstream_uri,
    response = {
      status = ngx.status,
      headers = resp_headers,
      size = ngx.var.bytes_sent
    },
    tries = (ngx.ctx.balancer_data or EMPTY).tries,
    latencies = {
      kong = (ngx.ctx.KONG_ACCESS_TIME or 0) +
             (ngx.ctx.KONG_RECEIVE_TIME or 0) +
             (ngx.ctx.KONG_REWRITE_TIME or 0) +
             (ngx.ctx.KONG_BALANCER_TIME or 0),
      proxy = ngx.ctx.KONG_WAITING_TIME or -1,
      request = ngx.var.request_time * 1000
    },
    err_message = error_message,
    authenticated_entity = authenticated_entity,
    route = ngx.ctx.route,
    service = ngx.ctx.service,
    api = ngx.ctx.api,
    consumer = ngx.ctx.authenticated_consumer,
    jwt_claims = jwt_claims,
    client_ip = ngx.var.remote_addr,
    started_at = ngx.req.start_time() * 1000
  }
end

function get_jwt_claims(headers)
  if not headers['authorization'] then
    return nil
  end

  -- The JWT consists of 2-3 period-delimited, base64 encoded sections (signature is optional):
  --   header.payload.[signature]
  -- The claims we're interested in are in the payload, so we capture the second base64 encoded string
  local encoded_claims = string.match(headers['authorization'], 'Bearer [%w/+]+=?=?%.([%w/+]+=?=?)%.')
  if not encoded_claims then
    return nil
  end

  local claims = ngx.decode_base64(encoded_claims)
  if not claims then
    return nil
  end

  local parsed_claims, err = cjson.decode(claims)
  if err then
    return nil
  end

  -- only log a subset of claims to avoid logging PII/PHI
  return whitelist_filter(parsed_claims, {
    'cid',
    'exp',
    'iat',
    'iss',
    'jti',
    'scp'
  })
end

function blacklist_filter(t, blacklist)
  blacklist = list(blacklist):map(string.lower)
  return tablex.pairmap(function(k,v)
    if blacklist:contains(k:lower()) then
      v = "FILTERED"
    end
    return v, k
  end, t)
end

function whitelist_filter(t, whitelist)
  whitelist = list(whitelist):map(string.lower)
  return tablex.pairmap(function(k,v)
    if not whitelist:contains(k:lower()) then
      v = "FILTERED"
    end
    return v, k
  end, t)
end

function convert_error_message(msg)
  local e
  if string.find(msg, "No API key") then
    e = "No Key"
  elseif string.find(msg, "Invalid authentication") then
    e = "Invalid Key"
  elseif string.find(msg, "IP address is not allowed") then
    e = "IP Blocked"
  elseif string.find(msg, "no Route") then
    e = "Invalid Route"
  else
    e = ""
  end
  return e
end

return _M
