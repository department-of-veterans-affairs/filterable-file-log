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
  entity_checks = {
    { only_one_of = { "request_headers_whitelist", "request_headers_blacklist" } },
    { only_one_of = { "response_headers_whitelist", "response_headers_blacklist" } },
    { only_one_of = { "query_params_whitelist", "query_params_blacklist" } }
  }
}
