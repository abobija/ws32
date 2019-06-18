# ws32
ESP32 Lua NodeMCU WebSocket Client Library

## Demo
[![WebSocket Client, Programming ESP32 in Lua](https://img.youtube.com/vi/Tb3L4UcjlI4/mqdefault.jpg)](https://www.youtube.com/watch?v=Tb3L4UcjlI4)

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
