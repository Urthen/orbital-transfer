data:extend({
  {
    type = "bool-setting",
    name = "orbital-transfer-fuel-oxidizer-barrels",
    setting_type = "startup",
    default_value = true
  },
  {
    type = "bool-setting",
    name = "orbital-transfer-deep-debug",
    setting_type = "runtime-global",
    default_value = false
  },
  {
    type = "bool-setting",
    name = "orbital-transfer-render-deliveries",
    setting_type = "runtime-global",
    default_value = true
  },
  {
    type = "bool-setting",
    name = "orbital-transfer-debug",
    setting_type = "runtime-global",
    default_value = false
  },
  {
    type = "int-setting",
    name = "orbital-transfer-tick-rate",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 1
  },  
  {
    type = "int-setting",
    name = "orbital-transfer-delivery-delay",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 1
  },
})