local http = require "server"
local markup = require "markup"

local html, div, p = markup.html, markup.div, markup.p

http.get("/(%w+)", function(req, name)
  return html {
    title = "Hello",
    head = {},
    body = div {
      p { "Hello, " .. name .. "!" }
    }
  }
end)

http.listen(8080)
