# 🧠 Brainrot Dash: Don't Fall! 💀

A **speedrun** across a sky course over a bottomless void. You run fast and almost never
need to jump: pick the right glass lane, outrun crumbling floors, dodge sweeper walls,
time the blinking road. Cross the start line and the clock starts.
At the end of every stage you rescue a goofy brainrot creature that earns you coins
and follows you around. Buy superpowers, survive the server-wide Chaos Events, reach
the finish and **rebirth** for a bigger coin multiplier.

## The course (10 stages, built for running, not jumping)
| # | Stage | What happens |
|---|---|---|
| 1 | Glass Lanes | 3 lanes of glass, rows touching. 1 tile per row is fake and shatters under you. |
| 2 | Crumble Road | The floor crumbles a split second after you touch it. Don't stop! |
| 3 | Sweeper Alley | A tall spinning wall sweeps the road. Time your dash past it. |
| 4 | Blink Road | Road sections take turns vanishing (orange = about to go). Sprint across. |
| 5 | Glass Gamble | 4 lanes, 2 fake tiles per row. |
| 6 | Launch Pads | Run onto the pads and they fling you over the gaps automatically. |
| 7 | Boulder Hill | Run uphill while boulders roll down at you. |
| 8 | Double Sweep | Two sweeper walls spinning in opposite directions. |
| 9 | Blink Panic | Faster blinking road. |
| 10 | Glass Gauntlet | 4 lanes, only 1 safe tile per row, 12 rows. |
| 🏆 | Finish | Stops your timer. Step on the pad to **rebirth** (+500 coins, +50% coin income forever). |

**Speedrun features**
- Base run speed is **24** (normal Roblox is 16).
- **⚡ Speed pads** at the hub and every checkpoint give a 2.5 s burst.
- **⏱️ Run timer:** starts when you cross the START line, stops at the finish. Falling doesn't stop the clock.
- Your **best time is saved** and shown on the leaderboard (the `Best` column).

Falling puts you back at your last checkpoint (with a funny message and a fall counter 💀).

## Brainrots
Each checkpoint holds one. Touch the checkpoint to rescue it. It earns coins every
second (even while you're standing still), and your newest one follows you as a pet.
Change your pet in the 🧠 Brainrots menu.

They're in the classic brainrot style (animal + everyday object, Italian-sounding name,
sneakers, a catchphrase) but they're **original characters**. Copying the famous meme
characters can get a Roblox game taken down, because some of them have trademark claims.

| Stage | Brainrot | What it is | Rarity | Coins/s |
|---|---|---|---|---|
| 1 | Gattino Frullatino | a cat that is a blender | Common | 1 |
| 2 | Pomodoro Motorino | a tomato on a scooter | Common | 2 |
| 3 | Ranocchio Lavatrice | a frog in a washing machine | Uncommon | 4 |
| 4 | Pinguino Pizzaiolo | a penguin pizza chef | Uncommon | 6 |
| 5 | Cammello Caffettiera | a camel with moka-pot humps | Rare | 10 |
| 6 | Polpo Pantofolo | an octopus in fluffy slippers | Rare | 15 |
| 7 | Elefantino Aspirapolvere | an elephant with a vacuum-hose trunk | Epic | 25 |
| 8 | Gufo Guantone | a boxing owl | Epic | 40 |
| 9 | Tartaruga Trattore | a turtle whose shell is a tractor | Legendary | 60 |
| 10 | Giraffa Gelatona | a giraffe ice-cream cone on one sneaker | Mythic | 100 |

**Using your own 3D models:** make a Folder called `BrainrotModels` in ReplicatedStorage (in Studio)
and put a Model in it named after the brainrot's id (e.g. `GattinoFrullatino`, ids are in
`src/shared/Brainrots.luau`). The game uses it instead of the part-built one, scaled to fit and
facing forward (-Z). Use models you made or that you're allowed to use.

