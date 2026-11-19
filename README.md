[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/soedirman566-stack/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/soedirman566-stack/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

# BRAINROT TYCOON

A 3D Roblox brainrot game in the genre *Steal a Brainrot* began, built for
[make.fun's roblox-brainrot-01 bounty](https://make.fun/bounty/roblox-brainrot-01).
Absurd meme characters ride a conveyor belt through a colourful 3D world —
buy them, stand them on your base, and watch the cash tick up every second.
Then protect them: rivals can steal your brainrots right off their pads,
and every 85 seconds a tsunami sweeps the lane.

## How to play

- **Buy from the belt.** Brainrots ride the conveyor from the shop end of
  the map. Walk up to one and hold its prompt to buy it; it appears on a
  free pad at your base and earns its income every second.
- **Catch wild ones.** Common brainrots wander the grass north and south of
  the lane. Catching one is free.
- **Fourteen brainrots, five rarities.** Common → Rare → Epic → Legendary →
  Mythic, from the 25-cash Noobini to Godini Brainrotti himself
  ($1,100,000, $19,000 a second). The full list is in the in-game Catalog.
- **Steal.** Every placed brainrot has a Steal prompt. Grab a rival's
  brainrot and it rides over your head — the theft only counts when you
  carry it back onto your own plot, and you run slower while carrying. The
  victim can rescue it by catching you.
- **Lock your base.** Step on the black pad at your base to lock it for 60
  seconds; locked bases refuse all thieves.
- **Beware the tsunami.** A warning banner counts down 10 seconds, then a
  wall of water sweeps the lane. Standing on any base plot is safe; anyone
  caught in the open is flung, hurt, drops their carry, and the belt is
  washed clean.
- **Rebirth.** At the shrine (or the HUD button), trade your cash and your
  whole collection for a permanent +50% income multiplier per rebirth.
  Costs grow ×4 each time: $25,000, then $100,000, then $400,000…

## The world

A shop row at the west end where the belt begins, the conveyor lane running
the length of the map, six colour-coded base plots (six pads each) north
and south of the lane, the purple Rebirth Shrine at the east end, and trees,
lamps and clouds for scenery. Signs throughout are lettered at runtime by
the server's Signs module.

## Layout

- `src/server/` — the server systems, one module per job:
  `BrainrotDefs` (the catalog), `BrainrotFactory` (builds the 3D models),
  `Economy` (cash and the rebirth ladder), `PlotManager` (bases, pads and
  placement records), `Conveyor` (belt offers and wild spawns), `Steal`
  (carries, rescues, locks), `Tsunami` (the wave), `Signs` (sign text),
  and `init.server.luau` wiring them together.
- `src/client/Game.client.luau` — the HUD: cash and income bar, rebirth
  button, catalog panel, tsunami banner, notifications.
- `default.project.json` — the Rojo project: services plus the whole
  Workspace world. It is emitted by `tools/generate-project.mjs` (the world
  is laid out by loops, so plots and scenery stay regular); edit the
  generator, not the JSON.
- `game.rbxl` — the place Rojo builds from the project and the sources.
- `main.ts` — the hand-in program: copies the game into `/output` and
  writes `dossier.json` with `vendor/makefun-roblox.ts` (the kit's library,
  unchanged).
- `PLAY.json` — the published Roblox place this entry points at.
- `screenshots/` — captures of the game; the first is the cover and the
  game's Roblox thumbnail.

## Build and hand in

    node tools/generate-project.mjs          # only after changing the world layout
    rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
