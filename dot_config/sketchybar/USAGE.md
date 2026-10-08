# Subscription quota

[SketchyUsage](https://github.com/raisedadead/SketchyUsage) shows the Claude and Codex quota. Install it and start its service:

```sh
brew install raisedadead/tap/sketchyusage
brew services start sketchyusage
```

The bar shows the remaining weekly quota: `96%`. The label is yellow at 25% or less, and red at 10% or less. `—` means that the weekly limit is missing or its reset has passed. `!` marks a fetch error or data older than 30 minutes.

`— !` on both items means that the service is not running. The bar checks the service heartbeat every minute.

Click Claude or Codex to open the panel. The panel shows each limit, its reset countdown, the burn-rate projection, and the Codex reset credits. Press Escape or click outside the panel to close it.

## Validation

Run `luac -p lua/items/sketchyusage.lua`. Run `sketchybar --query sketchyusage.claude` and compare the label with the panel.
