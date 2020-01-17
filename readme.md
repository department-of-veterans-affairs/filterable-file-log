# Filterable File Log
A fork of the official [Kong file log plugin](https://github.com/Kong/kong/tree/0.14.1/kong/plugins/file-log) that supports filtering fields from the log.

This plugin also logs a subset of claims from a JWT that is presented in an `Authorization: Bearer` header. This behavior is not configurable, and the claims logged are hardcoded.

## Compatibility
This plugin is forked from Kong 0.14.1, but supports Kong 1.x.

## Local Development

The docker-compose.yml in this repo will automatically mount and install the local plugin when you run `docker-compose up`. It also includes konga for easy configuration, which can be accessed at http://localhost:1337. Code changes to the plugin will be visible after running `docker-compose exec kong kong reload`.
