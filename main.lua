local http = require "http"
local markup = require "markup"

local html = markup.html

local head = { 
  markup.link {
    rel = "stylesheet",
    href = "https://unpkg.com/normalize.css@8.0.1/normalize.css"
  },
  markup.link { 
    rel = "stylesheet",
    href = "https://unpkg.com/concrete.css@2.1.1/concrete.css"
  },
  markup.script {
    src = "https://unpkg.com/htmx.org@1.9.11"
  }
}

-- message board thread
local threads = {
  gaming = {
    { author = "player1", message = "hello world" },
    { author = "player2", message = "hello player1" },
  },
  programming = {},
}

http
  :handle("GET /", function()
    return html {
      title = "plum board",
      head = head,
      body = [[
      <main>
        <h1>welcome to plum board</h1>
        <p>threads:</p>
        <ul>
          <li><a href="/gaming">gaming</a></li>
          <li><a href="/programming">programming</a></li>
        </ul>
      </main>
      ]]
    }
  end)
  :handle("GET /(%w+)", function(request, name)
    local messages = threads[name]

    if not messages then
      return html {
        title = "plum board",
        body = markup.main {
          markup.p { "thread not found" }
        }
      }
    end

    return html {
      title = name,
      head = head,
      body = markup.main {
        markup.h1 { "thread: " .. name },
        markup.form {
          ["hx-post"] = "/" .. name,
          ["hx-target"] = "ul",
          ["hx-swap"] = "afterbegin",
          markup.input { type = "text", name = "author", placeholder = "author" },
          markup.textarea { name = "message", placeholder = "message" },
          markup.button { type = "submit", "post" }
        },
        markup.ul {
          markup.each {
            data = messages,
            template = markup.li {
              markup.p { "author: $author" },
              markup.p { "$message" }
            }
          }
        }
      }
    }
  end)
  :handle("POST /(%w+)", function(request, name)
    local author, message = request.body:match("author=(.*)&message=(.*)")

    if not author or not message then
      return { status = 400, body = "bad request" }
    end

    local messages = threads[name]

    if not messages then
      return html {
        title = "plum board",
        body = markup.main {
          markup.p { "thread not found" }
        }
      }
    end

    messages[#messages + 1] = { author = author, message = message }

    return markup.li {
      markup.p { "author: " .. author },
      markup.p { message }
    }:render()
  end)
  :listen(3000)
