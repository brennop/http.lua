-- local http = require "http"

-- http
--   .get("/", function()
--     return ""
--   end)
--   .get("/(%w+)", function(req, name)
--     return "hello " .. name
--   end)
--   .listen(3000)

local socket = require "socket"

local server = socket.bind("*", 3000)
server:settimeout(0)

local SEND_SIZE = 32

local sockets = { server }
local sockets2 = {}
local handlers = {}
local senders = {}

local messages = {
  [200] = "OK",
  [404] = "Not Found",
  [500] = "Internal Server Error",
}

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

local function handle_client(client, client_index)
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

    coroutine.yield()
  end

  table.insert(sockets2, client)

  local send = coroutine.create(function()
    local response = serialize({ status = 200, body = "Hello World" })

    for i = 1, #response, SEND_SIZE do
      client:send(response:sub(i, i + SEND_SIZE - 1))
      coroutine.yield()
    end

    client:close()

    -- find client in sockets
    for i, socket in ipairs(sockets) do
      if socket == client then
        table.remove(sockets, i)
        break
      end
    end

    -- find client in sockets2
    for i, socket in ipairs(sockets2) do
      if socket == client then
        table.remove(sockets2, i)
        break
      end
    end
  end)

  senders[tostring(client)] = send
end

local max = -1
while true do
  local time = socket.gettime()
	local readable, writable, err = socket.select(sockets, sockets2, 0)

	for i, socket in ipairs(readable) do
		if socket == server then
			local client, err = server:accept()

			if client then
				client:settimeout(0)

        local index = #sockets + 1
        sockets[index] = client

        local handler = coroutine.create(function()
          handle_client(client, index)
        end)

        handlers[tostring(client)] = handler
			end
		else
      local handler = handlers[tostring(socket)]

      if handler == nil then
        break
      end

      local ok, err = coroutine.resume(handler)

      if not ok then
        print("recv Error: "..err)
      end

      if coroutine.status(handler) == "dead" then
        handlers[tostring(socket)] = nil
      end
		end
	end

  for i, socket in ipairs(writable) do
    local send = senders[tostring(socket)]

    local ok, err = coroutine.resume(send)

    if not ok then
      print("sending Error: "..err)
    end

    if coroutine.status(send) == "dead" then
      senders[tostring(socket)] = nil
      -- print("removing socket " .. err)
      -- table.remove(sockets2, err)
    end
  end
end
