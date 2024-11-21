local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")

data:extend({
  {
    type = "item",
    name = "orbital-transfer-provider",
    icon = "__base__/graphics/icons/passive-provider-chest.png",
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
    icon = "__base__/graphics/icons/requester-chest.png",
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