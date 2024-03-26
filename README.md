# http.lua

A tiny (~150sloc) http server

## Usage

Drop in a project and require it

```lua
local http = require "http"
```

#### http:handle(pattern, handler)

`http:handle("GET /", function() return "Hello World!" end)`

Register a GET handler, Where pattern is a lua pattern match, and handler is a
function that returns either a message, or a table with a status and a body.

#### http:listen(port)

`http:listen(3000)`

Starts the http server listening on port (default is 3000)

## Example

```lua
local http = require "http"

http
  :handle("GET /", function()
    return "hello world"
  end)
  :handle("GET /(%w+)", function(request, name)
    return "hello " .. name
  end)
  :listen(3000)
```
