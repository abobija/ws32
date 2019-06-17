M = {}

local socket = nil
local on_connect_callback = nil
local on_data_callback = nil

M.on = function(callback_str, callback_foo)
    if callback_str == 'connect' then
        on_connect_callback = callback_foo
    elseif callback_str == 'data' then
        on_data_callback = callback_foo
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
    -- FIN. 1 means msg is complete. 0 means multi-part
    fin = frame:byte(1)
    fin = bit.isset(fin, 7)
    
    local opcode = frame:byte(1)
    opcode = bit.clear(opcode, 4, 5, 6, 7)
    print("Opcode:", opcode)
    
    -- get 2nd byte as it has the payload length
    -- msb of byte is mask, remaining 7 bytes is len 
    local plen = frame:byte(2)
    local mask = bit.isset(plen, 7)
    
    plen = bit.clear(plen, 7) -- remove the mask from the length
    len_expected = plen
    
    if mask then 
      -- print("We should not get a mask from server. Error.")
      return
    end
    
    data = string.sub(frame, 3) -- remove first 2 bytes, i.e. start at 3rd char
  
    if plen == 126 then 
      local extlen = frame:byte(3)
      local extlen2 = frame:byte(4)
      
      extlen = bit.lshift(extlen, 8)
      
      len_expected = extlen + extlen2
      
      data = string.sub(data, 3) -- remove first 2 bytes
      
    elseif plen == 127 then 
      -- print("Websocket lib does not support longer payloads yet")
      -- return
      data = string.sub(data, 5) -- remove first 4 bytes
    end
    
    -- set the buffer to the current data since it's new
    buffer = data
  end 
  
  len_expected = len_expected - #data
  
  if len_expected <= 0 then
    len_expected = 0
    
    if on_data_callback ~= nil then 
      on_data_callback(buffer)
    end
    
    buffer = ''
  end
end

M.connect = function(ws_url)
    local host, port, path = string.match(ws_url, 'ws://(.-):(.-)/(.*)')
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
        .. "\r\n"
    
    socket = net.createConnection(net.TCP)

    socket:on("sent", function()
        print("socket:sent")
    end)
    
    socket:on('disconnection', function(errcode)
        print("socket:disconnection", errcode)
    end)
    
    socket:on('reconnection', function(errcode)
        print('Reconnection. err:', errcode)
    end)
    
    socket:on("connection", function(sck)
        print("soket:connection")
        socket:send(handshake)
    end)

    socket:on("receive", function(sck, data) 
        print('socket:receive')
        print(data)
    
        if is_header_received == false then
            if string.match(data, "HTTP/1.1 101(.*)\r\n\r\n") then 
                is_header_received = true
                print('handshake done')
                
                if on_connect_callback ~= nil then
                    on_connect_callback(M)
                end
            end
        else
            decode_frame(data)
        end
    end)

    socket:connect(port, host)
end

M.send = function(data)
    print("send", data)
    
    --if m.isConnected == false then 
    --print("Websocket not connected, so cannot send.")
    --return
    --end 
    
    local binstr, payload_len 
    
    if #data > 126 then 
        print("Lib only supports max len 126 currently")
        return
    end

    -- set FIN to 1 meaning we will not multi-part this msg
    binstr = string.char(bit.set(0x1, 7)) 
    
    -- 2nd byte mask and payload length
    payload_len = #data
    payload_len = bit.set(payload_len, 7) -- set mask to on for 8th msb
    binstr = binstr .. string.char(payload_len)
    
    -- 3rd, 4th, 5th, and 6th byte is masking key
    -- just use mask of 0 to cheat so no need to xor
    binstr = binstr .. string.char(0x0, 0x0, 0x0, 0x0)
    
    binstr = binstr .. data
    
    socket:send(binstr)
end

return M