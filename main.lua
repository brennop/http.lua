local http = require "http"
local markup = require "markup"

local function write(data, file)
  if type(data) == "number" then 
    file:write(data)
  elseif type(data) == "string" then
    file:write(string.format("%q", data))
  elseif type(data) == "table" then
    file:write("{")
    for k, v in pairs(data) do
      if type(k) == "number" then
        file:write("[", k, "] = ")
      else
        file:write(k, " = ")
      end
      write(v, file)
      file:write(", ")
    end
    file:write("}")
  end
end

local function open(name)
  local file = io.open(name, "r")
  if not file then
    return {}
  end
  local data = file:read "*a"
  local ok, result = pcall(loadstring("return " .. data))
  return ok and result or {}
end

local threads = open("/tmp/db")

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

http
  :handle("GET /", function()
    return html {
      title = "plum board",
      head = head,
      body = markup.main {
        markup.h1 { "welcome to plum board" },
        markup.p { "threads:" },
        markup.ul {
          ["hx-boost"] = "true",
          markup.each {
            data = threads,
            template = markup.li {
              markup.a { href = "/$key", "$key" }
            }
          }
        }
      }
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
  -- Handle new post
  :handle("POST /(%w+)", function(request, name)
    local author, message = request.body.author, request.body.message
    local timestamp = os.time()

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

    write(threads, io.open("/tmp/db", "w"))

    return markup.li {
      markup.p { "author: " .. author },
      markup.p { message }
    }:render()
  end)
  :listen(3000)
