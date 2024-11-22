local function debug(message, deep)
  if (not deep and settings.global["orbital-transfer-debug"].value) or settings.global["orbital-transfer-deep-debug"].value then
    game.print(message)
  end
end

local DELIVERY_LAUNCH_HEIGHT = 10

-- ###############################################
-- ### PLATFORM TRACKING
-- ###############################################
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

-- ###############################################
-- ### CHEST (DE)REGISTRATION
-- ###############################################
local function register_transfer_chest(event)
  if not event.platform then
    -- handle edge cases where these were not built by a space platform for some reason
    -- (usually map editor)
    event.platform = event.entity.surface.platform

    if not event.platform then
      game.print("That belongs in a museu- er, a platform!")
      event.entity.destroy()
      return
    end
  end
  debug("Built " .. event.entity.name .. " on platform " .. event.platform.name)

  -- register destruction event
  local registration, unit_number, _ = script.register_on_object_destroyed(event.entity)
  storage.registered_chests[unit_number] = {
    platform_name = event.platform.name,
    name = event.entity.name,
    last_tick_active =
        game.tick,
    entity = event.entity
  }

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


-- ###############################################
-- ### ON NTH TICK (REQUEST HANDLING)
-- ###############################################
local function render_stack(stack, position, surface)
  local sprite_path = "item/" .. stack.name
  local sprite = rendering.draw_sprite {
    sprite = sprite_path,
    x_scale = 0.66,
    y_scale = 0.66,
    target = position,
    surface = surface,
    render_layer = "air-object",
    orientation = math.random(),
    -- These are destroyed anyway, this is just a backup
    time_to_live = (settings.global["orbital-transfer-delivery-delay"].value / 2) + 1
  }

  return sprite
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

    if not platform_data.platform or not platform_data.platform.valid then
      debug("Platform removed: " .. platform_name)

      for i, orbiting_platform_name in ipairs(orbiting_platforms) do
        if platform_name == orbiting_platform_name then
          table.remove(orbiting_platforms, i)
          break
        end
      end

      goto platform_continue
    end

    if platform_data.platform.scheduled_for_deletion > 0 then
      -- don't delete it from this system as it may be cancelled, just don't process it
      goto platform_continue
    end

    -- Get provided items on this platform
    for _, provider_chest in ipairs(platform_data.provider_chests) do
      if provider_chest and provider_chest.valid then
        local last_tick_active = storage.registered_chests[provider_chest.unit_number].last_tick_active

        if last_tick_active + 1 <= game.tick - settings.global["orbital-transfer-delivery-delay"].value then
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
    end

    --requested items on this platform
    for _, requester_chest in ipairs(platform_data.requester_chests) do
      if requester_chest and requester_chest.valid and requester_chest.unit_number then
        -- Note that this delay is critical to prevent another item from landing while the container is full and disappearing
        local last_tick_active = storage.registered_chests[requester_chest.unit_number].last_tick_active
        if last_tick_active + 1 <= game.tick - settings.global["orbital-transfer-delivery-delay"].value then
          local inventory = requester_chest.get_inventory(defines.inventory.chest)
          local contents = inventory.get_contents()

          -- Dont request if not empty
          if not contents[1] then
            -- yep, I'm abusing storage filter as a request since I want to only allow one request at a time.
            -- may be another way to do this, but this seems to work
            local filters = requester_chest.get_logistic_point(defines.logistic_member_index.logistic_container)
            .get_section(1).filters

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
      else
        debug("Requester chest invalidated: " .. serpent.line(requester_chest))
      end
    end

    ::platform_continue::
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

            -- put the item into the transfer inventory, that way spoilage etc is maintained and even keeps ticking
            provided_item_stack.swap_stack(transit_item_stack)

            -- create sprite
            local launch_position = { provider_chest.position.x, provider_chest.position.y - 0.5 }
            local sprite = render_stack(transit_item_stack, launch_position, provider_chest.surface)

            -- create the delivery
            table.insert(storage.deliveries, {
              target = requester_chest,
              force = requester_chest.force,
              transit_inventory = transit_inventory,
              tick_launched = game.tick,
              swapped_surface = false,
              sprite = sprite
            })

            storage.registered_chests[request_unit_number].last_tick_active = game.tick
            storage.registered_chests[available_unit_number].last_tick_active = game.tick

            -- Stop processing this request
            break
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

-- ###############################################
-- ### ON TICK
-- ###############################################

local function lostInTransit(delivery)
  -- prevent trying to delete the delivery twice so I don't have to care about calling this multiple times
  if not delivery.lost then
    delivery.lost = true
    local transit_stack = delivery.transit_inventory[1]
    delivery.force.print(
      "Warning: " .. transit_stack.count .. " " .. transit_stack.name .. " lost in space due to delivery target removal.")
    delivery.transit_inventory.destroy()
  end
end

