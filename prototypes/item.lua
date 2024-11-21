local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")

data:extend({
  {
    type = "item",
    name = "orbital-transfer-provider",
    icons = {      
      {icon = "__space-age__/graphics/icons/space-platform-foundation.png", scale=0.5 },
      {icon = "__base__/graphics/icons/passive-provider-chest.png", scale=0.4 },
    },
    subgroup = "space-platform",
    order = "e[orbital-transfer]-a",
    inventory_move_sound = item_sounds.metal_chest_inventory_move,
    pick_sound = item_sounds.metal_chest_inventory_pickup,
    drop_sound = item_sounds.metal_chest_inventory_move,
    place_result = "orbital-transfer-provider",
    stack_size = 10,
    weight = 100*kg,
    random_tint_color = item_tints.iron_rust
  },
  {
    type = "item",
    name = "orbital-transfer-requester",
    icons = {      
      {icon = "__space-age__/graphics/icons/space-platform-foundation.png", scale=0.5 },
      {icon = "__base__/graphics/icons/requester-chest.png", scale=0.4 },
    },
    subgroup = "space-platform",
    order = "e[orbital-transfer]-b",
    inventory_move_sound = item_sounds.metal_chest_inventory_move,
    pick_sound = item_sounds.metal_chest_inventory_pickup,
    drop_sound = item_sounds.metal_chest_inventory_move,
    place_result = "orbital-transfer-requester",
    stack_size = 10,
    weight = 100*kg,
    random_tint_color = item_tints.iron_rust
  },
})

if settings.startup["orbital-transfer-fuel-oxidizer-barrels"].value then

  data.raw.fluid["thruster-fuel"].auto_barrel = true
  data.raw.fluid["thruster-oxidizer"].auto_barrel = true

  -- local fuel_copy = table.deepcopy(data.raw.fluid["thruster-fuel"])
  -- local oxidizer_copy = table.deepcopy(data.raw.fluid["thruster-oxidizer"])

  -- fuel_copy.auto_barrel = true
  -- oxidizer_copy.auto_barrel = true

  -- data:extend({
  --   fuel_copy,
  --   oxidizer_copy
  -- })
end