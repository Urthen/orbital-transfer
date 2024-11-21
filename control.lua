local flib_on_tick_n = require("__flib__/on-tick-n")

local function debug(message, deep)
  if (not deep and settings.global["orbital-transfer-debug"].value) or settings.global["orbital-transfer-deep-debug"].value then
    game.print(message)
  end
end

local function default_platform_data(platform)
  return {
    platform = platform,
    latest_location = platform.space_location and platform.space_location.name,
    requester_chests = {},
    provider_chests = {}
  }
end

local function get_orbiting_platforms(space_location)
  local orbit_data = storage.platforms_by_space_location[space_location.name]

  if not orbit_data then
    orbit_data = {}
    storage.platforms_by_space_location[space_location.name] = orbit_data
  end

  return orbit_data
end

local function space_platform_exit_orbit(platform, platform_data)
  debug("Platform " .. platform.name .. " exited transfer orbit around " .. platform_data.latest_location.name)
  local orbit_data = get_orbiting_platforms(platform_data.latest_location)
  platform_data.latest_location = nil

  for i, platform_name in ipairs(orbit_data) do
    if platform_name == platform.name then
      table.remove(orbit_data, i)
      break
    end
  end

  debug("platforms in orbit: " .. serpent.block(orbit_data))
end

local function space_platform_enter_orbit(platform, platform_data)
  debug("Platform " .. platform.name .. " entered transfer orbit around " .. platform.space_location.name)
  platform_data.latest_location = platform.space_location
  local orbit_data = get_orbiting_platforms(platform.space_location)

  table.insert(orbit_data, platform.name)
  debug("platforms in orbit: " .. serpent.block(orbit_data))
end

local function initialize_platform(platform)
  debug("Initializing new platform into Orbital Transfer: " .. platform.name)
  local platform_data = default_platform_data(platform)
  storage.platforms_with_chests[platform.name] = platform_data

  if platform.space_location then
    space_platform_enter_orbit(platform, platform_data)
  end

  return platform_data
end

