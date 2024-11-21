require("circuit-connector-sprites")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")

local logistic_chest_opened_duration = 7

data:extend({
  {
    type = "logistic-container",
    name = "orbital-transfer-provider",
    icon = "__base__/graphics/icons/passive-provider-chest.png",
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "orbital-transfer-provider"},
    max_health = 350,
    corpse = "passive-provider-chest-remnants",
    dying_explosion = "passive-provider-chest-explosion",
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    damaged_trigger_effect = hit_effects.entity(),
    resistances =
    {
      {
        type = "fire",
        percent = 90
      },
      {
        type = "impact",
        percent = 60
      }
    },
    surface_conditions =
    {
      {
        property = "pressure",
        min = 0,
        max = 0
      }
    },
    fast_replaceable_group = "container",
    inventory_size = 1,
    quality_affects_inventory_size = false,
    render_not_in_network_icon = false,
    icon_draw_specification = {scale = 0.7},
    logistic_mode = "passive-provider",
    open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume=0.43 },
    close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.43 },
    animation_sound = sounds.logistics_chest_open,
    impact_category = "metal",
    opened_duration = logistic_chest_opened_duration,
    animation =
    {
      layers =
      {
        {
          filename = "__base__/graphics/entity/logistic-chest/passive-provider-chest.png",
          priority = "extra-high",
          width = 66,
          height = 74,
          frame_count = 7,
          shift = util.by_pixel(0, -2),
          scale = 0.5
        },
        {
          filename = "__base__/graphics/entity/logistic-chest/logistic-chest-shadow.png",
          priority = "extra-high",
          width = 112,
          height = 46,
          repeat_count = 7,
          shift = util.by_pixel(12, 4.5),
          draw_as_shadow = true,
          scale = 0.5
        }
      }
    },
    circuit_connector = circuit_connector_definitions["chest"],
    circuit_wire_max_distance = default_circuit_wire_max_distance
  },
  {
    type = "logistic-container",
    name = "orbital-transfer-requester",
    icon = "__base__/graphics/icons/requester-chest.png",
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "orbital-transfer-requester"},
    max_health = 350,
    max_logistic_slots = 1,
    corpse = "requester-chest-remnants",
    dying_explosion = "requester-chest-explosion",
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    damaged_trigger_effect = hit_effects.entity(),
    resistances =
    {
      {
        type = "fire",
        percent = 90
      },
      {
        type = "impact",
        percent = 60
      }
    },
    surface_conditions =
    {
      {
        property = "pressure",
        min = 0,
        max = 0
      }
    },
    fast_replaceable_group = "container",
    inventory_size = 1,
    quality_affects_inventory_size = false,
    render_not_in_network_icon = false,
    icon_draw_specification = {scale = 0.7},
    logistic_mode = "storage",
    open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume=0.43 },
    close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.43 },
    animation_sound = sounds.logistics_chest_open,
    impact_category = "metal",
    opened_duration = logistic_chest_opened_duration,
    animation =
    {
      layers =
      {
        {
          filename = "__base__/graphics/entity/logistic-chest/requester-chest.png",
          priority = "extra-high",
          width = 66,
          height = 74,
          frame_count = 7,
          shift = util.by_pixel(0, -2),
          scale = 0.5
        },
        {
          filename = "__base__/graphics/entity/logistic-chest/logistic-chest-shadow.png",
          priority = "extra-high",
          width = 112,
          height = 46,
          repeat_count = 7,
          shift = util.by_pixel(12, 4.5),
          draw_as_shadow = true,
          scale = 0.5
        }
      }
    },
    circuit_connector = circuit_connector_definitions["chest"],
    circuit_wire_max_distance = default_circuit_wire_max_distance
  },
})