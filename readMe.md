<h1>ccTweaked casino system</h1>
Image of an illegal gambling den I made on a server.

> **This fork adds six games: slots, texas hold'em, villager races, baccarat, plinko and craps.**
> Jump to [new games](#new-games-slots-texas-holdem-villager-races-baccarat-plinko-craps) for how to build and install them,
> and to [settings](#settings-return-and-hit-frequency) for changing how much each game pays back.
> Blackjack, roulette, the cashier and the central computer are the original ones (sections further down).

![image](https://github.com/user-attachments/assets/d31386db-cef3-43be-9972-12ede72e7917)

<h2>cental computer</h2>
This wil be the computer managing all the games and disks

<h3> construction </h3>

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/fbac0c25-7a03-471a-aa20-75f8102b8b64)

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/861a77b2-0b4f-4d2f-8805-fe9e9a6cc50f)

Monitor is optional but if you do, I recommend using a monitor of minimum 6 blocks wide.


<h3> software </h3>

Install the software using the installer 
1. wget run https://raw.githubusercontent.com/YeeetiamusGames/ccTweakedCasino/refs/heads/main/installer.lua
2. select cental computer using the arrowkeys
3. press enter
   
You are able to change the value of a chip and the withdrawalfee in the settings.lua file
You can also view the profits of each machine in machineprofits.json (note that the cashier wil most of the time give negative profits)

<h2>cashier</h2>

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/bbdd1c93-0a68-4220-8464-b57df3c2eda8)

<h3> construction </h3>

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/a0f18771-142a-4966-99a4-f4cf503cd1e2)

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/06efed05-9970-4978-9f8b-b1f98076703f)

Screen is 3x2
Barrel is connected to front of computer together with the main natwork
Computer facing out in the modem of the main network

!!!Also connect a storage drawer somewhere on the network. This wil be your vault and your diamonds will be stored here!!!
!!!You can also only attach 1 cashier to a network!!!

<h3> software </h3>

Install the software using the installer 
1. wget run https://raw.githubusercontent.com/YeeetiamusGames/ccTweakedCasino/refs/heads/main/installer.lua
2. select cashier using the arrowkeys
3. press enter

Enter the name of the barrel people will be accesing on line 4 (example: "barrel_3")
Enter the name of the drawer where your diamonds will be stored on line 3 (example: "storagedrawers:standard_drawers_1_0")

You are also able to change the name of the casino on line 192 (sorry it is hardcoded =[ )


<h2>roulette</h2>

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/dd885eb3-1535-40d5-91d4-e01576e9dc57)

<h3> construction </h3>
Bottom screen is 5x2
Top screen is 5x5
Computer facing out with drive comming out of right side.

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/bec31947-8696-4b16-857d-640c317cad95)

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/957e5166-bdcf-4aae-b9ee-60815cec8daf)

Place the modem of the main network on the front of the monitor.

<h3> software </h3>
Install the software using the installer 
1. wget run https://raw.githubusercontent.com/YeeetiamusGames/ccTweakedCasino/refs/heads/main/installer.lua
2. select roulette using the arrowkeys
3. press enter

Also enter the name of your drive on line 16 (example: "drive_5")



<h2>blackjack</h2>

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/b00a55ee-82b3-4e92-b79e-c070c5ccc256)

<h3> construction </h3>
screen is 3x4
Computer facing out in the modem of the main network

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/6e77dad3-e96e-486e-9f45-c33015ca71fb)

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/2324241c-1ff2-4497-8774-ea5107969214)

