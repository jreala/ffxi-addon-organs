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
_addon.version = "0.0.1"
_addon.commands = { "organs", "obis", "gorgets" }

require("luau")
require("sendall")

local defaults = {
  debug = false,
  debug_area = "log",   -- log | console
  info_area = "log",    -- log | console
  lot = false,          -- true | false
  lot_delay = 2,        -- delay in seconds between rolling on an item when it hits the pool
  send_all_delay = 0.5, -- delay in seconds between sending messages to all characters
  tracking = "both",    -- both | obi | gorget
  command_on_done = "", -- command to run when all items are obtained
  pass_on_done = true,  -- pass organs once all are obtained for the current tracking method
}

local settings = config.load(defaults)
if settings.send_all_delay < 0 then
  settings.send_all_delay = 0
end
if settings.send_all_delay > 5 then
  settings.send_all_delay = 5
end

local organ_list = L {
  "aern organ",
  "hpemde organ",
  "luminian tissue",
  "phuabo organ",
  "xzomit organ",
  "yovra organ",
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

local gorget_list = L {
  "flame gorget",
  "soil gorget",
  "aqua gorget",
  "breeze gorget",
  "snow gorget",
  "thunder gorget",
  "light gorget",
  "shadow gorget",
  "fotia gorget",
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

local obi_list = L {
  "karin obi",
  "dorin obi",
  "suirin obi",
  "furin obi",
  "hyorin obi",
  "rairin obi",
  "korin obi",
  "anrin obi",
  "hachirin-no-obi",
}

-- List of gorgets and obis already obtained
local inventory_items = T {}
local items_needed = T {}
local organs_required = T {}
local has_fotia = false
local has_hachirin = false

local participating_characters = nil

local valid_commands = L {
  "start",
  "stop",
  "analyze",
  "track",
  "lot",
  "debug",
}

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
  command_analyze()
  command_list()
end

function command_stop()
  debug('command stop')
end

function command_analyze()
  debug('command analyze')
  local inventory = windower.ffxi.get_items()

  if not inventory then
    return
  end

  -- reset tables
  inventory_items = T {}
  items_needed = T {}
  organs_required = T {}

  -- build list of items in bags
  for _, storage_name in ipairs(storages_order) do
    for _, data in ipairs(inventory[storage_name]) do
      if type(data) == 'table' then
        if data.id ~= 0 then
          local itemName = res.items[data.id].en:lower()
          -- check for gorgets
          if (settings.tracking == "both" or settings.tracking == "gorget") and gorget_list:contains(itemName) then
            if (itemName == "fotia gorget") then
              debug("Fotia gorget found in inventory.")
              has_fotia = true
            end

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
            if (itemName == "hachirin-no-obi") then
              debug("Hachirin-no-obi found in inventory.")
              has_hachirin = true
            end

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

  -- create a copy for record keeping
  organs_required = items_needed:copy():flatten_and_sum()

  -- subtract organs in inventory from items_needed
  for item, _val in pairs(inventory_items) do
    if organ_list:contains(item) then
      if organs_required[item] then
        organs_required[item] = organs_required[item] - inventory_items[item]
      else
        organs_required[item] = -inventory_items[item]
      end
    end
  end
  debug('Total organs needed after subtracting inventory: ')
  debug(organs_required)
end

function command_track(tracking)
  if not tracking then
    log('Please specify a tracking method: both, gorgets, or obis.')
    return
  end
  if tracking == 'both' then
    debug('command tracking both')
  elseif tracking == 'gorget' then
    debug('command tracking gorgets')
  elseif tracking == 'obi' then
    debug('command tracking obis')
  end
end

function command_lot()
  debug('lot')
end

function command_debug()
  if settings.debug then
    settings.debug = false
    log('Debugging is now disabled.')
  else
    settings.debug = true
    log('Debugging is now enabled.')
  end
end

function command_list()
  log('Tracking: ' .. settings.tracking)
  if (organs_required:length() == 0) then
    debug('List run before analyze.')
    command_analyze()
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
  elseif cmd == 'debug' then
    command_debug()
  else
    debug('invalid command... ' .. cmd .. ' ' .. args.concat(' '))
  end
end

-- Helper functions below

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
    print('organs: ' .. msg)
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
  result = result or {}

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
