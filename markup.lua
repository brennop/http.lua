local h = {}

local document = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>%s</title>
%s
</head>
<body>
%s
</body>
</html>
]]

setmetatable(h, {
  __index = function(_, tag)
    return function(data)
      local children = {}
      local attrs = {}

      if type(data) == "table" then
        for k, v in pairs(data) do
          if type(k) == "number" then
            children[k] = v
          else
            attrs[k] = v
          end
        end
      else
        children = {data}
      end

      return {tag = tag, attrs = attrs, children = children}
    end
  end
})

function h.render(node)
  if type(node) == "string" then
    return node
  end
  local attrs = {}
  for k, v in pairs(node.attrs) do
    table.insert(attrs, string.format(' %s="%s"', k, v))
  end
  local children = {}
  for _, child in ipairs(node.children) do
    table.insert(children, h.render(child))
  end
  return string.format("<%s%s>%s</%s>", node.tag, table.concat(attrs), table.concat(children, ""), node.tag)
end

function h.html(data)
  local heads = {}
  for i, child in ipairs(data.head or {}) do heads[i] = h.render(child) end
  return document:format(data.title, table.concat(heads, "\n"), h.render(data.body))
end

return h
