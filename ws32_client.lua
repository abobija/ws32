local M = {}

M.Opcode = {
   -- ContinuationFrame = 0,
   TextFrame = 1,
   -- BinaryFrame = 2,
   -- ConnectionCloseFrame = 8,
   PingFrame = 9,
   PongFrame = 10
}

local socket = nil
local is_connected = false
local on_connection_callback = nil
local on_receive_callback = nil
local on_disconnection_callback = nil

M.on = function(callback_str, callback_foo)
    if callback_str == 'connection' then
        on_connection_callback = callback_foo
    elseif callback_str == 'receive' then
        on_receive_callback = callback_foo
    elseif callback_str == 'disconnection' then
        on_disconnection_callback = callback_foo
    end
    
    return M
end

local len_expected = 0
local buffer = ''

local function decode_frame(frame)
    local data, fin
    
    if len_expected > 0 then
        data = frame 
        buffer = buffer .. data
    else
        fin = frame:byte(1)
        fin = bit.isset(fin, 7)
    
        local opcode = frame:byte(1)
        opcode = bit.clear(opcode, 4, 5, 6, 7)
        
        -- print("Opcode:", opcode)

        if opcode == M.Opcode.PingFrame then
            M.send('', M.Opcode.PongFrame)
            return
        end
    
        local plen = frame:byte(2)
        local mask = bit.isset(plen, 7)
    
        plen = bit.clear(plen, 7)
        len_expected = plen
    
        if mask then
            return
        end
    
        data = frame:sub(3)
    
        if plen == 126 then 
            local extlen = frame:byte(3)
            local extlen2 = frame:byte(4)
        
            extlen = bit.lshift(extlen, 8)
        
            len_expected = extlen + extlen2
        
            data = data:sub(3)
        elseif plen == 127 then
            data = data:sub(5)
        end
    
        buffer = data
    end 
    
    len_expected = len_expected - #data
    
    if len_expected <= 0 then
        len_expected = 0
    
        if on_receive_callback ~= nil then 
            on_receive_callback(buffer, M)
        end
    
        buffer = ''
    end
end

M.send = function(data, opcode)
    opcode = opcode or M.Opcode.TextFrame
    
    if is_connected == false then 
        print("[WebSocket] Not connected, so cannot send.")
        return
    end 
    
    if #data > 126 then 
        print("[WebSocket] Lib only supports max len 126 currently")
        return
    end
    
    local binstr, payload_len

    payload_len = #data
    payload_len = bit.set(payload_len, 7)
    
    binstr = string.char(bit.set(opcode, 7))
        .. string.char(payload_len)
        .. string.char(0x0, 0x0, 0x0, 0x0)
        .. data
    
    socket:send(binstr)
end

local function extend(tbl, with)
    if with ~= nil then
        for k, v in pairs(with) do
            tbl[k] = with[k]
        end
    end

    return tbl
end

M.reconnect = function()
    tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
        M.connect(M.url, M.options)
    end)
end

M.connect = function(url, options)
    M.url = url
    
    M.options = extend({
        auto_reconnect = false,
        extra_handshake_headers = {}
    }, options)
    
    if M.url:sub(-1) ~= '/' then
        M.url = M.url .. '/'
    end

    local host, port, path = string.match(M.url, 'ws://(.-):(.-)/(.*)')
    local is_header_received = false
    
    local handshake = 
        'GET /' .. path .. " HTTP/1.1\r\n"
        .. "Host: " .. host .. "\r\n"
        .. "Upgrade: websocket\r\n"
        .. "Connection: Upgrade\r\n"
        .. "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r\n"
        .. "Sec-WebSocket-Protocol: chat, superchat\r\n"
        .. "Sec-WebSocket-Version: 13\r\n"
        .. "Origin: esp32\r\n"

    for _, hdr in pairs(M.options.extra_handshake_headers) do
        handshake = handshake .. hdr[1] .. ': ' .. hdr[2] .. "\r\n"
    end
    
    handshake = handshake .. "\r\n"
    
    socket = net.createConnection(net.TCP)

    --socket:on("sent", function()
    --     print("[WebSocket]:sent")
    --end)

    local on_disconnection = function(errcode)
        is_connected = false
        is_header_received = false

        if on_disconnection_callback ~= nil then
            on_disconnection_callback(errcode, M)
        end

        if M.options.auto_reconnect then
            M.reconnect()
        end
    end
    
    socket:on('disconnection', on_disconnection)
    
    socket:on('reconnection', on_disconnection)
    
    socket:on("connection", function(sck)
        socket:send(handshake)
    end)
    
    socket:on("receive", function(sck, data)
        if is_header_received == false then
            if string.match(data, "HTTP/1.1 101(.*)\r\n\r\n") then 
                is_header_received = true
                is_connected = true
                
                if on_connection_callback ~= nil then
                    on_connection_callback(M)
                end
            end
        else
            decode_frame(data)
        end
    end)

    socket:connect(port, host)
end

return M