local function register_transfer_chest(event)
  debug("Built " .. event.entity.name .. " on platform " .. event.platform.name)

  -- register destruction event
  local registration, unit_number, _ = script.register_on_object_destroyed(event.entity)
  storage.registered_chests[unit_number] = { platform_name = event.platform.name, name = event.entity.name, last_tick_active =
  game.tick, entity = event.entity }

  -- get data for platform
  local platform_data = storage.platforms_with_chests[event.platform.name]

  -- If this is the first chest placed on this platform initialize it
  if not platform_data then
    platform_data = initialize_platform(event.platform)
  end

  -- add to data for platform
  if event.entity.name == "orbital-transfer-requester" then
    table.insert(platform_data.requester_chests, event.entity)
    debug("Requester chests: " .. #platform_data.requester_chests)
  elseif event.entity.name == "orbital-transfer-provider" then
    table.insert(platform_data.provider_chests, event.entity)
    debug("Provider chests: " .. #platform_data.provider_chests)
  end
end

local function rescan_requester_chests(platform)
  local platform_data = storage.platforms_with_chests[platform.name]
  local matching_chests = platform.surface.find_entities_filtered { name = "orbital-transfer-requester" }
  platform_data.requester_chests = matching_chests
  debug("Requester chests: " .. #platform_data.requester_chests)
end

local function rescan_provider_chests(platform)
  local platform_data = storage.platforms_with_chests[platform.name]
  local matching_chests = platform.surface.find_entities_filtered { name = "orbital-transfer-provider" }
  platform_data.provider_chests = matching_chests
  debug("Provider chests: " .. #platform_data.provider_chests)
end

-- might want this later as sort of a "fixup"
local function rescan_platform(platform)
  rescan_requester_chests(platform)
  rescan_provider_chests(platform)
end

local function process_orbit(space_location_name, orbiting_platforms)
  debug("Processing orbit " .. space_location_name, true)

  -- {unit_number: {item, quality}}
  local available_by_unit_number = {}

  -- {unit_number: {item, quality, last_active}}
  local requested_by_unit_number = {}

  -- Get all available and requested items in this orbit
  for _, platform_name in pairs(orbiting_platforms) do
    local platform_data = storage.platforms_with_chests[platform_name]

    -- Get provided items on this platform
    for _, provider_chest in ipairs(platform_data.provider_chests) do
      local last_tick_active = storage.registered_chests[provider_chest.unit_number].last_tick_active

      if last_tick_active <= game.tick - settings.global["orbital-transfer-delivery-delay"].value then
        local inventory = provider_chest.get_inventory(defines.inventory.chest)

        if not inventory.is_empty() then
          local stack = inventory[1]

          if stack.count >= prototypes["item"][stack.name].stack_size then
            available_by_unit_number[provider_chest.unit_number] = { item = stack.name, quality = stack.quality.name }
          end
        end
      else 
        debug("skipping provider due to cooldown " .. provider_chest.unit_number, true)
      end
    end

    --requested items on this platform
    for _, requester_chest in ipairs(platform_data.requester_chests) do
      local last_tick_active = storage.registered_chests[requester_chest.unit_number].last_tick_active
      
      if last_tick_active <= game.tick - settings.global["orbital-transfer-delivery-delay"].value then
        local inventory = requester_chest.get_inventory(defines.inventory.chest)
        local contents = inventory.get_contents()

        -- Dont request if not empty
        if not contents[1] then
          -- yep, I'm abusing storage filter as a request since I want to only allow one request at a time.
          -- may be another way to do this, but this seems to work
          local filters = requester_chest.get_logistic_point(defines.logistic_member_index.logistic_container).get_section(1).filters

          if filters[1] then
            local requested_item = filters[1].value.name
            local requested_quality = filters[1].value.quality

            local request = {
              item = requested_item,
              quality = requested_quality,
              last_active = storage.registered_chests[requester_chest.unit_number].last_tick_active
            }
            requested_by_unit_number[requester_chest.unit_number] = request
          end
        end
      else 
        debug("skipping requester due to cooldown " .. requester_chest.unit_number, true)
      end
    end
  end

  debug("Available: " .. serpent.block(available_by_unit_number), true)
  debug("Requested: " .. serpent.block(requested_by_unit_number), true)

  -- Order requests by last_tick_active
  local ordered_requests = {}
  for key in pairs(requested_by_unit_number) do
    table.insert(ordered_requests, key)
  end

  table.sort(ordered_requests,
    function(a, b) return requested_by_unit_number[a].last_active < requested_by_unit_number[b].last_active end)


  -- Map requests to available in order
  for _, request_unit_number in ipairs(ordered_requests) do
    local request = requested_by_unit_number[request_unit_number]
    -- game.print("Evaluating request " .. request_unit_number)

    -- search for provider for this request
    for available_unit_number, available in pairs(available_by_unit_number) do
      debug("Comparing " .. serpent.line(request) .. serpent.line(available), true)
      if available.item == request.item and available.quality == request.quality then
        debug("Potentially matched request " .. request_unit_number .. " to provider " .. available_unit_number, true)
        -- Provider matches, make sure it isn't on the same platform

        local requester_chest = storage.registered_chests[request_unit_number].entity
        local provider_chest = storage.registered_chests[available_unit_number].entity

        -- game.print("Surface Forces " .. serpent.line(provider_chest.force == requester_chest.force) .. " request " .. serpent.line(requester_chest.force) .. " to provider " .. serpent.line(provider_chest.force))

        if (provider_chest.surface_index ~= requester_chest.surface_index) then
          if (provider_chest.force == requester_chest.force) then
            -- match made in heaven
            available_by_unit_number[available_unit_number] = nil
            local provided_item_stack = provider_chest.get_inventory(defines.inventory.chest)[1]
            
            debug("Transferring!", true)
            local transit_inventory = game.create_inventory(1)
            local transit_item_stack = transit_inventory[1]

            provided_item_stack.swap_stack(transit_item_stack)

            flib_on_tick_n.add(game.tick + settings.global["orbital-transfer-delivery-delay"].value, {
              type = "delivery",
              target = requester_chest,
              transit_inventory = transit_inventory
            })

            storage.registered_chests[request_unit_number].last_tick_active = game.tick
            storage.registered_chests[available_unit_number].last_tick_active = game.tick         
          else
            debug("Forces don't match", true)
          end
        else
          debug("Not on different platform", true)
        end
      end
    end
  end
end

script.on_nth_tick(settings.global["orbital-transfer-tick-rate"].value --[[@as integer]], function(event)
  -- game.print("Tick! " .. serpent.block(storage.platforms_by_space_location))

  for space_location_name, orbiting_platforms in pairs(storage.platforms_by_space_location) do
    process_orbit(space_location_name, orbiting_platforms)
  end
end)

local function handleTask(task)  
  if task.type == "delivery" then
    local transit_stack = task.transit_inventory[1]
    if task.target.valid then      
      debug("Delivering " .. transit_stack.count .. " " .. transit_stack.name .. ' to ' .. task.target.name .. ' on ' .. task.target.surface.platform.name, true)
      
      -- deliver to output inventory just in case another delivery arrived before this one was removed 
      local delivery_inventory = task.target.get_output_inventory()
      delivery_inventory.insert(transit_stack)
      task.transit_inventory.destroy()

      -- not sure if getting script inventories is expensive so wrap this in another check
      if settings.global["orbital-transfer-deep-debug"].value then
        debug("Transit inventories remaining: " .. #game.get_script_inventories('orbital-transfer'), true)
      end
    else      
      debug("Requester chest removed before delivery completed, " .. transit_stack.count .. " " .. transit_stack.name .. " lost in space.")
      task.transit_inventory.destroy()
    end
  end
end

script.on_event(defines.events.on_tick, function(event)
  for _, task in pairs(flib_on_tick_n.retrieve(event.tick) or {}) do
    if type(task)=="table" and task.type then
      handleTask(task)
    end
  end
end)

script.on_event(defines.events.on_space_platform_built_entity, register_transfer_chest,
  {
    { filter = "name", name = "orbital-transfer-requester" },
    { filter = "name", name = "orbital-transfer-provider" }
  })

local function deregister_transfer_chest(name, platform_name)
  debug("Removed chest on platform " .. platform_name)
  local platform_data = storage.platforms_with_chests[platform_name]

  -- Rescan to see what is still there since we don't know the entity removed
  if name == "orbital-transfer-requester" then
    rescan_requester_chests(platform_data.platform)
  elseif name == "orbital-transfer-provider" then
    rescan_provider_chests(platform_data.platform)
  end
end

local function on_object_destroyed(event)
  local chest = storage.registered_chests[event.useful_id]
  if chest then
    storage.registered_chests[event.useful_id] = nil
    deregister_transfer_chest(chest.name, chest.platform_name)
  end
end

script.on_event(defines.events.on_object_destroyed, on_object_destroyed)

script.on_event(defines.events.on_space_platform_changed_state, function(event)
  local platform = event.platform
  local platform_data = storage.platforms_with_chests[event.platform.name]

  -- if this platform has no chests, don't worry about it.
  -- This should also filter out new platforms etc
  if not platform_data then return end

  -- if there is no space location or it is waiting to depart, and we had a location for it already,
  -- exit it from orbit in our system
  if (not platform.space_location or platform.state == defines.space_platform_state.waiting_for_departure)
      and platform_data.latest_location then
    space_platform_exit_orbit(platform, platform_data)

    -- Otherwise, if we didn't already have a location, enter the orbit.
  elseif not platform_data.latest_location then
    space_platform_enter_orbit(platform, platform_data)
  end
end)

script.on_init(function()
  flib_on_tick_n.init()
  storage.platforms_by_space_location = {}
  -- {"space_location_name": {"platform-name", .. more platforms ..}, .. more locations
  storage.platforms_with_chests = {}
  -- {"platform-name": {platform: platform_entity, latest_location: space_location, requester_chests: {entities}, provider_chests: {entities}}
  storage.registered_chests = {}
  -- {unit_number: {entity, platform, last_tick_active}}
end)