local function completeDelivery(delivery)
  if delivery.target.valid then
    local transit_stack = delivery.transit_inventory[1]
    debug(
    "Delivering " ..
    transit_stack.count ..
    " " .. transit_stack.name .. ' to ' .. delivery.target.name .. ' on ' .. delivery.target.surface.platform.name, true)

    -- deliver to output inventory just in case another delivery arrived before this one was removed
    local delivery_inventory = delivery.target.get_output_inventory()
    delivery_inventory.insert(transit_stack)
    delivery.transit_inventory.destroy()

    -- not sure if getting script inventories is expensive so wrap this in another check
    if settings.global["orbital-transfer-deep-debug"].value then
      debug("Transit inventories remaining: " .. #game.get_script_inventories('orbital-transfer'), true)
    end
  else
    lostInTransit(delivery)
  end
end

local function handleOutboundDeliveryTick(delivery)
  if game.tick >= delivery.tick_launched + (settings.global["orbital-transfer-delivery-delay"].value / 2) then
    delivery.sprite.destroy()

    if delivery.target and delivery.target.valid then
      local reentry_position = { delivery.target.position.x, delivery.target.position.y - 0.5 - DELIVERY_LAUNCH_HEIGHT }
      delivery.sprite = render_stack(delivery.transit_inventory[1], reentry_position, delivery.target.surface)
      delivery.sprite.color = { 0, 0, 0, 0 }
      delivery.swapped_surface = true
    else
      lostInTransit(delivery)
    end
  else
    local position = delivery.sprite.target.position or { 0, 0 }
    position.y = position.y - ((DELIVERY_LAUNCH_HEIGHT * 2) / settings.global["orbital-transfer-delivery-delay"].value)
    delivery.sprite.target = position

    if game.tick >= delivery.tick_launched + (settings.global["orbital-transfer-delivery-delay"].value / 4) then
      local color = delivery.sprite.color
      color.a = math.max(color.a - (4 / settings.global["orbital-transfer-delivery-delay"].value), 0)
      color.r = color.a
      color.g = color.a
      color.b = color.a
      delivery.sprite.color = color
    end
  end
end

local function handleInboundDeliveryTick(delivery)
  local position = delivery.sprite.target.position or { 0, 0 }
  position.y = position.y + ((DELIVERY_LAUNCH_HEIGHT * 2) / settings.global["orbital-transfer-delivery-delay"].value)
  delivery.sprite.target = position

  local color = delivery.sprite.color
  color.a = math.min(color.a + (4 / settings.global["orbital-transfer-delivery-delay"].value), 1)
  color.r = color.a
  color.g = color.a
  color.b = color.a
  delivery.sprite.color = color
end



script.on_event(defines.events.on_tick, function(event)
  if not storage.deliveries then storage.deliveries = {} end
  local still_valid_delivieries = {}

  -- Handle each delivery appropriately
  for _, delivery in pairs(storage.deliveries) do
    if game.tick > delivery.tick_launched + settings.global["orbital-transfer-delivery-delay"].value then
      if delivery.sprite and delivery.sprite.valid then
        delivery.sprite.destroy()
      end
      completeDelivery(delivery)
    else
      if not delivery.swapped_surface then
        handleOutboundDeliveryTick(delivery)
      else
        handleInboundDeliveryTick(delivery)
      end
      if not delivery.lost then
        table.insert(still_valid_delivieries, delivery)
      end
    end
  end

  storage.deliveries = still_valid_delivieries
end)


-- ###############################################
-- ### ON BUILT ENTITY
-- ###############################################

script.on_event(defines.events.on_built_entity, register_transfer_chest,
  {
    { filter = "name", name = "orbital-transfer-requester" },
    { filter = "name", name = "orbital-transfer-provider" }
  })
script.on_event(defines.events.on_space_platform_built_entity, register_transfer_chest,
  {
    { filter = "name", name = "orbital-transfer-requester" },
    { filter = "name", name = "orbital-transfer-provider" }
  })
script.on_event(defines.events.on_robot_built_entity, register_transfer_chest,
  {
    { filter = "name", name = "orbital-transfer-requester" },
    { filter = "name", name = "orbital-transfer-provider" }
  })

-- ###############################################
-- ### ON OBJECT DESTROYED
-- ###############################################

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


-- ###############################################
-- ### ON SPACE PLATFORM CHANGED STATE
-- ###############################################
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

    -- Otherwise, if we didn't already have a location and we're at one now, enter the orbit.
  elseif not platform_data.latest_location and platform.space_location then
    space_platform_enter_orbit(platform, platform_data)
  end
end)


-- ###############################################
-- ### ON INIT
-- ###############################################
script.on_init(function()
  storage.platforms_by_space_location = {}
  -- {"space_location_nam: {"platform-name", .. more platforms ..}, .. more locations
  storage.platforms_with_chests = {}
  -- {"platform-name": {platform: platform_entity, latest_location: space_location, requester_chests: {entities}, provider_chests: {entities}}
  storage.registered_chests = {}
  -- {unit_number: {entity, platform, last_tick_active}}
  storage.deliveries = {}
  -- {{tick_launched, target, transit_inventory}}
end)
