local http = require "server"

http
  .get("/", function()
    return "hello world"
  end)
  .get("/(%w+)", function(req, name)
    return "hello " .. name
  end)
  .listen(3000)
