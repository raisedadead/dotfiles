# Subscription quota

Click Claude or Codex to open the quota panel for 15 seconds. A second click
closes it. An outside click or app focus change closes it immediately.
Click the footer to check the cache and restart the timer.

The bar shows the remaining weekly quota. The panel shows limit percentages,
local reset times, and the age of each provider response. Codex Spark rows are
hidden. Other Codex rows use the limits that the provider returns.

Expired limits show `Unknown` until the next successful refresh. A dot after
the bar value marks stale data. The panel shows saved data after a service error.

The panel is 480 points wide. Labels use 13-point type. Reset times and the
footer use 11-point type. The native popup contains a rendered detail image and
a clickable footer. A temporary mouse listener detects outside clicks.
It exits after 15 seconds; a footer refresh can start another interval.

## Runtime

`lua/items/usage.lua` controls the popup and its timer. `usage-panel.swift`
renders the normalized quota cache. Xcode command-line tools compile the
renderer on first use or after a source change. The binary and images stay in
`$XDG_CACHE_HOME/sketchybar-usage`, or `~/.cache/sketchybar-usage` by default.

`usage.py` uses the existing Claude and Codex CLI authentication. It checks each
provider after 15 minutes plus up to one minute of jitter. Clicks do not bypass
that deadline. Failures cause a longer delay. The popup countdown runs locally
while the panel is open and makes no provider requests.

## Validation

Run `luac -p lua/items/usage.lua` and compile `usage-panel.swift` with
`xcrun swiftc -O`. Use a disposable normalized quota file to check full,
expired, missing-reset, and stale limits. Inspect the native popup after a
reload. Check its width, text, click behavior, and 15-second close timer.
