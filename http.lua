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

  return { status = 404, body = "" }
end

local function serialize(status, body)
  local message = messages[status] or "Unknown"

  local response = {
    "HTTP/1.1 " .. status .. " " .. message,
    "Content-Length: " .. #body,
    "",
    body,
  }

  return table.concat(response, "\r\n")
end

local function handle_client(client)
  local pattern, version = 
    client:receive():match("(%u+%s[%p%w]+)%s(HTTP/1.1)")

  -- ignore headers for now
  for line in function() client:receive() end do end

  local data = match_handler(pattern)

  local response = ""

  if type(data) == "table" then
    response = serialize(data.status, data.body or "")
  else
    response = serialize(200, data)
  end

  client:send(response)
end

local function wrapper(client)
  client:settimeout(5)
  ok, err = pcall(handle_client, client)
  if not ok then
    -- TODO: log errors
    client:send(serialize(500, err))
  end
  client:close()
end

function http.listen(port)
  local server = socket.bind("*", port or 8080)

  while true do
    local client = server:accept()
    coroutine.wrap(wrapper)(client)
  end
end

function http.get(pattern, handler)
  http.handlers["GET " .. pattern] = handler
end

return http
