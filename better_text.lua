-- Shared preparation for widened dialogue and battle messages.
-- Pagination stays with the engine's glyph-aware TextBox helper.
local TextBox = require("src.render.TextBox")
local Text = {}

function Text.prepare(text)
  text = tostring(text or ""):gsub("\r\n", "\n")
  -- Join a word split by a hyphen at a stock line boundary before reflow.
  -- A scroll inside the split word is also a soft boundary. Other scrolls,
  -- explicit page breaks and hyphens within a line remain intact.
  text = text:gsub("([%a\128-\255])%-[ \t]*[\n\v][ \t]*([%a\128-\255])", "%1%2")
  return (text:gsub("\n", " "))
end

function Text.paginate(text, maxCols)
  return TextBox.paginate(Text.prepare(text), maxCols)
end

return Text
