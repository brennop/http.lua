local http = require "http"

http
  .get("/", function()
    return ""
  end)
  .get("/(%w+)", function(req, name)
    return "hello " .. name
  end)
  .listen(3000)
