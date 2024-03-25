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
local parser = require "parser"

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

  local parse = coroutine.create(parser)
  local request = nil

  while true do
    local data, err, partial = client:receive(128)

    -- TODO: handle errors

    local ok, result = coroutine.resume(parse, data or partial)

    if result then
      request = result
      break
    end

    coroutine.yield()
  end

  self:remove_socket(client, self.rindexes, self.recvt)

  self.sendt[#self.sendt + 1] = client

  -- save index to remove later
  self.sindexes[tostring(client)] = #self.sendt

  -- save handler to run later
  self.senders[tostring(client)] = coroutine.create(function() self:send(client, request) end)
end

function http:send(client, request)
  local data = self:match_handler(request.pattern)

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

  self:remove_socket(client, self.sindexes, self.sendt)
end

function http:remove_socket(socket, indexes, list)
  local index = indexes[tostring(socket)]
  local last = #list
  list[index] = list[last]
  list[last] = nil
  indexes[tostring(list[index])] = index
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

          self.recvt[#self.recvt + 1] = client

          -- save index to remove later
          self.rindexes[tostring(client)] = #self.recvt

          -- save handler to run later
          self.receivers[tostring(client)] = coroutine.create(function() self:receive(client) end)
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
