-- Internal BetterBattle module. Command/move menus and scoped input handling. install() owns update/navigation hooks.
-- Loaded once by better_battle_hud.lua; not a public consumer API.
return function(deps)
  local M = {}
  local Layout = assert(deps.layout)
  local Policy = assert(deps.policy)
  local Presentation = assert(deps.presentation)
  local BattleState = require("src.battle.BattleState")
  local Font = require("src.render.Font")
  local Strings = require("src.core.Strings")
  local WideBattle = require("src.battle.WideBattle")
  local tinyFont = deps.compatibility.tinyFont or {}

  local function wrapWords(text, maxWidth)
    local lines, line = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local candidate = line == "" and word or line .. " " .. word
      if line ~= "" and Font.width(candidate) > maxWidth then
        lines[#lines + 1] = line
        line = word
      else
        line = candidate
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
  end

  local SELECTOR_ON_SECONDS = 1.100

  local SELECTOR_PERIOD_SECONDS = SELECTOR_ON_SECONDS + 0.550

  local function battleSelectorVisible(battle)
    return ((battle._betterSelectorBlinkElapsed or 0) % SELECTOR_PERIOD_SECONDS)
      < SELECTOR_ON_SECONDS
  end

  function M.drawBetterCommandMenu(battle)
    local pad = Layout.framePadding()
    if not battle.safari and not battle.demo then
      Font.drawBox(22, 8, 16, 5)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("FIGHT"), 194, 72 + pad)
      Font.drawCode(0xE1, 258, 72 + pad)
      Font.drawCode(0xE2, 266, 72 + pad)
      Font.draw(Strings("ITEM"), 194, 83 + pad + (pad > 0 and 1 or 0))
      Font.draw(Strings("RUN"), 258, 83 + pad + (pad > 0 and 1 or 0))

      local index = battle.menuIndex or 1
      local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
      if battleSelectorVisible(battle) then
        Font.drawCode(
          0xED,
          (col == 0 and 184 or 248) + pad,
          72 + pad + row * (pad > 0 and 12 or 11)
        )
      end
      return 176, 64, 128, 40, "top"
    end

    Font.drawBox(22, 8, 16, 4)
    love.graphics.setColor(0, 0, 0, 1)
    if not battle.demo then
      local who = battle.player and battle.player.name or ""
      local prompt = Strings("What will") .. " " .. tostring(who) .. Strings(" do?")
      for i, line in ipairs(wrapWords(prompt, 112 - pad * 8)) do
        Font.draw(line, 184 + pad, 72 + pad + (i - 1) * 8)
      end
    end

    if battle.safari then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 184, 72, 112, 16)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("BALLx") .. tostring(battle.safari.balls), 184, 72)
    end

    love.graphics.push()
    love.graphics.translate(0, -1)
    Font.drawBox(22, 12, 16, 4)

    if battle.safari then
      Font.draw(Strings("BALL"), 192, 104)
      Font.draw(Strings("BAIT"), 256, 104)
      Font.draw(Strings("ROCK"), 192, 112)
      Font.draw(Strings("RUN"), 256, 112)
    else
      Font.draw(Strings("FIGHT"), 192, 104)
      Font.drawCode(0xE1, 256, 104)
      Font.drawCode(0xE2, 264, 104)
      Font.draw(Strings("ITEM"), 192, 112)
      Font.draw(Strings("RUN"), 256, 112)
    end

    local index = battle.menuIndex or 1
    if battle.demo then index = (battle.demoTimer or 0) <= 80 and 1 or 3 end
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
    Font.drawCode(0xED, col == 0 and 184 or 248, 104 + row * 8)
    love.graphics.pop()
    return 176, 64, 128, 64, "top"
  end

  local function tinyDraw(text, x, y)
    if type(tinyFont.draw) == "function" then return tinyFont.draw(text, x, y, 0) end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(tostring(text or ""), x, y)
  end

  local function tinyFit(text, width)
    if type(tinyFont.fit) == "function" then return tinyFont.fit(text, width) end
    return Presentation.fitName(text, width)
  end

  local function typeAbbreviation(value)
    if type(tinyFont.typeAbbreviation) == "function" then
      return tinyFont.typeAbbreviation(value)
    end
    return tostring(value or ""):sub(1, 3):upper()
  end

  function M.drawBetterMoveMenu(battle, moves, selected)
    local pad = Layout.framePadding()
    love.graphics.setColor(0, 0, 0, 1)
    Font.drawBox(22, 8, 16, 10)
    for i = 1, 4 do
      local move = moves and moves[i]
      local y = 75 + (pad > 0 and 1 or 0) + (i - 1) * 9
      if move then
        local def = battle:moveDef(move) or battle.data.moves[move.id]
        local maxPP = def
            and ((def.pp or 0) + (move.ppUps or 0) * math.floor((def.pp or 0) / 5))
          or 0
        tinyDraw(tinyFit(def and def.name or move.id or "", 56 - pad), 192 + pad, y)
        tinyDraw(typeAbbreviation(def and def.type), 252, y)
        tinyDraw(("%d/%d"):format(move.pp or 0, maxPP), 272, y)
      end
    end
    local cursor = math.max(1, math.min(4, selected or 1))
    love.graphics.setColor(0, 0, 0, 1)
    if battleSelectorVisible(battle) then
      Font.drawCode(0xED, 184 + pad, 72 + pad + (cursor - 1) * 9)
    end
    if battle.moveSwapIndex and battle.moveSwapIndex ~= cursor then
      Font.drawCode(0xEC, 184 + pad, 72 + pad + (battle.moveSwapIndex - 1) * 9)
    end

    love.graphics.rectangle("fill", 192 + pad, 114, 104 - pad * 2, 1)
    local move = moves and moves[cursor]
    local def = move and (battle:moveDef(move) or battle.data.moves[move.id])
    if def then
      local power = tonumber(def.power)
      local accuracy = tonumber(def.accuracy)
      tinyDraw("POWER", 192 + pad, 120)
      tinyDraw(power and power > 0 and tostring(math.floor(power)) or "---", 252, 120)
      tinyDraw("ACCURACY", 192 + pad, 129)
      tinyDraw(accuracy and tostring(math.floor(accuracy)) or "---", 252, 129)
    end
    return 176, 64, 128, 80, "top"
  end

  -- WideBattle.navigate has no battle argument. Scope the list mapping to
  -- this battle's update only; command-menu and stock-grid input stay native.
  local inputBattle

  function M.install()
    local originalUpdate = BattleState.update

    BattleState.update = function(battle, ...)
      local previous = inputBattle
      local active = Policy.setting(battle)
      local previousPhase = battle.phase
      local previousMenuIndex = battle.menuIndex
      local previousMoveIndex = battle.moveIndex
      local previousMimicIndex = battle.mimicIndex
      inputBattle = active and battle or nil
      local ok, result = pcall(originalUpdate, battle, ...)
      inputBattle = previous
      if not ok then error(result, 0) end
      if active then
        if
          battle.phase ~= previousPhase
          or battle.menuIndex ~= previousMenuIndex
          or battle.moveIndex ~= previousMoveIndex
          or battle.mimicIndex ~= previousMimicIndex
        then
          battle._betterSelectorBlinkElapsed = 0
        else
          local dt = tonumber(select(1, ...)) or (1 / 60)
          battle._betterSelectorBlinkElapsed = (
            (battle._betterSelectorBlinkElapsed or 0) + math.max(0, dt)
          ) % SELECTOR_PERIOD_SECONDS
        end
      end
      return result
    end

    local originalNavigate = WideBattle.navigate

    WideBattle.navigate = function(index, count, input)
      if
        inputBattle
        and (inputBattle.phase == "moveSelect" or inputBattle.phase == "mimicSelect")
      then
        if count < 1 then return nil end
        if input:wasPressed("up") then return (index - 2) % count + 1 end
        if input:wasPressed("down") then return index % count + 1 end
        if input:wasPressed("left") or input:wasPressed("right") then return index end
        return nil
      end
      return originalNavigate(index, count, input)
    end
  end

  return M
end
