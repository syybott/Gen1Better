-- Classic palette compatibility belongs to the mod, including options UI.
return function(mod, locked, drawCard, cardZone)
  local ManagerState = require("src.mods.ManagerState")
  local TextBox = require("src.render.TextBox")
  local PaletteFX = require("src.render.PaletteFX")
  local buttons = { "a", "b", "left", "right", "up", "down", "start" }
  local waitingForRelease = false
  local promptOpen = false
  local frameReminders = setmetatable({}, { __mode = "k" })

  local function released(game)
    for _, button in ipairs(buttons) do
      if game.input:isDown(button) or game.input:wasPressed(button) then
        return false
      end
    end
    return true
  end

  local function blocked(game)
    if promptOpen then return true end
    if waitingForRelease then
      if not released(game) then return true end
      waitingForRelease = false
    end
    return false
  end

  -- Options rows run only on pressed edges; observe idle ticks as well.
  mod.hooks:wrap("input.step", function(next, game, dt)
    if waitingForRelease and released(game) then
      waitingForRelease = false
    end
    return next(game, dt)
  end)

  local function isOgFrame(value)
    return type(value) == "string" and value:match("^og:") ~= nil
  end

  local function frameChoices(game, definition)
    local choices = definition.choices or {}
    if not locked(game) then return choices end
    local og = {}
    for _, choice in ipairs(choices) do
      if isOgFrame(choice[2]) then og[#og + 1] = choice end
    end
    return og
  end

  local function remindOnFrameExit(game)
    local stack = game.stack
    local screen = stack and stack:top()
    if not screen then return end
    frameReminders[screen] = true
    if stack.gen1BetterMenusFrameReminderInstalled then return end
    stack.gen1BetterMenusFrameReminderInstalled = true
    local update = stack.update
    stack.update = function(self, ...)
      local top = self:top()
      local pending = top and frameReminders[top]
      local exiting = pending and (game.input:wasPressed("b")
        or game.input:wasPressed("start"))
      if pending and (exiting or not locked(game)) then
        frameReminders[top] = nil
      end
      -- Let B/START perform the screen's normal back/save action first.
      local result = update(self, ...)
      -- The stock manager options pane handles B but has no START route.
      if exiting and game.input:wasPressed("start") and self:top() == top
          and top.screen == "options" and type(top.goBack) == "function" then
        top:goBack()
      end
      if exiting and locked(game) and isOgFrame(mod.options:get("better_frames")) then
        game.stack:push(TextBox.new(game,
          "MORE CUSTOM FRAMES AVAILABLE\n" ..
          "IF YOU CHOOSE A DIFFERENT\n" ..
          "IN GAME PALETTE.\f" ..
          "SELECT YOUR PALETTE IN THE\n" ..
          "COLORS MENU UNDER THE\n" ..
          "GRAPHICS OPTIONS."))
      end
      return result
    end
  end

  local function advanced(game)
    game.save.options.palette = ""
    game.save.options.colors = "redpp"
    PaletteFX.setCustomRamp(nil)
    PaletteFX.setMode("redpp")
    if game.writeOptions then game:writeOptions() end
  end

  local function ask(game, onYes)
    if blocked(game) then return end
    promptOpen = true
    local message = "WHILE USING A CLASSIC GAME\nPALETTE THE MENU IS LOCKED\nTO THE SAME,\fWOULD YOU LIKE TO CHANGE TO\nADVANCED GAME PALETTE?"
    game.stack:push(TextBox.new(game, message, nil, {
      defaultNo = true,
      choice = function(yes)
        promptOpen = false
        waitingForRelease = true
        if yes then
          advanced(game)
          onYes()
        end
      end,
    }))
  end

  local function picker(manager, schema)
    local game = manager.game
    local choices = schema.choices or {}
    if #choices == 0 then return end
    local saved = mod.options:get("palette")
    local state = {
      game = game, index = 1, isOpaque = false,
      holdsUIAnchors = true, BetterMenusScaleEligible = true,
    }
    for index, choice in ipairs(choices) do
      if choice[2] == saved then state.index = index break end
    end
    local parent = game.stack:top()
    local width, height = 304, 168
    if parent and parent.uiSize then width, height = parent:uiSize() end
    local style = { width = width, height = height }
    local function preview()
      mod.gen1BetterMenusPalettePreview = choices[state.index][2]
    end
    local function close(commit)
      mod.gen1BetterMenusPalettePreview = nil
      if commit then manager:setOption(mod.id, "palette", choices[state.index][2]) end
      game.stack:pop()
      waitingForRelease = true
    end
    function state:uiSize() return width, height end
    function state:sgbPalettes()
      return cardZone({ choices[self.index][1] }, style)
    end
    function state:draw()
      drawCard({ choices[self.index][1] }, 1, style)
    end
    function state:update()
      if blocked(game) then return end
      local input = game.input
      if locked(game) then close(false) return end
      if input:wasPressed("left") or input:wasPressed("up") then
        self.index = (self.index - 2) % #choices + 1
        preview()
      elseif input:wasPressed("right") or input:wasPressed("down") then
        self.index = self.index % #choices + 1
        preview()
      elseif input:wasPressed("a") or input:wasPressed("start") then
        close(true)
      elseif input:wasPressed("b") then
        close(false)
      end
    end
    preview()
    game.stack:push(state)
  end

  local originalBuild = ManagerState.buildOptionRows
  ManagerState.buildOptionRows = function(manager, candidate, schema)
    if candidate.id ~= mod.id then return originalBuild(manager, candidate, schema) end
    local byKey = {}
    for _, definition in ipairs(schema) do byKey[definition.key] = definition end
    local visibleSchema = {}
    for i, definition in ipairs(schema) do
      if definition.key == "better_frames" then
        local copy = {}
        for key, value in pairs(definition) do copy[key] = value end
        copy.choices = frameChoices(manager.game, definition)
        visibleSchema[i] = copy
      else
        visibleSchema[i] = definition
      end
    end
    local rows = originalBuild(manager, candidate, visibleSchema)
    for _, row in ipairs(rows) do
      local key = row.id
      if key == "palette" or key == "better_frames" then
        local value, step = row.value, row.step
        row.value = function(...)
          if key == "better_frames" then
            local current = mod.options:get(key)
            for _, choice in ipairs(frameChoices(manager.game, byKey[key])) do
              if choice[2] == current then return choice[1] end
            end
            return "DEFAULT"
          end
          if locked(manager.game) then
            return "CLASSIC"
          end
          return value(...)
        end
        row.step = function(game, direction)
          game = game or manager.game
          if key == "palette" then
            if blocked(game) then return false end
            if not locked(game) then return step(game, direction) end
            ask(game, function() picker(manager, byKey.palette) end)
            return false
          end
          local choices = frameChoices(game, byKey.better_frames)
          if #choices == 0 then return false end
          local current = mod.options:get(key)
          local index = 1
          for i, choice in ipairs(choices) do
            if choice[2] == current then index = i break end
          end
          local target = choices[(index - 1 + (direction or 1)) % #choices + 1]
          if target[2] == current then return false end
          manager:setOption(mod.id, key, target[2])
          if mod.options:get(key) ~= target[2] then return false end
          if locked(game) then remindOnFrameExit(game) end
          return true
        end
      end
    end
    return rows
  end
end