![image](https://github.com/WillemVermeeren/ccTweakedCasino/assets/104625121/7e43f6e3-790a-4024-b331-afcb63f63186)

<h3> software </h3>
Install the software using the installer 
1. wget run https://raw.githubusercontent.com/YeeetiamusGames/ccTweakedCasino/refs/heads/main/installer.lua
2. select blackjack using the arrowkeys
3. press enter

Also enter the name of your drive on line 16 (example: "drive_5")





---

<h2>new games: slots, texas hold'em, villager races, baccarat, plinko, craps</h2>

All six work like blackjack: a player inserts a casino card (made by the cashier) and plays with their chips. Every machine talks
to the same central computer, which keeps the balances and the profit of each machine in `machineprofits.json`.
Set up the **central computer and the cashier first** (sections below), then add machines.

<h3> what you need for each machine </h3>

| part | notes |
|---|---|
| Advanced computer | a normal computer also runs it, but only advanced monitors send touches |
| Advanced monitor, **at least 4 wide x 3 tall** | a bigger one works too. The game stops with a message if it is too small |
| Disk drive | the player's card goes in here |
| Wired modem | connects the machine to the casino network (right click it so it turns red) |
| Speaker | optional: villager noises, dice rattles and win sounds |

<h3> construction </h3>

Put the monitor, disk drive and speaker **directly against the computer** (not on the cable network) so the game always finds its own.
Only the wired modem connects to the casino network cable.

```
            [  monitor 4x3 or bigger  ]   <- on the front of the computer
                       |
     [disk drive] [ COMPUTER ] [wired modem] ---- cable ---- casino network (central computer)
                       |
                  [speaker]   (on top, optional)
```

A player stands in front of the monitor, touches the screen, and puts their card in the drive.

<h3> software </h3>

1. Put this repository on your own GitHub (the installer entries for the new games point at
   `github.com/YeeetiamusGames/ccTweakedCasino`, branch `main`; change the name in `installer.lua` if yours is different).
2. On the new computer run
   `wget run https://raw.githubusercontent.com/YeeetiamusGames/ccTweakedCasino/refs/heads/main/installer.lua`
3. Pick the game with the arrow keys and press enter. It downloads `startup.lua` (the game) and `casinoSettings.lua` (the settings).
4. Reboot the computer (`reboot`). The game starts by itself every time the computer turns on.

HTTP must be allowed in your server's ComputerCraft config. If the game complains about the monitor size, build a bigger one.

<h3> the games </h3>

| game | how it plays | defaults |
|---|---|---|
| **slots** | 3 reels, centre line pays. Buttons: SPIN, BET (change bet), PAYS (paytable) | wins 35% of spins, bet back 10%, returns 97% |
| **texas hold'em** | You vs the house (Ultimate Texas Hold'em rules). Put up an equal ANTE and BLIND, get 2 cards. Check or raise 4x before the flop, check or raise 2x after the flop, then raise 1x or fold on the river. Dealer needs a pair to qualify. Play bet pays 1:1, ante pays 1:1 if the dealer qualified, the blind pays a bonus when you win with a straight or better | blind bonus x1.25 (about 99% for a decent player) |
| **villager races** | Six villagers race. Bet on one to WIN (1st) or finish in the TOP 3. Their form changes every race and so do the odds: long shots pay big | returns 97% |
| **baccarat** | Bet PLAYER (1:1), BANKER (pays 0.96:1) or TIE (8:1). Standard third-card rules, 8 decks. Player and banker bets push on a tie | banker 99.4%, player 98.7%, tie 86% |
| **plinko** | Pick LOW / MEDIUM / HIGH risk, set a bet, press DROP. The ball bounces down 8 rows into a multiplier. Same bet drops again with one touch | 40% of balls pay 1x or more, returns 97% |
| **craps** | PASS LINE or DON'T PASS. Come-out roll, then roll the point. After a point is set you can add a free ODDS bet (up to 2x your bet) that pays true odds | pass line 98.6%, with 2x odds only about 0.6% lost per chip risked |

Notes on the numbers: "returns 97%" means that over a very long time players get back 97 of every 100 chips they bet.
Short sessions swing a lot around that. As far as I know real slot machines usually pay back roughly 90 to 95 % and table games
roughly 95 to 99 %, so these defaults are set a little more generous than that so the casino feels winnable.
The hold'em figure is a simulation of a simple (not perfect) strategy: a perfect player does a bit better than that.

<h3> settings: return and hit frequency </h3>

All the new games read one file, `casinoSettings.lua`, on their own computer. To change it:
1. on the game computer run `edit casinoSettings.lua`, change the numbers, save (ctrl, then Save, then Exit)
2. `reboot`

(or edit the file in your GitHub repo and run the installer again on the machines).
Every value is optional: delete a line and the default is used. If you pick something impossible (for example a 90% hit
frequency at a 97% return) the game fixes it and prints a note on the computer's own screen when it starts.

| game | setting | what it does | allowed |
|---|---|---|---|
| all | `betLimit` | biggest bet a player can place | any number |
| slots | `rtp` | return per chip | 0.50 to 1.20 |
| slots | `hitFrequency` | share of spins that win more than the bet | about 0.05 to 0.45 (depends on `rtp`) |
| slots | `pushFrequency` | share of spins that give the bet back | 0 to 0.30 |
| plinko | `rtp` | return per chip | 0.50 to 1.20 |
| plinko | `hitFrequency` | share of balls paying 1x or more (a plain board is 0.29) | 0.05 to 0.85 |
| villager races | `rtp` | return per chip | 0.50 to 1.20 |
| villager races | `weights` | win chance of the six form slots. Closer numbers = fairer races, fewer long shots | exactly 6 numbers |
| baccarat | `bankerCommission` | percent taken from banker wins (casinos: 5) | 0 to 50 |
| baccarat | `tiePays` | tie bet pays N:1 (casinos: 8) | 1 to 50 |
| craps | `oddsMax` | free odds allowed behind the point, times the line bet | 0 to 10 |
| texas hold'em | `blindPayScale` | multiplies the blind bonus table. 1 = standard. Around 1.5 a decent player breaks even | 0 to 10 |

