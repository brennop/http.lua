local http = require "http"

http
  :handle("GET /", function()
    return ""
  end)
  :handle("GET /(%w+)", function(req, name)
    return "hello " .. name
  end)
  :listen(3000)
