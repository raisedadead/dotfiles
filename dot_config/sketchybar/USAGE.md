# Subscription quota

Click Claude or Codex to open the text panel. Click either item again to
close it. An app focus change also closes it. There is no close timer or
outside-click listener.

The bar shows the remaining weekly quota: `96%`. `—` means that the weekly
limit is missing or its reset has passed. `!` marks a fetch error or data
older than 30 minutes. Open the panel for the error or stale-data status.

Each panel row shows a limit, its remaining percentage, and its local reset
time: `Weekly  96% · Tue 15 Sep 08:16`. Saved values have a `!` marker.
Expired limits show `— · reset passed`. Missing reset times are omitted.
Codex Spark rows are hidden. Other model limits appear only when the
provider returns them.

Background checks run every 15 minutes. A successful request sets a minimum
15-minute interval from its start. Clicks, wake events, and restarts respect
the saved deadline. A check before that deadline uses the cache; the next
background check can therefore occur later. Failures delay requests for
1 to 6 hours. A longer server retry delay takes precedence.

Claude uses the CLI credential file or its current user's Keychain entry,
with a service-only fallback for older entries. The Claude CLI owns token
renewal. Open Claude CLI if the panel reports an expired login. Codex uses
its CLI account service. The quota cache contains usage data, not credentials.

## Validation

Run `luac -p lua/items/usage.lua`. Parse `usage.py` with Python's `ast.parse`.
Use isolated fixtures for fresh, stale, expired, missing, and model limits.
Check that repeated calls and HTTP 429 responses preserve request deadlines.
Use a separate SketchyBar instance to check native text layout and dismissal.
