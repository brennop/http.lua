#!/usr/bin/env luajit

local socket = require "socket"
local kqueue = require "kqueue"

local EVFILT_READ = -1
local EVFILT_WRITE = -2
local EV_EOF = 0x8000

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

local server = socket.bind("*", 3000, 128)
local server_fd = server:getfd()
server:settimeout(0)

kqueue:setup(server_fd)

local clients = {}

local function parser(data)
  local headers, pattern, version, rest, body = {}

  -- parse request line
  while pattern == nil do
    pattern, version, rest = data:match "(%u+%s[%p%w]+)%s(HTTP/1.1)\r\n(.*)"

    data = rest or (data .. coroutine.yield())
  end

  local path, query_string = pattern:match "([^%?]+)%?(.*)$"
  -- local query = decode_query(query_string)

  -- parse headers
  while not data:match "^\r\n(.*)" do
    local key, value, rest = data:match "([%w%-]+):%s([%p%w]+)\r\n(.*)"

    if key then headers[key] = value end
    
    -- if rest is nil, then we don't have enough data. yield control and wait
    -- till more data is read
    data = rest or (data .. coroutine.yield())
  end

  -- parse body
  if headers["Content-Length"] then
    local length = tonumber(headers["Content-Length"])

    print(length)

    while #data - 2 < length do data = data .. coroutine.yield() end

    body = data:sub(3, length + 2)

    if headers["Content-Type"] == "application/x-www-form-urlencoded" then
      body = decode_query(body)
    end
  end

  return { pattern = pattern, version = version, headers = headers, body = body, query = query, path = path }
end

local function try_parse(client, parse)
  local data, err, partial = client:receive(8192) -- This is to match luasockets bufsize

  -- TODO: handle errors

  local result = parse(data or partial)

  if result then return result end

  coroutine.yield()

  return try_parse(client, parse)
end

local function serialize(data)
  if type(data) == "string" then 
    data = { status = 200, body = data }
  end

  local message = messages[data.status] or "Unknown"

  local headers = {
    "Content-Length: " .. #data.body,
    "Connection: keep-alive",
  }

  local response = {
    "HTTP/1.1 " .. data.status .. " " .. message,
    table.concat(headers, "\r\n") .. table.concat(data.headers or {}, "\r\n"),
    "",
    data.body,
  }

  return table.concat(response, "\r\n")
end

local function receive(client)
  while true do
    local request = try_parse(client, parser)
    local data = serialize("hello world")
    client:send(data)
    coroutine.yield()
  end
end


while true do
  local events = kqueue:poll() -- convert in a kqueue:loop call
  for i = 0, events - 1 do
    local event = kqueue.event_list[i]
    local fd = tonumber(event.ident)
    local client = clients[fd] -- { Client, Coroutine } | nil

    if fd == server_fd then
      local sock = server:accept()

      if sock then
        sock:settimeout(0)
        kqueue:add(sock:getfd())

        local co = coroutine.create(function() receive(sock) end)

        clients[sock:getfd()] = { sock = sock, co = co }
      end

    elseif bit.band(event.flags, EV_EOF) > 0 then
      client.sock:close()
      kqueue:del(event.ident)
      clients[fd] = nil
    elseif event.filter == EVFILT_READ then
      local ok, err = coroutine.resume(client.co)

      -- if coroutine.status(client.co) == "dead" then
      --   local data = serialize("hello world")
      --   client.sock:send(data)
      --   client.co = coroutine.create(function() receive(client.sock) end)
      -- end
    elseif event.filter == EVFILT_WRITE then
      print("TODO: handle write")
    end
  end
end

