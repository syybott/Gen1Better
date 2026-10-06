-- Hide field menus that Kanto Gear mirrors on its separate companion display.
-- Observe the bridge supplied to downstream hooks; never replace the engine's
-- bridge or alter Kanto Gear's menu/input state.
local Menu = require("src.ui.Menu")
local ChoiceBox = require("src.ui.ChoiceBox")
local PC_LIST_KINDS = {
  pc_box_withdraw = true, pc_box_deposit = true,
  pc_box_release = true, pc_box_change = true,
  pc_item_withdraw = true, pc_item_deposit = true, pc_item_toss = true,
}

return function(mod)
  local compat = {}
  local game, sourceBridge, observedBridge, ownerExports
  local enabled, ready = false, false

  local function provider()
    return type(mod.find) == "function" and mod.find("kanto_gear") or nil
  end

  local function separateDisplay()
    local loader = game and game.mods
    local stored = loader and loader.modOptions
      and loader.modOptions.kanto_gear
    local mode = stored and stored.display_mode
    if mode == nil then
      for _, row in ipairs(loader and loader.optionSchemas
          and loader.optionSchemas.kanto_gear or {}) do
        if row.key == "display_mode" then mode = row.default; break end
      end
    end
    return mode == "separate"
  end

  local function available()
    if not sourceBridge then return false end
    local detectedOk, detected = pcall(sourceBridge.detected)
    local availableOk, canSubmit = pcall(sourceBridge.available)
    return detectedOk and detected == true
      and availableOk and canSubmit == true
  end

  local function resetDisplay()
    sourceBridge, observedBridge, ownerExports = nil, nil, nil
    enabled, ready = false, false
  end

  mod.events:on("game.ready", function(event)
    game = event and event.game
    resetDisplay()
  end)

  -- Kanto Gear retains this facade for asynchronous submissions and screen
  -- swaps. Forward every bridge operation, recording only enable/submission
  -- results. A failed or throwing push immediately releases menu ownership.
  mod.hooks:wrap("render.compose", function(next, renderer, context)
    local gear = provider()
    local bridge = context and context.secondScreen
    if not (gear and separateDisplay() and type(bridge) == "table"
        and type(bridge.push) == "function"
        and type(bridge.setEnabled) == "function"
        and type(bridge.detected) == "function"
        and type(bridge.available) == "function") then
      resetDisplay()
      return next(renderer, context)
    end

    if bridge ~= sourceBridge or gear.exports ~= ownerExports then
      resetDisplay()
      sourceBridge, ownerExports = bridge, gear.exports
      local observed = setmetatable({}, { __index = bridge })
      observed.setEnabled = function(on)
        if observed == observedBridge then
          enabled = on == true
          if not enabled then ready = false end
        end
        return bridge.setEnabled(on)
      end
      observed.push = function(...)
        if observed == observedBridge then ready = false end
        local shown = bridge.push(...)
        if observed == observedBridge then
          ready = enabled and shown == true
        end
        return shown
      end
      observedBridge = observed
    end

    if not available() then ready = false end
    local observedContext = {}
    for key, value in pairs(context) do observedContext[key] = value end
    setmetatable(observedContext, getmetatable(context))
    observedContext.secondScreen = observedBridge
    return next(renderer, observedContext)
  end, -999) -- Outside Kanto Gear's companion submission hook (-1000).

  local function mirroredMenu(state)
    if type(state) ~= "table" then return false end
    if getmetatable(state) == ChoiceBox then
      -- Gear's choice view always shows YES/NO, including the SAVE prompt.
      -- Keep other two-option labels visible rather than misrepresent them.
      return type(state.update) == "function"
        and type(state.onChoose) == "function" and state.items == nil
        and (state.index == 1 or state.index == 2)
        and type(state.labels) == "table" and #state.labels == 2
        and state.labels[1] == "YES" and state.labels[2] == "NO"
    end
    if getmetatable(state) ~= Menu
        or state.isModOptions or PC_LIST_KINDS[state.kind]
        or state.phase ~= nil
        or type(state.update) ~= "function"
        or type(state.items) ~= "table" or #state.items == 0
        or type(state.index) ~= "number" or state.index % 1 ~= 0
        or state.index < 1 or state.index > #state.items then
      return false
    end

    if state.screenId == "StartMenu" then
      if not state.startCloses then return false end
    elseif state.screenId ~= nil then
      -- Named custom screens may expose rows without being mirrored by Gear.
      return false
    end

    -- A confirmation or stat overlay takes precedence over Gear's list view.
    if state.confirm or type(state.mon) == "table" and state.mon.stats then
      return false
    end
    for _, item in ipairs(state.items) do
      if type(item) ~= "table" or type(item.label) ~= "string" then
        return false
      end
    end
    return true
  end

  function compat.shouldHide(state)
    local gear = provider()
    if not (gear and gear.exports == ownerExports and enabled and ready
        and separateDisplay() and available() and mirroredMenu(state)) then
      return false
    end

    -- Only the running Gen 1 field is in scope. Title menus and the other
    -- generations retain their presentation, even if a companion is ready.
    if not game or (game.generation and game.generation ~= 1)
        or state.game ~= game then return false end
    local inStack, inField = false, false
    for _, screen in ipairs(game.stack and game.stack.states or {}) do
      if screen.isBattle then return false end
      if screen == state then inStack = true end
      if screen == game.overworld then inField = true end
    end
    return inStack and inField
  end

  return compat
end
