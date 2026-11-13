-- casinoSettings.lua : ONE settings file for all the new games (slots, plinko, villager races, baccarat, craps, texas hold'em).
-- Every machine reads its own section when it starts. Change a value, then reboot that machine (ctrl+R or `reboot`).
-- Every value is optional: delete a line and the default is used. Impossible combinations are fixed automatically and
-- a note is printed on the computer's own screen when it starts.
--
-- "rtp" = return to player: 0.97 means players get back 97 of every 100 chips they bet in the long run.
--         Real casinos are usually somewhere between about 0.90 and 0.99. Above 1.00 the casino loses money over time.
-- "betLimit" = largest bet a player can place on that machine.
return {
    -- SLOTS: the outcome is picked from a table built from these three numbers (exact, not approximate)
    slots = {
        rtp = 0.97,            -- 0.50 - 1.20
        hitFrequency = 0.35,   -- share of spins that win MORE than the bet (about 0.05 - 0.45, depends on rtp)
        pushFrequency = 0.10,  -- share of spins that give the bet back (one cherry), 0 - 0.30
        betLimit = 5000,
    },

    -- PLINKO: the 3 risk levels share these settings; riskier levels just have bigger top prizes
    plinko = {
        rtp = 0.97,            -- 0.50 - 1.20
        hitFrequency = 0.40,   -- share of balls that pay 1x or more, 0.05 - 0.85 (a real unweighted board is 0.29)
        betLimit = 2000,
    },

    -- VILLAGER RACES: payout = rtp / chance of the racer winning, so long shots pay big
    villagerRaces = {
        rtp = 0.97,                      -- 0.50 - 1.20
        weights = {30, 24, 18, 14, 9, 5}, -- exactly 6 numbers: win chance of each form slot. Closer together = fairer races
        betLimit = 2000,
    },

    -- BACCARAT
    baccarat = {
        bankerCommission = 4,  -- percent taken from banker wins (real casinos: 5). 0 = banker bet pays 1:1
        tiePays = 8,           -- tie bet pays N:1 (real casinos: 8, sometimes 9)
        betLimit = 5000,
    },

    -- CRAPS
    craps = {
        oddsMax = 2,           -- free odds allowed behind the point, times the line bet (0 = none). Odds pay true odds
        betLimit = 2000,
    },

    -- TEXAS HOLD'EM (you vs the house): multiplies the blind bonus (straight 1:1, flush 3:2, full house 3:1,
    -- quads 10:1, straight flush 50:1, royal flush 500:1). 1.0 is the standard table.
    texasHoldem = {
        blindPayScale = 1.25,
        betLimit = 1000,       -- largest ante; up to 6x that can be at risk in one hand
    },

    -- TOS GATE (the tos/ computer): rules screen, door + alarm through Create Redstone Links
    tos = {
        casinoName = "THE CASINO",
        tosVersion = 1,        -- raise this number to make everybody agree again
        acceptDays = 30,       -- how long an agreement lasts (0 = forever)
        entryRange = 6,        -- blocks around the Player Detector counted as "at the entrance"
        casinoRange = 40,      -- blocks around the Player Detector counted as "inside the casino"
        touchRange = 4,        -- a monitor touch counts for the one player within this many blocks
        doorSide = "back",     -- computer side touching the Redstone Link that opens the entrance
        alarmSide = "left",    -- computer side touching the Redstone Link that powers the alarm
        doorSeconds = 8,       -- door stays open this long after someone agrees
        warnEvery = 15,        -- seconds between warnings to someone inside who never agreed
        alarmAfter = 3,        -- warnings before the alarm output turns on
        admins = {},           -- e.g. {"YourName", "Helper"}: may use !tos revoke/allow/list and skip the gate
        -- rules = { {"Title", "Text"}, ... },   -- uncomment to replace the built-in rules
    },
}