## Superpowers (🛒 Shop)
| Key | Power | Price | What it does |
|---|---|---|---|
| 1 | ⚡ Zoomies | 25 | Run super fast for 5 s |
| 2 | 🥾 Moon Boots | 100 | Giant jumps for 6 s |
| 3 | 🪂 Parachute | 250 | Float down slowly. Pop it while falling! |
| 4 | 👓 X-Ray Goggles | 750 | Fake glass tiles glow red, safe ones green, for 4 s |
| 5 | ⏪ Rewind | 1500 | Teleport back to the last solid ground you stood on. Saves you mid-fall. |
| - | 🦘 Double Jump | 400 | Always on: jump again in mid-air |

On phones, tap the power buttons at the bottom of the screen.

## Chaos Events
Every 60 seconds, something happens to the whole server:
- **🌙 Low Gravity:** everything floats (bounce pads become *very* bouncy)
- **⚡ Speed Frenzy:** everyone runs fast
- **💰 Coin Rain:** coins drop all over the course for 20 s
- **🔀 Tile Shuffle:** every fake glass tile moves, so what you memorised is wrong now

## Saving
Coins, rebirths, best stage, brainrots, powers and your pet are saved with DataStores.
**In Studio**, saving needs **Home → Game Settings → Security → Enable Studio Access to API Services**.
Without it the game still works, it just forgets everything when you stop.

## Setup in Roblox Studio (Windows)
1. Copy `rojo.exe` from one of the other game folders into this `brainrot-dash` folder (or download it again:
   ```powershell
   Invoke-WebRequest https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-windows-x86_64.zip -OutFile rojo.zip
   Expand-Archive rojo.zip -DestinationPath . -Force
   ```
   ).
2. Run `.\rojo.exe serve` in this folder.
3. In Studio: **File → New → Baseplate** → Plugins → **Rojo** → **Connect** → **Play**.
   The game removes the Baseplate (there's no floor, that's the point) and builds the course.

## Testing tips
- **Give yourself coins:** in the Command Bar during Play (Server view), run
  `game.Players:GetPlayers()[1].leaderstats.Coins.Value = 99999`.
  This is only the display; to really test buying, temporarily set prices lower in `Config.luau`.
- **More Chaos Events:** lower `Config.Chaos.Every` to see them more often.
- **Note:** fake-tile info is sent to every player's computer (so X-Ray can work), so a cheater
  could read it. Fine for now; later the server could send it only while X-Ray is on.

## Ideas for next updates
- **More stages:** conveyor belts, wind fans, rising "brainrot goo", lasers, a giant fly-swatter, disappearing ladders
- **Trading** brainrots between players, **mutations** (golden / rainbow versions worth more)
- **Brainrot fusion:** combine 3 of the same into a stronger one
- **Daily spin wheel, quests** ("fall 0 times on stage 5"), **badges**, a **leaderboard** for fastest runs
- **Monetization:** coin packs, "Skip Stage" (developer product), 2x Coins pass, VIP pet slot (2 pets at once),
  cosmetic trails, power bundles, a "Revive Here" button after falling

## Project layout
```
src/shared/Config.luau            tuning: course, powers, prices, chaos events
src/shared/Brainrots.luau         the 10 brainrot creatures (data + models)
src/shared/Remotes.luau           RemoteEvents / RemoteFunctions
src/server/Main.server.luau       startup
src/server/Services/
  CourseBuilder.luau              builds all 10 stages + hub + finish, runs the traps
  ProgressService.luau            checkpoints, falling, rescues, coins, income, rebirth
  PowerService.luau               buying powers, cooldowns, Zoomies / Moon Boots
  ChaosService.luau               server-wide Chaos Events
  DataService.luau                saving and loading
  Parts.luau                      part / sign helpers
src/client/HUD.client.luau        stats, shop, collection, hotbar, messages
src/client/Powers.client.luau     X-Ray, Parachute, Rewind, Double Jump, bounce pads
src/client/Pets.client.luau       pets that follow players, spinning coins
```
