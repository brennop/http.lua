function parser(data)
  local pattern, version, rest, body
  local headers = { }

  -- parse request line
  while pattern == nil do
    pattern, version, rest = data:match("(%u+%s[%p%w]+)%s(HTTP/1.1)\r\n(.*)")

    data = rest or (data .. coroutine.yield())
  end

  -- parse headers
  while not data:match("^\r\n(.*)") do
    local key, value, rest = data:match("([%w%-]+):%s([%p%w]+)\r\n(.*)")

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
  end

  return { pattern = pattern, version = version, headers = headers, body = body }
end

return parser
