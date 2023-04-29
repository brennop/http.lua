# http.lua

A tiny (<100sloc) http server

## Usage

Drop in a project and require it

`local http = require "http"`

#### http.get(pattern, handler)

`http.get("/", function() return "Hello World" end)`

Register a GET handler, Where pattern is a lua pattern match, and handler is a
function that returns either a message, or a table with a status and a body.

#### http.listen(port)

`http.listen(3000)`

Starts the http server listening on port (default is 3000)

## Example

```lua
local http = require "server"

http
  .get("/", function()
    return "hello world"
  end)
  .get("/(%w+)", function(req, name)
    return "hello " .. name
  end)
  .listen(3000)
```
