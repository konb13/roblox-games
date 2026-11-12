# 🍩 Escape from Donut

A Roblox chase game: a giant donut hunts players through a maze full of locked houses.
Find the keys, open the houses, grab the Master Key and reach the Exit before you get glazed.

## What's in this build (Stages 1–2)

- **Rounds:** lobby → 15 s intermission → 10 s head start (donut asleep 💤) → up to 6 min chase → results.
- **New maze every round**, generated in code: 21×21 hedge maze with loops, a start plaza and an exit room.
- **The Donut:** pathfinds to the nearest runner, charges when it can see you up close,
  and speeds up every 20 s (14 → 23). A **second donut** shows up at 3:00.
- **Getting caught:** you turn into a **Mini Donut** and help catch everyone else (+10 coins per catch).
- **4 houses + key chain**, all generated: Red key in the maze → Red house holds the Blue key →
  … → Yellow house holds the **Master Key** → opens the **Exit Gate** → step on the green pad to escape.
  Your key floats over your head, and you drop it if you get caught.
- **🍩 Donut Key** (50% of rounds, hidden in a far dead end): press **Q** or tap the button to
  switch sides and become a **Rogue Donut** (bigger, faster, +20 coins per catch).
- **HUD:** timer, donut speed, current objective, your role, carried key, event pop-ups. Works on phones.
- **Leaderboard:** Coins and Escapes (*not saved yet*; saving comes in Stage 5).

## Getting it into Roblox Studio

### Option A: Rojo (recommended, keeps code in sync)
1. Install [Roblox Studio](https://create.roblox.com).
2. Install [VS Code](https://code.visualstudio.com) and its **Rojo** extension
   (or install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in this folder).
3. In Studio, install the Rojo plugin (the VS Code extension offers to do this).
4. Open this folder in VS Code → Rojo: **Start server** (or run `rojo serve`).
5. In Studio: **File → New → Baseplate**, then click **Rojo → Connect** in the Plugins tab.
   The scripts appear in ReplicatedStorage, ServerScriptService and StarterPlayerScripts.

### Option B: copy and paste (no extra tools)
Create these in Studio's Explorer and paste in each file's contents:

| Studio location | Type | File |
|---|---|---|
| ReplicatedStorage → Folder **Shared** | ModuleScript **Config** | `src/shared/Config.luau` |
| ReplicatedStorage → Shared | ModuleScript **Remotes** | `src/shared/Remotes.luau` |
| ServerScriptService → Folder **Server** | Script **Main** | `src/server/Main.server.luau` |
| ServerScriptService → Server → Folder **Services** | ModuleScript per file | `src/server/Services/*.luau` (name = file name without `.luau`) |
| StarterPlayer → StarterPlayerScripts → Folder **Client** | LocalScript **HUD** | `src/client/HUD.client.luau` |

The game deletes the template's Baseplate and SpawnLocation when it starts, and builds the
lobby and maze itself.

## Testing
- **Solo:** press **Play** (F5). You spawn in the lobby, and the round starts after 15 s.
- **Multiplayer:** **Test** tab → **Clients and Servers** → 2–3 players → **Start**.
- **Faster testing:** lower `IntermissionTime`, `HeadStartTime` or `SpeedGainEvery` in `src/shared/Config.luau`.
  Set `DonutKey.SpawnChance = 1` to always get a Donut Key.
- **Maze logic test** (outside Roblox, needs the [Luau CLI](https://github.com/luau-lang/luau/releases)):
  `./tests/build_maze_test.sh`. It checks 300 random mazes for connectivity, open entrances and exit, and valid house doors.

## Publishing
1. **File → Publish to Roblox**, then name the game.
2. At [create.roblox.com/dashboard](https://create.roblox.com/dashboard) → your game → **Configure**:
   fill in the **Maturity & Compliance questionnaire** and set the game to **Public**.
3. Add an icon and thumbnails. They matter more than anything else for getting clicks.

## Project layout
```
src/shared/Config.luau          all tuning numbers (speeds, timers, rewards, maze size)
src/shared/Remotes.luau         RemoteEvents (Announce, UseDonutKey)
src/server/Main.server.luau     startup
src/server/Services/
  RoundService.luau             game loop, catching, escaping, Donut Key
  DonutAI.luau                  chaser donut movement and pathfinding
  DonutModel.luau               builds a donut out of parts (eyes, teeth, sprinkles)
  CharacterDonut.luau           turns a player into a Mini or Rogue donut
  MazeGenerator.luau            maze algorithm (pure logic, tested)
  WorldBuilder.luau             maze, plaza, exit and lobby parts
  HouseBuilder.luau             locked houses with furniture and key pedestal
  KeyService.luau               keys, doors, Exit Gate, escape pad
  PlayerService.luau            leaderstats and roles
  Parts.luau                    part, sign and label helpers
src/client/HUD.client.luau      UI, Q / button for the Donut Key, spinning keys
```

## Roadmap
3. **Items:** Crowbar, TNT (blast walls, stun donut), Speed Quilt, Jump Quilt, inventory UI
4. **Vehicles & portals:** Go-kart, Golf Cart, Volt Roadster, portal pairs, Glitch Portal
5. **Progression & monetization:** saved data (ProfileStore), shop, Game Passes, Revive, coin packs
6. **Retention:** daily rewards, quests, badges, leaderboards, codes
7. **Worlds 2–5:** Frosting Forest, Glazed Glacier, Candy Factory, Donut Dimension
8. **Polish:** sounds, music, effects, tutorial, thumbnails
