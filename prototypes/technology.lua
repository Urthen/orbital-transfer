data:extend(
{
  {
    type = "technology",
    name = "orbital-transfer",
    icons = {
      {icon = "__space-age__/graphics/icons/space-platform-hub.png", scale = 1, shift={0, -16}},
      {icon = "__base__/graphics/icons/passive-provider-chest.png", scale = 1, shift={-32, 32}},
      {icon = "__base__/graphics/icons/requester-chest.png", scale = 1, shift={32, 32}},
    },
    icon_size = 256,
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "orbital-transfer-provider"
      },
      {
        type = "unlock-recipe",
        recipe = "orbital-transfer-requester"
      },
    },
    prerequisites = {"space-platform-thruster", "logistic-system"},
    unit =
    {
      count = 1000,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 60
    }
  },
})