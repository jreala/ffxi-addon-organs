require('tables')


local participating_characters = nil

local function exec(participant, msg)
    windower.send_ipc_message('execute '..participant..' '..msg)
end

-- send a message to all 'particiants' with the given delay between them.
function send_all(msg, delay, participants)
    if participants == nil then
        participants = get_participants()
    end

    local total_delay = 0
    for _,c in ipairs(participants) do
        if c == windower.ffxi.get_mob_by_target('me').name then
            handle_addon_command:schedule(total_delay, msg)
        else
            exec:schedule(total_delay, c, msg)
        end
        total_delay = total_delay + delay
    end
end

-- Function to catch the send-all exec. Handle whatever you need to do in this function. Either in this file, or in the main file.
function handle_addon_command(msg)
    print('handle_addon_command not overridden! msg: '..msg)
end

local function ping()
    local player = windower.ffxi.get_mob_by_target('me').name
    participating_characters = T{}
    participating_characters:append(player)
    windower.send_ipc_message('ping '..player)
end

-- send an IPC message to all local clients and record which come back.
function get_participants()
    ping()
    coroutine.sleep(0.1)

    local r = participating_characters:copy()
    participating_characters = nil
    return r
end


-- handle the ipc messages. 
windower.register_event('ipc message', function(msg) 
    local args = msg:split(' ')
    local cmd = args[1]
    args:remove(1)
    local player = windower.ffxi.get_mob_by_target('me') and windower.ffxi.get_mob_by_target('me').name

    if cmd == 'ping' then
        windower.send_ipc_message('pong '..player)

    elseif cmd == 'pong' then
        if participating_characters ~= nil then 
            participating_characters:append(args[1])
        end
    elseif cmd == 'execute' and args[1] == player then
        args:remove(1)
        handle_addon_command(args:concat(' '))
    end
end)