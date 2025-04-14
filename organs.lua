--[[

Copyright © 2025, Syzak
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of <addon name> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]

_addon.name = "organs"
_addon.author = "Syzak"
_addon.version = "2025.04.13.a"
_addon.commands = { "organs", "obis", "gorgets" }

require("luau")
require("sendall")
packets = require('packets')

local defaults = {
  debug = false,
  debug_area = "log",   -- log | console
  info_area = "log",    -- log | console
  lot = false,          -- true | false
  lot_delay = 2,        -- delay in seconds between rolling on an item when it hits the pool
  send_all_delay = 0.5, -- delay in seconds between sending messages to all characters
  tracking = "both",    -- both | obi | gorget
  command_on_done = "", -- command to run when all items are obtained. Not yet implemented
  pass_on_done = true,  -- pass organs once all are obtained for the current tracking method
}

local isRunning = false

local settings = config.load(defaults)
if settings.send_all_delay < 0 then
  settings.send_all_delay = 0
end
if settings.send_all_delay > 5 then
  settings.send_all_delay = 5
end

local organs = T {
  ["aern organ"] = 1786,
  ["hpemde organ"] = 1787,
  ["luminian tissue"] = 1783,
  ["phuabo organ"] = 1784,
  ["xzomit organ"] = 1785,
  ["yovra organ"] = 1788,
}

-- Gorgets and their associated costs
local gorgets = T {
  ["flame gorget"] = T {
    ["phuabo organ"] = 10,
    ["xzomit organ"] = 5,
    ["yovra organ"] = 1,
  },
  ["soil gorget"] = T {
    ["aern organ"] = 5,
    ["xzomit organ"] = 10,
    ["yovra organ"] = 1,
  },
  ["aqua gorget"] = T {
    ["aern organ"] = 10,
    ["hpemde organ"] = 5,
    ["yovra organ"] = 1,
  },
  ["breeze gorget"] = T {
    ["hpemde organ"] = 5,
    ["phuabo organ"] = 10,
    ["yovra organ"] = 1,
  },
  ["snow gorget"] = T {
    ["aern organ"] = 5,
    ["phuabo organ"] = 10,
    ["yovra organ"] = 1,
  },
  ["thunder gorget"] = T {
    ["hpemde organ"] = 5,
    ["xzomit organ"] = 10,
    ["yovra organ"] = 1,
  },
  ["light gorget"] = T {
    ["aern organ"] = 7,
    ["hpemde organ"] = 3,
    ["phuabo organ"] = 3,
    ["yovra organ"] = 2,
  },
  ["shadow gorget"] = T {
    ["aern organ"] = 3,
    ["hpemde organ"] = 7,
    ["phuabo organ"] = 3,
    ["yovra organ"] = 2,
  }
}

-- Obis and their associated costs
local obis = T {
  ["karin obi"] = T {
    ["luminian tissue"] = 3,
    ["phuabo organ"] = 7,
    ["xzomit organ"] = 3,
  },
  ["dorin obi"] = T {
    ["aern organ"] = 3,
    ["hpemde organ"] = 7,
    ["luminian tissue"] = 3,
  },
  ["suirin obi"] = T {
    ["hpemde organ"] = 7,
    ["phuabo organ"] = 5,
    ["luminian tissue"] = 3,
  },
  ["furin obi"] = T {
    ["aern organ"] = 7,
    ["hpemde organ"] = 3,
    ["luminian tissue"] = 3,
  },
  ["hyorin obi"] = T {
    ["xzomit organ"] = 7,
    ["phuabo organ"] = 3,
    ["luminian tissue"] = 3,
  },
  ["rairin obi"] = T {
    ["hpemde organ"] = 3,
    ["phuabo organ"] = 7,
    ["luminian tissue"] = 3,
  },
  ["korin obi"] = T {
    ["aern organ"] = 3,
    ["xzomit organ"] = 7,
    ["luminian tissue"] = 3,
  },
  ["anrin obi"] = T {
    ["aern organ"] = 7,
    ["xzomit organ"] = 3,
    ["luminian tissue"] = 3,
  }
}

-- List of gorgets and obis already obtained
local inventory_items = T {}
local items_needed = T {}
local organs_required = T {}
local has_fotia = false
local has_hachirin = false

local lot_list = L {}
local pass_list = L {}

local inventory_id = res.bags:with('english', 'Inventory').id

-- borrowed from Treasury
function act(action, output, id, ...)
  if settings.debug then
    debug(output .. ' ' .. res.items[id].name)
  end
  windower.ffxi[action]:prepare(...):schedule((math.random() + 1) / 2 * settings.lot_delay)
end

local pass = act + { 'pass_item', 'Passing' }
local lot = act + { 'lot_item', 'Lotting' }

local storages_order_tokens = L { 'inventory', 'wardrobe', 'wardrobe 2', 'wardrobe 3', 'wardrobe 4', 'wardrobe 5', 'wardrobe 6', 'wardrobe 7', 'wardrobe 8', 'safe', 'safe 2', 'storage', 'locker', 'satchel', 'sack', 'case' }
local storages_order = S(res.bags:map(string.gsub - { ' ', '' } .. string.lower .. table.get - { 'english' })):sort(function(
    name1, name2)
  local index1 = storages_order_tokens:find(name1)
  local index2 = storages_order_tokens:find(name2)

  if not index1 and not index2 then
    return name1 < name2
  end

  if not index1 then
    return false
  end

  if not index2 then
    return true
  end

  return index1 < index2
end)

function command_start()
  debug('command start')
  isRunning = true
  command_analyze()
  command_list()
end

function command_stop()
  debug('command stop')
  isRunning = false
end

function command_analyze()
  debug('command analyze')
  if not isRunning then
    log('Please start the addon first.')
    return
  end

  local inventory = windower.ffxi.get_items()

  if not inventory then
    return
  end

  -- reset tables
  reset_analysis()

  local gorget_list = get_key_list(gorgets)
  local obi_list = get_key_list(obis)
  local organ_list = get_key_list(organs)

  -- build list of items in bags
  for _, storage_name in ipairs(storages_order) do
    for _, data in ipairs(inventory[storage_name]) do
      if type(data) == 'table' then
        if data.id ~= 0 then
          local itemName = res.items[data.id].en:lower()
          -- check for gorgets
          if (itemName == "fotia gorget") then
            debug("Fotia gorget found in inventory.")
            has_fotia = true
          end

          if (itemName == "hachirin-no-obi") then
            debug("Hachirin-no-obi found in inventory.")
            has_hachirin = true
          end

          if (settings.tracking == "both" or settings.tracking == "gorget") and gorget_list:contains(itemName) then
            if inventory_items[itemName] then
              debug("Found " .. itemName .. ", updating inventory_items with count" .. data.count)
              inventory_items[itemName] = inventory_items[itemName] + data.count
            else
              debug("Adding " .. itemName .. " to inventory_items with count " .. data.count)
              inventory_items[itemName] = data.count
            end
          end
          -- check for obis
          if (settings.tracking == "both" or settings.tracking == "obi") and obi_list:contains(itemName) then
            if inventory_items[itemName] then
              debug("Found " .. itemName .. ", updating inventory_items with count" .. data.count)
              inventory_items[itemName] = inventory_items[itemName] + data.count
            else
              debug("Adding " .. itemName .. " to inventory_items with count " .. data.count)
              inventory_items[itemName] = data.count
            end
          end
          -- check for organs
          if (organ_list:contains(itemName)) then
            if inventory_items[itemName] then
              debug("Found " .. itemName .. ", updating inventory_items with count" .. data.count)
              inventory_items[itemName] = inventory_items[itemName] + data.count
            else
              debug("Adding " .. itemName .. " to inventory_items with count " .. data.count)
              inventory_items[itemName] = data.count
            end
          end
        end
      end
    end
  end

  -- add gorgets to items_needed
  if settings.tracking == "gorget" or settings.tracking == "both" then
    if not has_fotia then
      local cloned_gorgets = gorgets:copy()
      for item, _val in pairs(inventory_items) do
        if gorget_list:contains(item) then
          cloned_gorgets[item] = nil
        end
      end
      debug("Adding gorgets to items_needed:")
      debug(cloned_gorgets)
      items_needed:amend(cloned_gorgets)
    else
      debug("Fotia gorget is already obtained, no need to track gorgets.")
    end
  end

  -- add obis to items_needed
  if settings.tracking == "obi" or settings.tracking == "both" then
    if not has_hachirin then
      local cloned_obis = obis:copy()
      for item, _val in pairs(inventory_items) do
        if obi_list:contains(item) then
          cloned_obis[item] = nil
        end
      end
      debug("Adding obis to items_needed")
      debug(cloned_obis)
      items_needed:amend(cloned_obis)
    else
      debug("Hachirin-no-obi is already obtained, no need to track obis.")
    end
  end

  debug('Total organs needed for missing equipment:')
  debug(items_needed:flatten_and_sum())

  if items_needed:length() == 0 then
    log('No items needed for ' .. settings.tracking)
    return
  end

  -- create a copy for record keeping
  organs_required = items_needed:copy():flatten_and_sum()

  -- subtract organs in inventory from items_needed
  for item, _val in pairs(inventory_items) do
    if organ_list:contains(item) then
      if organs_required[item] then
        organs_required[item] = organs_required[item] - inventory_items[item]
      end
    end
  end
  debug('Total organs needed after subtracting inventory: ')
  debug(organs_required)

  -- update lot list
  if settings.lot then
    for item in organ_list:it() do
      if organs_required[item] and organs_required[item] > 0 then
        debug('Adding ' .. item .. ' to lotting list for ' .. settings.tracking .. ' : ' .. organs[item])
        lot_list:append(organs[item])
      end
    end
  end

  -- update pass list
  if settings.pass_on_done then
    for item in organ_list:it() do
      if not organs_required[item] or organs_required[item] <= 0 then
        debug('Adding ' .. item .. ' to passing list for ' .. settings.tracking .. ' : ' .. organs[item])
        pass_list:append(organs[item])
      end
    end
  end

  debug('Lot list: ')
  debug(lot_list)
  debug('pass list: ')
  debug(pass_list)
end

function command_track(tracking)
  debug('command track')
  if not tracking then
    log('Please specify a tracking method: both, gorgets, or obis.')
    return
  end

  reset_analysis()

  if tracking == 'both' then
    debug('command tracking both')
    settings.tracking = 'both'
    settings:save()
  elseif tracking == 'gorget' then
    debug('command tracking gorgets')
    settings.tracking = 'gorget'
    settings:save()
  elseif tracking == 'obi' then
    debug('command tracking obis')
    settings.tracking = 'obi'
    settings:save()
  else
    log('Invalid tracking method. Please specify: both, gorget, or obi.')
    return
  end
end

function command_lot()
  settings.lot = not settings.lot
  if settings.lot then
    log('Lotting is now enabled.')
  else
    log('Lotting is now disabled.')
  end
  settings:save()
end

function command_debug(area)
  if settings.debug then
    settings.debug = false
    log('Debugging is now disabled.')
  else
    settings.debug = true
    log('Debugging is now enabled.')
  end
  if area == 'log' then
    settings.debug_area = 'log'
    log('Debugging output is now set to log.')
  elseif area == 'console' then
    settings.debug_area = 'console'
    log('Debugging output is now set to console.')
  end
  settings:save()
end

function command_list()
  log('Tracking: ' .. settings.tracking)
  log('Lotting: ' .. tostring(settings.lot))

  if (not organs_required or organs_required:length() == 0) then
    debug('Command list was run before analyze. Analyzing now...')
    command_analyze()
  end

  if not isRunning then
    return
  end

  log('Organs required: ')
  log(organs_required)
end

windower.register_event('addon command', function(...)
  local args = T { ... }

  for i, v in pairs(args) do args[i] = windower.convert_auto_trans(args[i]) end

  local to_all = args[1] and T { "all", "a", "@all" }:contains(args[1]:lower())
  local to_party = args[1] and T { 'party', 'p', '@party' }:contains(args[1]:lower())

  if to_all or to_party then
    args:remove(1)

    local characters = get_participants()
    if to_all then
      debug('sending command to all: ' .. args:concat(' '))
      characters = get_participants()
    elseif to_party then
      debug('sending command to party: ' .. args:concat(' '))
      characters = get_party_members(get_participants())
    end

    send_all(args:concat(' '), settings.send_all_delay, characters)
    return
  end

  handle_addon_command(args:concat(' '))
end)

function handle_addon_command(args)
  local args = args:split(' ')
  local cmd = args[1]
  args:remove(1)

  if cmd == 'start' then
    command_start()
  elseif cmd == 'stop' then
    command_stop()
  elseif cmd == 'analyze' then
    command_analyze()
  elseif cmd == 'track' then
    command_track(args[1])
  elseif cmd == 'lot' then
    command_lot()
  elseif cmd == 'list' then
    command_list()
  elseif cmd == 'infoarea' then
    if args[1] == 'log' or args[1] == 'console' then
      settings.info_area = args[1]
      settings:save()
      log('Info area set to ' .. args[1])
    else
      log('Invalid info area. Please specify: log or console.')
    end
  elseif cmd == 'debug' then
    command_debug(args[1])
  else
    debug('invalid command... ' .. cmd .. ' ' .. args.concat(' '))
  end
end

windower.register_event('incoming chunk', function(id, data)
  if not isRunning then
    return
  end

  if id == 0x0D2 then                                        -- found item packet
    local treasure = packets.parse('incoming', data)
    check_treasure_conditions(treasure.Index, treasure.Item) -- pool index, item id
  elseif id == 0x020 then                                    -- item update packet
    local chunk = packets.parse('incoming', data)

    -- Ignore items in other bags
    if chunk.Bag ~= inventory_id then
      return
    end

    if id == 0x020 and chunk.Status == 0 then
      -- handle the items needed update logic here
      if lot_list:contains(chunk.Item) then
        local item_name = organs:find(chunk.Item)
        debug('Obtained ' .. chunk.Count .. ' ' .. item_name .. '.')
        organs_required[item_name] = organs_required[item_name] - chunk.Count
        log('Updated organs_required: ')
        log(organs_required)
      end
    end
  end
end)

-- Helper functions below
function reset_analysis()
  debug('reset analysis')
  inventory_items = T {}
  items_needed = T {}
  organs_required = T {}
  lot_list = L {}
  pass_list = L {}
  has_fotia = false
  has_hachirin = false
end

-- borrowed from Treasury
function check_treasure_conditions(slot_index, item_id)
  if (pass_list:contains(item_id)) and not lot_list:contains(item_id) then
    pass(item_id, slot_index)
  elseif lot_list:contains(item_id) then
    local inventory = windower.ffxi.get_items(inventory_id)
    if inventory.max - inventory.count > 1 then
      lot(item_id, slot_index)
    end
  end
end

function log(msg)
  if settings.info_area == 'log' or settings.debug then
    if type(msg) == "table" then
      for key, value in pairs(msg) do
        windower.add_to_chat(80, '    ' .. tostring(key) .. ' : ' .. tostring(value))
      end
    elseif type(msg) == "number" then
      windower.add_to_chat(80, tostring(msg))
    elseif type(msg) == "string" then
      windower.add_to_chat(80, msg)
    elseif type(msg) == "boolean" then
      windower.add_to_chat(80, tostring(msg))
    else
      windower.add_to_chat(80, 'Unknown Debug Message')
    end
  elseif settings.info_area == 'console' then
    if type(msg) == "table" then
      for key, value in pairs(msg) do
        print('    ' .. tostring(key) .. ' : ' .. tostring(value))
      end
    elseif type(msg) == "number" then
      print(tostring(msg))
    elseif type(msg) == "string" then
      print(msg)
    elseif type(msg) == "boolean" then
      print(tostring(msg))
    else
      print('Unknown Debug Message')
    end
  end
end

function debug(msg)
  if settings.debug then
    log(msg)
  end
end

function get_party_members(local_members)
  local members = T {}
  for k, v in pairs(windower.ffxi.get_party()) do
    if type(v) == 'table' then
      if local_members:contains(v.name) then
        members:append(v.name)
      end
    end
  end

  return members
end

function table.flatten_and_sum(t, result)
  result = result or T {}

  for key, value in pairs(t) do
    if type(value) == "table" then
      -- Recursively flatten nested tables
      table.flatten_and_sum(value, result)
    else
      -- Sum values for similar keys
      result[key] = (result[key] or 0) + value
    end
  end

  return result
end

function get_key_list(t)
  local keys = L {}
  for k, _ in pairs(t) do
    keys:append(k)
  end
  return keys
end
