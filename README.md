# ws32
ESP32 Lua NodeMCU WebSocket Client Library

## Usage

```lua
  require('ws32_client')
  .on('connection', function(ws)
      print('WS connected')
      ws.send('Hello!')
  end)
  .on('receive', function(data, ws)
      print('WS received:', data)
  end)
  .connect('ws://demos.kaazing.com:80/echo')
```

## Dependencies

The library depends on the following NodeMCU modules:

  - `bit`
  - `net`
