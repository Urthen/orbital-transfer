data:extend({
  {
    type = "recipe",
    name = "orbital-transfer-provider",
    enabled = false,
    ingredients =
    {
      {type = "item", name = "passive-provider-chest", amount = 1},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "electric-engine-unit", amount = 10},
      {type = "item", name = "low-density-structure", amount = 10},
    },
    results = {{type="item", name="orbital-transfer-provider", amount=1}}
  },
  {
    type = "recipe",
    name = "orbital-transfer-requester",
    enabled = false,
    ingredients =
    {
      {type = "item", name = "requester-chest", amount = 1},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "electric-engine-unit", amount = 10},
      {type = "item", name = "low-density-structure", amount = 10},
    },
    results = {{type="item", name="orbital-transfer-requester", amount=1}}
  },
})