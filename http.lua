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

function http:match_handler(pattern)
  for key, handler in pairs(self.handlers) do
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

function http:receive(client)
  local buffer = ""

  while true do
    local data, err, partial = client:receive(8)

    if data then
      buffer = buffer .. data
    elseif err == "closed" then
      break
    elseif err == "timeout" then
      buffer = buffer .. partial
    end

    if buffer:sub(-4) == "\r\n\r\n" then
      break
    end

    -- FIXME: we could yield the buffer to the consumer coroutine
    -- and start handling the request before the whole buffer is
    -- received
    coroutine.yield()
  end

  table.insert(self.sendt, client)

  -- swap the socket with the last one
  local index = self.rindexes[tostring(client)]
  local last = #self.recvt
  self.recvt[index] = self.recvt[last]
  self.recvt[last] = nil
  self.rindexes[tostring(self.recvt[index])] = index

  -- create a new coroutine to handle the request
  local handler = coroutine.create(function() self:send(client, buffer) end)

  -- save index to remove later
  self.sindexes[tostring(client)] = #self.sendt

  -- save handler to run later
  self.senders[tostring(client)] = handler
end

function http:send(client, buffer)
  print(buffer)
  local pattern, version = 
      buffer:match("(%u+%s[%p%w]+)%s(HTTP/1.1)\r\n")

  local data = self:match_handler(pattern)

  local response = ""

  if type(data) == "table" then
    response = serialize(data)
  else
    response = serialize({ status = 200, body = data })
  end

  for i = 1, #response, SEND_SIZE do
    client:send(response:sub(i, i + SEND_SIZE - 1))
    coroutine.yield()
  end

  client:close()

  -- swap the socket with the last one
  local index = self.sindexes[tostring(client)]
  local last = #self.sendt
  self.sendt[index] = self.sendt[last]
  self.sendt[last] = nil
  self.sindexes[tostring(self.sendt[index])] = index
end

function http:listen(port)
  local server, port = nil, port or 3000

  while not server do
    server = socket.bind("*", port)
    port = port + 1
  end

  server:settimeout(0)
  print("Server listening on port " .. port - 1)

  -- list of sockets for socket.select
  self.recvt = { server }
  self.sendt = { }

  -- coroutines
  self.receivers = { }
  self.senders = { }

  -- map ids to sockets
  self.rindexes = { }
  self.sindexes = { }

  while true do
	  local readable, writable, err = socket.select(self.recvt, self.sendt, 0)

    -- handle readable sockets
    for _, socket in ipairs(readable) do
      if socket == server then
        local client, err = server:accept()

        if client then
          client:settimeout(0)

          local index = #self.recvt + 1
          self.recvt[index] = client

          local handler = coroutine.create(function() self:receive(client) end)

          -- save index to remove later
          self.rindexes[tostring(client)] = index

          -- save handler to run later
          self.receivers[tostring(client)] = handler
        end
      else
        -- socket is a client ready to be read
        local handler = self.receivers[tostring(socket)]

        -- TODO: check if is necessary
        if handler == nil then break end

        local ok, err = coroutine.resume(handler)

        -- TODO: handle errors
        if not ok then
          error("recv Error: "..err)
        end

        if coroutine.status(handler) == "dead" then
          self.receivers[tostring(socket)] = nil
        end
      end
    end

    -- handle writable sockets
    for _, socket in ipairs(writable) do
      local handler = self.senders[tostring(socket)]

      local ok, err = coroutine.resume(handler)

      if not ok then
        error("sending Error: "..err)
      end

      if coroutine.status(handler) == "dead" then
        self.senders[tostring(socket)] = nil
      end
    end
  end
end

function http:handle(pattern, handler)
  self.handlers[pattern] = handler
  return self
end

return http
