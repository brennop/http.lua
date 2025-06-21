--
-- http.lua
--
-- MIT License
--
-- Copyright (c) 2025 brennop
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
local RECV_SIZE = 32
local MAX_ACCEPTS = 16
local MAX_CLIENTS = 16

local messages = {
  [200] = "OK",
  [404] = "Not Found",
  [500] = "Internal Server Error",
}

local function decode_query(query)
  if query == nil then return {} end

  local form = {}

  for key, value in query:gmatch "([^&]+)=([^&]+)" do
    form[key] = value:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
  end

  return form
end

function http:match_handler(request)
  for key, handler in pairs(self.handlers) do
    local match = (request.path or request.pattern):match(key .. "$")
    if match then return handler(request, match) end
  end

  return { status = 404, body = "Not Found" }
end

function parser(data)
  local headers, pattern, version, rest, body = {}

  -- parse request line
  while pattern == nil do
    pattern, version, rest = data:match "(%u+%s[%p%w]+)%s(HTTP/1.1)\r\n(.*)"

    data = rest or (data .. coroutine.yield())
  end

  local path, query_string = pattern:match "([^%?]+)%?(.*)$"
  local query = decode_query(query_string)

  -- parse headers
  while not data:match "^\r\n(.*)" do
    local key, value, rest = data:match "([%w%-]+):%s([%p%w]+)\r\n(.*)"

    if key then headers[key] = value end

    data = rest or (data .. coroutine.yield())
  end

  -- parse body
  if headers["Content-Length"] then
    local length = tonumber(headers["Content-Length"])

    while #data - 2 < length do
      data = data .. coroutine.yield()
    end

    body = data:sub(3, length + 2)

    if headers["Content-Type"] == "application/x-www-form-urlencoded" then
      body = decode_query(body)
    end
  end

  return { pattern = pattern, version = version, headers = headers, body = body, query = query, path = path }
end

local function serialize(data)
  if type(data) == "string" then 
    data = { status = 200, body = data }
  end

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

local function try_parse(client, parse)
  local data, err, partial = client:receive(RECV_SIZE)

  -- TODO: handle errors

  local result = parse(data or partial)

  if result then return result end

  coroutine.yield()

  return try_parse(client, parse)
end

function http:receive(client)
  local request = try_parse(client, coroutine.wrap(parser))

  self.senders[client] = coroutine.create(function() self:send(client, request) end)
end

function http:send(client, request)
  local data = self:match_handler(request)

  local response = serialize(data)

  for i = 1, #response, SEND_SIZE do
    client:send(response:sub(i, i + SEND_SIZE - 1))
    coroutine.yield()
  end

  client:close()
end

function try_bind(port)
  local server = socket.bind("*", port, 128)
  if server then return server, port end
  return try_bind(port + 1)
end

function http:listen(port)
  local server, port = try_bind(port)

  server:settimeout(0)
  print("Server listening on port " .. port)

  -- coroutines
  self.receivers = { }
  self.senders = { }

  while true do
    local read_set = { server }
    local write_set = { }

    for sock, _ in pairs(self.receivers) do read_set[#read_set + 1] = sock end -- everything in p
    for sock, _ in pairs(self.senders) do write_set[#write_set + 1] = sock end -- erfect balanace

    local readable, writable, err = socket.select(read_set, write_set)

    for i = 1, MAX_ACCEPTS do
      local client, err = server:accept()

      if not client then break end

      client:settimeout(0)

      -- save handler to run later
      self.receivers[client] = coroutine.create(function() self:receive(client) end)
    end

    local resumed = 0
    -- handle readable sockets
    for _, socket in ipairs(readable) do
      if resumed > MAX_CLIENTS then break end

      if socket ~= server then
        resumed = resumed + 1

        -- socket is a client ready to be read
        local handler = self.receivers[socket]

        local ok, err = coroutine.resume(handler)

        if not ok then
          error("recv Error: "..err)
        elseif coroutine.status(handler) == "dead" then
          self.receivers[socket] = nil
        end
      end
    end

    local resumed = 0
    -- handle writable sockets
    for _, socket in ipairs(writable) do
      if resumed > MAX_CLIENTS then break end

      resumed = resumed + 1

      local handler = self.senders[socket]

      local ok, err = coroutine.resume(handler)

      if not ok then
        error("sending Error: "..err)
      elseif coroutine.status(handler) == "dead" then
        self.senders[socket] = nil
      end
    end
  end
end

function http:handle(pattern, handler)
  self.handlers[pattern] = handler
  return self
end

return http
