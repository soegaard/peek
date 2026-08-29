-- Basic Lua preview fixture.
local function greet(name)
  local message = [[hello ]] .. name
  return message, true
end

print(greet("peek"))
