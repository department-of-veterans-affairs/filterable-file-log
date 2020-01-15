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

  if filters.request_headers_blacklist then
    req_headers = blacklist_filter(req_headers, filters.request_headers_blacklist)
  elseif filters.request_headers_whitelist then
    req_headers = whitelist_filter(req_headers, filters.request_headers_whitelist, "FILTERED")
  end

  resp_headers = ngx.resp.get_headers()
  if filters.response_headers_blacklist then
    resp_headers = blacklist_filter(resp_headers, filters.response_headers_blacklist)
  elseif filters.response_headers_whitelist then
    resp_headers = whitelist_filter(resp_headers, filters.response_headers_whitelist, "FILTERED")
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

  local token = string.match(headers['authorization'], 'Bearer (.+)')
  if not token then
    return nil
  end

  -- The JWT has three .-delimited parts: header, payload, and signature
  -- The payload has the claims we're interested in
  local encoded_claims = stringx.split(token, '.')[2]
  if not encoded_claims then
    return nil
  end

  local claims = ngx.decode_base64(encoded_claims)
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

function whitelist_filter(t, whitelist, replacement)
  whitelist = list(whitelist):map(string.lower)
  return tablex.pairmap(function(k,v)
    if not whitelist:contains(k:lower()) then
      v = replacement
    end
    return v, k
  end, t)
end

return _M
