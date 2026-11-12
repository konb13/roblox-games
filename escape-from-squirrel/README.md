# 🐿️ Escape from Squirrel: The Great Acorn Heist

An open-world chase game. A giant squirrel guards its golden acorns in a little town.
Sneak around, grab acorns (on rooftops, upper floors, ramp tops, under the squirrel's own
oak), bank them at the **Acorn Bank**, and when the team has banked enough, an **escape
balloon** lands. Get in before the squirrel gets you.

## How a round works
1. **Lobby, then a 15 s countdown.** Everyone spawns in the town's plaza next to the **Garage**.
2. **12 s head start** while the squirrel naps by the Great Oak (💤).
3. **Chase (up to 7 min):**
   - Pick up **golden acorns 🌰** (carry up to 5). A counter over your head shows how many
     you have, and **the squirrel goes after whoever carries the most.**
   - Bank them on the gold vault inside the **🏦 Acorn Bank** (north-east).
   - The team goal is 5 acorns per runner (min 10, max 30). The progress bar is at the top of the screen.
   - When the goal is reached, the **🎈 escape balloon** lands at one of 3 spots. Touch it to escape.
4. **Caught?** You drop your acorns and become a **Squirrel Minion**. Minions are small and fast,
   **can go inside buildings**, and catch runners by bumping into them.
5. A **second squirrel** joins at 4:00. The squirrel gets faster every 25 s.

## The squirrel
- **Too big for doors.** Buildings are safe from the big squirrel (not from minions). It waits outside the nearest door.
- **Pounce:** it crouches for a moment with a **❗** over its head, then leaps at where you're
  *heading*. Change direction when you see the ❗.
- Hates water and won't swim. The lake is safe from it, but you're slow in the water.

## The town
| Area | What's there |
|---|---|
| SW Spawn plaza | **Garage** with Volt Roadster, Go-Kart and Monster Truck, plus 2 more karts outside |
| S Skate park | Funbox, kickers, quarter-pipe deck with acorns, **big kicker that jumps the road** |
| SE / W / E | 5 two-storey **houses** (stairs, upstairs windows you can jump out of) and the **Nut Mart** |
| C Central Park | **The Great Oak** (squirrel's home, risky acorns at its base), benches, trees, Lawn Mower |
| NW Stunt park | **MEGA RAMP** with a gap jump, and a **Watch Tower** (ladder to the roof, 2 acorns up top) |
| N Lake | Bridge, an island you can only swim to, and a **LAKE JUMP** that only a fast car clears |
| NE | **Acorn Bank** and the balloon field |

## Vehicles
| Car | Top speed | Notes |
|---|---|---|
| Volt Roadster | 95 | Fastest, 1 passenger seat, can clear the lake jump |
| Go-Kart | 75 | Small and twitchy |
| Monster Truck | 62 | Huge wheels, 2 passengers in the bed, great on ramps |
| Lawn Mower | 38 | Hilariously slow |

- **Drive:** walk into the seat, or use the **Drive / Ride** prompt (works on phones).
  W/S for gas and reverse, A/D to steer, **Space to get out**.
- **⚡ Boost pads** on the roads and in front of big ramps give 3 seconds of extra speed.
- **🚀 Air time pays:** coins for every jump that keeps you in the air for 0.6 s or longer.
- Flipped cars turn back over after 2 s. Cars that sink in the lake or get abandoned go back home.
- The squirrel can snatch you out of a car if it gets close, so keep moving.

## Setup in Roblox Studio (Windows)
You need **Roblox Studio** (free, from create.roblox.com) and **Rojo**.

1. Open PowerShell in this `escape-from-squirrel` folder and download Rojo:
   ```powershell
   Invoke-WebRequest https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-windows-x86_64.zip -OutFile rojo.zip
   Expand-Archive rojo.zip -DestinationPath . -Force
   .\rojo.exe plugin install
   ```
   (Or install the **Rojo** plugin by *rojo-rbx* from Studio's Toolbox → Plugins. Its version
   must match `rojo.exe`. The commands above use 7.7.1, the same as the Creator Store plugin.)
2. Start it with `.\rojo.exe serve` and leave the window open.
3. In Studio: **File → New → Baseplate** → **Plugins** tab → **Rojo** → **Connect**.
4. Press **Play**. The town builds itself when the game starts. In edit mode you'll only see the Baseplate.

## Testing tips
- **Multiplayer:** Test tab → Clients and Servers → 2–3 players.
- **Faster testing:** lower `IntermissionTime` / `HeadStartTime` or `Acorns.MinGoal` in `src/shared/Config.luau`.
- **If cars drive backwards or steer the wrong way**, flip `DriveSign` or `SteerSign` in `Config.VehicleTuning`.
  The cars are untested in Studio, so these may need flipping.
- **To fly around and look at the town:** while playing, switch **Current: Client** to **Server** and use the free camera.

## Ideas for the next updates
- **Items:** Nut Bait (distracts the squirrel for 5 s), Banana Peel (slips minions), Pinecone
  Bomb (stuns the squirrel), Jetpack, Grappling Hook for rooftops
- **More fun stuff:** trampolines, zip line from the Watch Tower, sprinklers that slow the squirrel, a car wash shortcut
- **Golden Nut:** rare pickup that lets a runner *become* a squirrel (like the Donut Key)
- **More maps:** Snowy Peaks (sleds and ice), Beach Boardwalk (jet skis), Night Town (flashlights)
- **Monetization:** Roadster / Monster Truck Game Passes (spawn your own car), Nitro boost,
  Acorn Magnet, Revive, VIP, squirrel skins, car paints, trails, "Play as the Squirrel" pass
- **Retention:** daily rewards, stunt quests ("get 3 s of air time"), badges, leaderboards for air time and acorns banked

## Project layout
```
src/shared/Config.luau             all tuning (speeds, goals, vehicles, rewards)
src/shared/Remotes.luau            RemoteEvents
src/server/Main.server.luau        startup
src/server/Services/
  RoundService.luau                game loop, catching, escaping
  SquirrelAI.luau                  giant squirrel: pathfinding, ground following, pounce
  SquirrelModel.luau               builds a squirrel from parts
  CharacterSquirrel.luau           turns caught players into minions
  AcornService.luau                golden acorns, bank deposits, escape balloon
  VehicleBuilder.luau              builds cars (chassis, seat, hinge wheels, servo steering)
  VehicleService.luau              driving, boost pads, air-time coins, flipping, respawning
  WorldBuilder.luau                the whole town + lobby
  BuildingBuilder.luau             enterable buildings (doors, windows, floors, stairs, ladders)
  PlayerService.luau               leaderstats + roles
  Parts.luau                       part/ramp/sign helpers
src/client/HUD.client.luau         UI, speedometer, spinning acorns
```
