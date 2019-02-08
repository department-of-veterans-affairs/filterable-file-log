-- Modified from https://github.com/Kong/kong/blob/0.14.1/kong/plugins/file-log/schema.lua
local Errors = require "kong.dao.errors"
local pl_file = require "pl.file"
local pl_path = require "pl.path"

local function validate_file(value)
  -- create file in case it doesn't exist
  if not pl_path.exists(value) then
    local ok, err = pl_file.write(value, "")
    if not ok then
      return false, string.format("Cannot create file: %s", err)
    end
  end

  return true
end

return {
  fields = {
    path = { required = true, type = "string", func = validate_file },
    reopen = { type = "boolean", default = false },
    request_headers_whitelist = { type = "array" },
    request_headers_blacklist = { type = "array" },
    response_headers_whitelist = { type = "array" },
    response_headers_blacklist = { type = "array" },
    query_params_blacklist = { type = "array" },
    query_params_whitelist = { type = "array" }
  },
  self_check = function(schema, config, dao, is_updating)
    for _, field in ipairs({"request_headers", "response_headers", "query_params"})
      if config[field .. "_whitelist"] and config[field .. "_blacklist"] then
        return false, Errors.schema "You cannot set both a whitelist and a blacklist for " .. field
      end
    end
    return true
  end
}
