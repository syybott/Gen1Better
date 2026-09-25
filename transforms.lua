-- Derives battle/balls.png from the player's own ROM-imported cache so
-- crystal_sprite_compat.lua can sample ball pixel data without reading
-- assets/generated/ directly.  Runs once at install; re-runs when the
-- cache is re-imported or this file changes.
return function(ctx)
  local REL = "battle/balls.png"
  if ctx.exists(REL) then
    ctx.writeImage(ctx.readImage(REL), REL)
  end
end
