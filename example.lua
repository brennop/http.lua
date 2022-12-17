local http = require "http"
local markup = require "markup"

local html, div, p = markup.html, markup.div, markup.p

http.get("/(%w+)", function(req, name)
  return html("Hello", div { 
    class = "container",
    p { "Hello, " .. name .. "!" }
  })
end)

http.listen(8080)
