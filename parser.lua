function parser(data)
  local pattern, version, rest
  local body = ""
  local headers = { }

  -- parse request line
  while pattern == nil do
    pattern, version, rest = 
        data:match("(%u+%s[%p%w]+)%s(HTTP/1.1)\r\n(.*)")

    if pattern then
      data = rest
    else
      data = data .. coroutine.yield()
    end
  end

  -- parse headers
  while true do
    local key, value, rest = 
        data:match("([%w%-]+):%s([%p%w]+)\r\n(.*)")

    if key then
      headers[key] = value
      data = rest
    else
      local match = data:match("\r\n(.*)")

      if match then
        data = match
        break
      end

      data = data .. coroutine.yield()
    end
  end

  -- parse body
  if headers["Content-Length"] then
    local length = tonumber(headers["Content-Length"])

    while #data < length do
      data = data .. coroutine.yield()
    end

    body = data:sub(1, length)
  end

  return { pattern = pattern, version = version, headers = headers, body = body }
end

return parser
