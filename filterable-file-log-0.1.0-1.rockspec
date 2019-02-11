package = "filterable-file-log"
version = "0.1.0-1"
source = {
   url = "git://github.com/department-of-veterans-affairs/filterable-file-log",
}
description = {
   summary = "A fork of the official kong file log plugin that supports filtering sensitive data"
}
dependencies = {
  "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.filterable-file-log.handler"] = "filterable-file-log/handler.lua",
      ["kong.plugins.filterable-file-log.schema"] = "filterable-file-log/schema.lua",
      ["kong.plugins.filterable-file-log.serializer"] = "filterable-file-log/serializer.lua"
   }
}
