-- Internal BetterBattle module. Message ownership, reflow, visibility, and drawing. install() owns message queue/start hooks.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Policy = assert(deps.policy)
  local BattleState = require("src.battle.BattleState")
  local Font = require("src.render.Font")
  local Text = assert(deps.text)

  function M.playerPaneBelowHead(battle)
    return not battle.safari
      and not battle.demo
      and (
        battle.phase == "menu"
        or battle.phase == "moveSelect"
        or battle.phase == "mimicSelect"
        or (
          M.displayedMessagePane(battle) == "player"
          and (battle.current or battle.animPlaying or battle.msgHold)
        )
      )
  end

  local PLAYER_MESSAGE_WIDTH = 112

  local WIDE_MESSAGE_WIDTH = 288

  local MESSAGE_VISIBLE_LINES = 2

  -- Message rows are tagged at the point where battle actions enqueue them.
  -- This keeps pane ownership stable while the queue advances through
  -- animation/hold rows (where transient battle fields are unavailable).
  local function routeQueuedMessages(methodName, destinationFor)
    local original = BattleState[methodName]
    if type(original) ~= "function" then return end
    BattleState[methodName] = function(battle, ...)
      local existing = {}
      for _, queued in ipairs(battle.queue or {}) do
        existing[queued] = true
      end
      local result = original(battle, ...)
      for _, queued in ipairs(battle.queue or {}) do
        if not existing[queued] and queued.text and not queued._betterMessagePane then
          queued._betterMessagePane = destinationFor(battle, ...)
        end
      end
      return result
    end
  end

  M.displayedMessagePane = function(battle)
    if
      battle.phase ~= "messages"
      or battle.shown ~= battle._betterMessageShown
      or #(battle.shown or {}) == 0
    then
      return nil
    end
    return battle._betterMessagePane
  end

  function M.escapeMessageVisible(battle)
    return Policy.setting(battle)
      and battle.phase == "messages"
      and battle.result == "run"
      and battle.playerRan
      and battle.current
      and battle.current.text == battle:romText("_GotAwayText", "Got away safely!")
  end

  local function drawShownMessageLines(battle, x, y, width, lineCount, lineStep, clipHeight)
    local g = love.graphics
    lineStep = lineStep or 16
    clipHeight = clipHeight or lineCount * lineStep

    g.push("all")
    g.intersectScissor(x, y, width, clipHeight)
    g.setColor(0, 0, 0, 1)

    if battle.scrollPx and battle.scrollPx > 0 then
      battle.scrollPx = math.max(0, battle.scrollPx - 2)
      if battle.scrollPx == 0 then battle.scrollPx = nil end
    end

    local off = battle.scrollPx or 0
    for lineIndex, line in ipairs(battle.shown or {}) do
      if lineIndex <= lineCount then
        local lineX = x
        local lineY = y + (lineIndex - 1) * lineStep + off

        for _, code in ipairs(line) do
          Font.drawCode(code, lineX, lineY)
          lineX = lineX + Font.advanceOf(code)
        end
      end
    end

    g.pop()
  end

  function M.drawBetterMessageBox(battle)
    local pad = Layout.framePadding()
    Font.drawBox(0, pad > 0 and 12 or 13, 38, pad > 0 and 6 or 5)

    drawShownMessageLines(
      battle,
      8 + pad,
      pad > 0 and 106 or 112,
      WIDE_MESSAGE_WIDTH - pad * 8,
      MESSAGE_VISIBLE_LINES,
      16,
      pad > 0 and 28 or 24
    )

    if (battle.msgWaiting or battle.msgPrompt) and (battle.frame or 0) % 60 < 30 then
      love.graphics.setColor(0, 0, 0, 1)
      Font.drawCode(0xEE, pad > 0 and 286 or 296, pad > 0 and 126 or 132)
    end

    return 0, pad > 0 and 96 or 104, 304, pad > 0 and 48 or 40, "bottom"
  end

  local function battleMessageWidthTiles(battle)
    local maxWidth = 0

    for _, line in ipairs(battle.lines or {}) do
      local width = 0
      for _, code in ipairs(line.codes or {}) do
        width = width + Font.advanceOf(code)
      end
      maxWidth = math.max(maxWidth, width)
    end

    return math.max(
      3,
      math.min(38, math.ceil(maxWidth / 8) + (Layout.framePadding() > 0 and 4 or 2))
    )
  end

  -- Centered, content-sized pane for wild intro and post-battle messages.
  function M.drawCenteredMessageBox(battle)
    local widthTiles = battleMessageWidthTiles(battle)
    local lineCount = math.max(1, math.min(MESSAGE_VISIBLE_LINES, #(battle.lines or {})))
    local pad = Layout.framePadding()
    local heightTiles = lineCount * 2 + (pad > 0 and 2 or 1)
    local tx = math.floor((38 - widthTiles) / 2)
    local ty = 18 - heightTiles
    local clipHeight = lineCount == 1 and 8 or 24
    local lineY = (ty + 1) * 8 + pad
    if pad > 0 and lineCount == 1 then lineY = lineY + 2 end

    love.graphics.setColor(0, 0, 0, 1)
    Font.drawBox(tx, ty, widthTiles, heightTiles)

    drawShownMessageLines(
      battle,
      (tx + 1) * 8 + pad,
      lineY,
      (widthTiles - 2) * 8 - pad * 4,
      lineCount,
      16,
      clipHeight
    )

    if (battle.msgWaiting or battle.msgPrompt) and (battle.frame or 0) % 60 < 30 then
      love.graphics.setColor(0, 0, 0, 1)
      Font.drawCode(
        0xEE,
        pad > 0 and (tx + widthTiles - 2) * 8 - pad or (tx + widthTiles - 1) * 8,
        pad > 0 and (ty + heightTiles - 1) * 8 - 10 - (lineCount == 1 and 2 or 0)
          or (ty + heightTiles) * 8 - 12
      )
    end

    return tx * 8, ty * 8, widthTiles * 8, heightTiles * 8, "bottom"
  end

  -- Player move messages use a separate pane below the party.
  function M.drawPlayerMessageBox(battle)
    local tx, ty, tw, th = 22, 8, 16, 5
    local pad = Layout.framePadding()

    love.graphics.setColor(0, 0, 0, 1)
    Font.drawBox(tx, ty, tw, th)

    drawShownMessageLines(
      battle,
      (tx + 1) * 8 + pad,
      (ty + 1) * 8 + pad,
      PLAYER_MESSAGE_WIDTH - pad * 8,
      MESSAGE_VISIBLE_LINES,
      pad > 0 and 12 or 8,
      pad > 0 and 20 or 16
    )

    if (battle.msgWaiting or battle.msgPrompt) and (battle.frame or 0) % 60 < 30 then
      love.graphics.setColor(0, 0, 0, 1)
      Font.drawCode(0xEE, pad > 0 and 286 or 296, pad > 0 and 86 or 88)
    end

    return 176, 64, 128, Layout.PLAYER_PANE_H, "top"
  end

  function M.install()
    routeQueuedMessages(
      "executeAction",
      function(_, user) return user and user.isPlayer and "player" or "generic" end
    )

    routeQueuedMessages("onFaint", function() return "generic" end)

    routeQueuedMessages("awardExp", function() return "center" end)

    routeQueuedMessages("learnMove", function() return "center" end)

    routeQueuedMessages(
      "enemyMonFainted",
      function(battle) return battle.result == "win" and "center" or "generic" end
    )

    -- Reflow the engine's decoded message lines before the first glyph is
    -- revealed. Player messages use the compact pane width; centered and
    -- generic messages use the full available width.
    local originalStartMessage = BattleState.startMessage

    BattleState.startMessage = function(battle, item)
      local active = Policy.setting(battle)
      local destination = type(item) == "table" and item._betterMessagePane
      if not destination then
        if battle.result == "run" and battle.afterQueue == "finish" then
          destination = "center"
        elseif battle.kind == "wild" and battle.introBalls == true then
          destination = "wild-intro"
        elseif battle.enemySendingOut == true then
          destination = "generic"
        elseif battle.sendingOut == true then
          destination = "center"
        else
          destination = "generic"
        end
      end
      if destination == "generic" then destination = "center" end
      local result = originalStartMessage(battle, item)
      battle._betterMessagePane = destination
      battle._betterMessageShown = active and battle.shown or nil
      if not active and not Policy.stockWideExtended(battle) then return result end

      local pad = Layout.framePadding()
      local maxWidth = active and destination == "player"
        and (PLAYER_MESSAGE_WIDTH - pad * 8) or (WIDE_MESSAGE_WIDTH - pad * 8)
      -- Use the same preparation and pagination as widened overworld dialogue.
      local pages = Text.paginate(type(item) == "table" and item.text or "", maxWidth / 8)
      local lines, total = {}, 0
      for pageIndex, page in ipairs(pages) do
        for lineIndex, text in ipairs(page) do
          local continuation = pages.contBefore
            and pages.contBefore[pageIndex][lineIndex] or false
          if pageIndex > 1 and lineIndex == 1 then continuation = true end
          local codes = Font.encode(text)
          lines[#lines + 1] = { text = text, codes = codes, cont = continuation }
          total = total + #codes
        end
      end

      battle.lines, battle.total = lines, total
      battle.shown, battle.lineIndex = {}, 0
      battle.scrollPx = nil
      battle:beginMsgLine()
      battle._betterMessageShown = active and battle.shown or nil
      return result
    end
  end

  return M
end
