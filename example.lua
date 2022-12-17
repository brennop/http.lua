local http = require "server"
local markup = require "markup"

local html, div, p, a, style = markup.html, markup.div, markup.p, markup.a, markup.style

local head = {
  style [[
    body {
      background-color: #eee;
      color: #333;
      font-family: monospace;
    }
  ]],
}

http
  .get("/", function()
    return html {
      head = head,
      title = "Hello, world!",
      body = div {
        p "Hello, world!",
        a { href = "/about", "About" }
      }
    }
  end)
  .get("/(%w+)", function(req, name)
    return html {
      title = name,
      head = head,
      body = div {
        p { "Hello, " .. name .. "!" },
        a { href = "/", "Home" },
      }
    }
  end)
  .listen(3000)
