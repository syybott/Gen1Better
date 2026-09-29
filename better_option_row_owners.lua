-- Track option contributions only while BetterOptions builds its own rows.
-- The engine hook runner retains its error handling and invocation semantics.
local Owners = {}
local unpack = table.unpack or unpack
local function pack(...) return { n = select("#", ...), ... } end
local function rowSet(rows)
  local out = {}
  for _, row in ipairs(type(rows) == "table" and rows or {}) do out[row] = true end
  return out
end

function Owners.collect(hooks, build)
  local owners, originals = {}, {}
  local function mark(rows, previous, owner)
    if not owner or type(rows) ~= "table" then return end
    for _, row in ipairs(rows) do
      if type(row) == "table" and not previous[row] and not owners[row] then
        owners[row] = owner
      end
    end
  end
  local chain = hooks and hooks.chains and hooks.chains["ui.options.rows"] or {}
  for _, entry in ipairs(chain) do
    local callback, owner = entry.callback, entry.owner
    originals[#originals + 1] = { entry = entry, callback = callback }
    entry.callback = function(next, ...)
      local args = pack(...)
      local before, downstream = rowSet(args[2]), nil
      local function trackedNext(...)
        local passed = pack(...)
        mark(passed.n == 0 and args[2] or passed[2], before, owner)
        local result = pack(next(...))
        downstream = rowSet(result[1])
        return unpack(result, 1, result.n)
      end
      local result = pack(callback(trackedNext, ...))
      mark(result[1], downstream or before, owner)
      return unpack(result, 1, result.n)
    end
  end
  local result = pack(pcall(build))
  for _, saved in ipairs(originals) do saved.entry.callback = saved.callback end
  if not result[1] then error(result[2], 0) end
  return result[2], owners
end

return Owners