Rule of thumb: a return of 1.00 means the casino makes nothing over time, above 1.00 it loses chips. The cashier takes a
withdrawal fee (`settings.lua` on the central computer), which is where the casino makes its diamonds back.

<h3> if something goes wrong </h3>

| message / problem | fix |
|---|---|
| `Monitor is 29x19 characters, needs at least 39x19` | build the monitor bigger (4 wide x 3 tall or more) |
| `no monitor connected` / touches do nothing | use an *advanced* monitor touching the computer |
| `no modem connected` | put a wired modem against the computer and right click it |
| the game says it needs a disk drive | place a disk drive against the computer |
| the machine freezes on "insert your card" and nothing happens | the central computer must be running and on the same cable network |
| a note starting with `[settings]` on the computer screen | your `casinoSettings.lua` had an impossible value, the game fixed it for you |

<h3> changing the games yourself </h3>

The `dev` folder holds the source: `common.lua` (network, card, buttons, bet screen), `cards.lua`, `footer.lua`, one file per game in
`dev/games`, and tests in `dev/test`. Each game's `startup.lua` is built from those pieces:

```
bash dev/build.sh .          # rebuilds every game's startup.lua and copies casinoSettings.lua
bash dev/test/run_all.sh .   # checks syntax and the maths of every game (needs a plain Lua 5.3, for example `texlua`)
```

The tests run each game's maths against the numbers above (exact return, hit frequency, card rules, payouts). They do not
simulate Minecraft itself, so look at a new machine in game before opening it to players.

## TOS gate (rules screen + Create Redstone Link door + alarm)

A computer at the entrance shows the casino rules (no breaking or modifying blocks, no griefing, no stealing, no cheating, hands off the tech, respect others, play at your own risk, consequences, data logging). Players must read every page and agree before the door opens.

**Honest limit:** a ComputerCraft program cannot stop someone breaking a block. It records who agreed, keeps the door shut for people who did not, warns and alarms on anyone inside who never agreed, and gives you a log for bans. For real protection also claim the casino chunks (FTB Chunks, Open Parties and Claims, a server plugin like WorldGuard) so blocks cannot be broken at all.

### Parts
| Part | Notes |
|---|---|
| Computer | any, with this installed |
| Advanced Monitor | 4 wide x 3 tall or bigger, touching the computer or on a wired modem |
| Player Detector (Advanced Peripherals) | touching the computer or on a wired modem; ranges are measured from this block, so put it at the entrance |
| Chat Box (Advanced Peripherals) | touching the computer or on a wired modem |
| Create Redstone Link (transmitter) x1-2 | one on the computer's `doorSide` (opens the entrance), optional one on `alarmSide` (alarm) |
| Create Redstone Link (receiver) | next to the door / alarm, tuned to the same two items as its transmitter |

The Redstone Link frequency is set by the two items you put in its slots, not by code. Wire the door receiver to an iron door, piston door or Create gate. Wire the alarm receiver to a note block, bell or lamps.

### Install
Put the computer down, run the installer (`wget run https://raw.githubusercontent.com/YeeetiamusGames/ccTweakedCasino/refs/heads/main/installer.lua`), pick **TOS gate**, then edit `casinoSettings.lua` (`tos` section): add your name to `admins`, set `casinoName`, check `doorSide` and `alarmSide`, and `reboot`.

### How players agree (any of these)
- touch **I AGREE** on the monitor (only appears on the last page; works if exactly one player is within `touchRange`)
- right-click the Player Detector twice within 15 seconds
- type `!agree` in chat (`$agree` keeps it out of public chat)

Chat commands for everyone: `!rules`, `!status`. For admins: `!tos revoke <name>`, `!tos allow <name>`, `!tos list`.

### What it does
- the door opens for 8 seconds after someone agrees, and stays open while everyone near the entrance has agreed (a stranger standing next to you keeps it shut)
- people inside `casinoRange` but away from the entrance who never agreed get a chat warning and toast every `warnEvery` seconds; after `alarmAfter` warnings the alarm output turns on until they leave or agree
- agreements last `acceptDays` days; raise `tosVersion` to make everyone agree again after you change the rules
- every agree, warning, revoke and alarm is written to `tos_log.txt` on the computer; agreements are stored in `tos_accepted.lua`
- the rules are in the `rules` list in the settings if you want your own text

### Troubleshooting
- `missing: Player Detector` : the block is not touching the computer or modem, or Advanced Peripherals is not installed
- the log says `detector error` : `casinoRange` is bigger than the detector's `playerDetMaxRange` config, lower it
- door never opens : check `doorSide`, and that the transmitter and receiver have the same two frequency items

