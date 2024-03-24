--
-- http.lua
--
-- MIT License
--
-- Copyright (c) 2022 brennop
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local socket = require "socket"

local http = { handlers = { } }

local SEND_SIZE = 32

local messages = {
  [200] = "OK",
  [404] = "Not Found",
  [500] = "Internal Server Error",
}

local function match_handler(pattern)
  for key, handler in pairs(http.handlers) do
    local path, query = pattern:match("([^%?]+)%?(.*)$")
    local match = (path or pattern):match(key .. "$")
    if match then
      local params = { }
      if query then
        for k, v in query:gmatch("([^=&]+)=([^=&]+)") do
          if v == "false" then v = false
          elseif v == "true" then v = true
          elseif tonumber(v) then v = tonumber(v) end
          params[k] = v
        end
      end
      return handler(params, match)
    end
  end

  return { status = 404, body = "Not Found" }
end

local function serialize(data)
  local message = messages[data.status] or "Unknown"

  local headers = {
    "Content-Length: " .. #data.body,
    "Connection: close",
  }

  local response = {
    "HTTP/1.1 " .. data.status .. " " .. message,
    table.concat(headers, "\r\n") .. table.concat(data.headers or {}, "\r\n"),
    "",
    data.body,
  }

  return table.concat(response, "\r\n")
end

local index = 1
local function handle_client(client)
  local time = socket.gettime()
  local id = index

  index = index + 1

  local pattern, version = 
    client:receive():match("(%u+%s[%p%w]+)%s(HTTP/1.1)")

  coroutine.yield()

  -- ignore headers for now
  for line in function() client:receive() end do end

  coroutine.yield()

  local data = match_handler(pattern)

  local response = ""

  if type(data) == "table" then
    response = serialize(data)
  else
    response = serialize({ status = 200, body = data })
  end

  for i = 1, #response, SEND_SIZE do
    coroutine.yield()
    client:send(response:sub(i, i + SEND_SIZE - 1))
  end

  print("Request took " .. (socket.gettime() - time) .. " seconds")

  client:close()
end

local coroutines = { }

function http.listen(port)
  local server, port = nil, port or 3000

  while not server do
    server = socket.bind("*", port)
    port = port + 1
  end

  print("Server listening on port " .. port - 1)

  server:settimeout(0)

  while true do
    local client = server:accept()

    if client then
      -- add to coroutines
      local co = coroutine.create(handle_client)

      -- start coroutine
      coroutine.resume(co, client)

      -- enqueue coroutine
      table.insert(coroutines, co)
      -- while coroutine.status(co) ~= "dead" do
      --   coroutine.resume(co)
      -- end
    end

    -- pop coroutine
    local co = table.remove(coroutines, 1)
    if co then
      coroutine.resume(co)

      -- check if coroutine is done
      if coroutine.status(co) ~= "dead" then
        table.insert(coroutines, co)
      end
    end

    -- client:settimeout(5)
    -- local ok, err = pcall(handle_client, client)

    -- if not ok then
    --   -- TODO: log errors
    --   client:send(serialize({ status = 500, body = err }))
    -- end

    -- client:close()
  end
end

function http.get(pattern, handler)
  http.handlers["GET " .. pattern] = handler
  return http
end

return http
