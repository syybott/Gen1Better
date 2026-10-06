-- Direct Gen1Better compatibility with PokePC Followers menu icons.
-- Resolve the active provider when drawing so mod load order is supported.
return function(mod)
  local compat = {}

  function compat.isIcon(screen, mon)
    local icons = screen.game.data.icons or {}
    local def = screen.game.data.pokemon[mon.species]
    local entry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    if type(entry) ~= "table" then return false end
    local handle = mod and type(mod.find) == "function"
      and mod.find("PokePCFollowers_VoxelMerge")
    local followers = handle and handle.exports
    if type(followers) ~= "table"
        or type(followers.assetPath) ~= "function" then
      return false
    end
    local ok, path = pcall(followers.assetPath, mon.species)
    return ok and type(path) == "string" and entry.image == path
  end

  return compat
end
