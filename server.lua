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

local messages = {
  [200] = "OK",
  [404] = "Not Found",
  [500] = "Internal Server Error",
}

local function match_handler(pattern)
  for key, handler in pairs(http.handlers) do
    local match = pattern:match(key .. "$")
    if match then
      return handler({}, match)
    end
  end

  return { status = 404, body = "Not Found" }
end

local function serialize(status, body)
  local message = messages[status] or "Unknown"

  local headers = {
    "Content-Length: " .. #body,
    "Connection: keep-alive",
    "Keep-Alive: timeout=5",
  }

  local response = {
    "HTTP/1.1 " .. status .. " " .. message,
    table.concat(headers, "\r\n"),
    "",
    body,
  }

  return table.concat(response, "\r\n")
end

local function handle_client(client)
  local line = client:receive()

  if not line then
    return
  end

  local pattern, version = line:match("(%u+%s[%p%w]+)%s(HTTP/1.1)")

  -- ignore headers for now
  for line in function() 
    local line = client:receive() 
    if line == "" then
      return nil
    end
    return line
  end do 
  end

  local data = match_handler(pattern)

  local response = ""

  if type(data) == "table" then
    response = serialize(data.status, data.body or "")
  else
    response = serialize(200, data)
  end

  client:send(response)
  return true
end

local function wrapper(client)
  while true do
    client:settimeout(5)
    local success, data = pcall(handle_client, client)

    print(data)

    if not success then
      client:send(serialize(500, data))
    end

    if not data then
      return
    end
  end
end

function http.listen(port)
  local server = socket.bind("*", port or 3000)

  while true do
    local client = server:accept()
    coroutine.wrap(wrapper)(client)
  end

  print("Server listening on port " .. port)
end

function http.get(pattern, handler)
  http.handlers["GET " .. pattern] = handler
  return http
end

return http
