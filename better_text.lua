-- Shared preparation for widened dialogue and battle messages.
-- Pagination stays with the engine's glyph-aware TextBox helper.
local TextBox = require("src.render.TextBox")
local Text = {}

function Text.prepare(text)
  text = tostring(text or ""):gsub("\r\n", "\n")
  -- Join a word split by a hyphen at a stock line boundary before reflow.
  -- A scroll inside the split word is also a soft boundary. Explicit page
  -- breaks and hyphens within a line remain intact.
  text = text:gsub("([%a\128-\255])%-[ \t]*[\n\v][ \t]*([%a\128-\255])", "%1%2")
  return (text:gsub("[\n\v]", " "))
end

function Text.paginate(text, maxCols)
  local pages = TextBox.paginate(Text.prepare(text), maxCols)
  -- Stock line and scroll boundaries describe the narrow textbox. Pause
  -- against the reflowed rows instead, before either visible row is lost.
  for pageIndex, page in ipairs(pages) do
    local conts = pages.contBefore[pageIndex]
    for lineIndex = 1, #page do
      conts[lineIndex] = lineIndex > 2
    end
  end
  return pages
end

return Text
