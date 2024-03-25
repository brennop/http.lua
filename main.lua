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
}

local function each(tbl, fn)
  local results = {}
  for i, v in ipairs(tbl) do
    results[i] = fn(v)
  end
  return table.concat(results)
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
  :handle("GET /(%w+)", function(req, name)
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

    return html {
      title = name,
      head = head,
      body = [[
      <main>
        <h1>thread: ]] .. name .. [[</h1>
        <form method="POST" action="/]] .. name .. [[">
          <input type="text" name="author" placeholder="author">
          <textarea name="message" placeholder="message"></textarea>
          <button type="submit">post</button>
        </form>
        <ul>
          ]] .. each(messages, function(message)
            return [[
            <li>
              <p>author: ]] .. message.author .. [[</p>
              <p>]] .. message.message .. [[</p>
            </li>
            ]]
          end) .. [[
        </ul>
      ]]
    }
  end)
  :listen(3000)
