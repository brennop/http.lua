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

local function each(tbl, fn)
  local results = {}
  for i, v in ipairs(tbl) do
    results[i] = fn(v)
  end
  return table.concat(results)
end

local function messageMarkup(message)
  local template = [[
    <li>
      <p>author: %s</p>
      <p>%s</p>
    </li>
  ]]

  return template:format(message.author, message.message)
end

local function thread(name, messages)
  return html {
    title = name,
    head = head,
    body = string.format([[
      <main>
        <h1>thread: %s</h1>
        <form hx-post="/%s" hx-target="ul" hx-swap="afterbegin">
          <input type="text" name="author" placeholder="author">
          <textarea name="message" placeholder="message"></textarea>
          <button type="submit">post</button>
        </form>
        <ul>
          %s
        </ul>
      ]], name, name, each(messages, messageMarkup))
  }
end

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
        body = [[
        <main>
          <p>thread not found</p>
        </main>
        ]]
      }
    end

    return thread(name, messages)
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
        body = [[
        <main>
          <p>thread not found</p>
        </main>
        ]]
      }
    end

    messages[#messages + 1] = { author = author, message = message }

    return messageMarkup { author = author, message = message }
  end)
  :listen(3000)
