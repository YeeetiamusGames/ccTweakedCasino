-- ================= CASINO TERMS OF SERVICE GATE =================
-- Needs: computer, ADVANCED monitor (4x3 or bigger), Advanced Peripherals Player Detector + Chat Box,
-- and one or two Create Redstone Link transmitters touching the computer (door + alarm).
-- Settings live in casinoSettings.lua under  tos = { ... }
-- Players agree by: touching AGREE on the monitor, right-clicking the Player Detector twice, or typing !agree
-- NOTE: this cannot physically stop block breaking. Use chunk claims / a protection mod for that.

TOS = TOS or {}

local DEFAULT_RULES = {
    {"No breaking or modifying", "Do not break, place, replace, or change any block in the casino. Machines, walls, floors and decor stay exactly as built."},
    {"No griefing", "No TNT, lava, fire, water, or lag machines. Do not trap or block players, doors, or villagers, and do not harm players, villagers or animals."},
    {"No stealing", "Do not take items, chips, cards, or chests that are not yours. Each card belongs to one player."},
    {"No cheating", "No hacked clients, x-ray, auto-clickers, bots, duping, or bug abuse. Report bugs to staff instead of using them."},
    {"Hands off the tech", "Do not open, break, or reprogram the computers, monitors, modems, disk drives, or redstone links."},
    {"Respect others", "No harassment, hate, spam, or begging. Do not scam players or lure them away from the casino to rob them."},
    {"Play at your own risk", "All games are chance. Chips have no guaranteed value, and casino staff decisions on payouts are final."},
    {"Consequences", "Breaking these rules can get you kicked, banned from the casino, and your chips and card removed."},
    {"Your data", "This gate logs your username and the time you agree. By agreeing, you accept every rule above."},
}

local DEFAULTS = {
    casinoName = "Casino Fortuna",
    tosVersion = 1,        -- raise this number to make everyone agree again
    acceptDays = 30,       -- how long an agreement lasts (0 = forever)
    entryRange = 2,        -- blocks around the detector counted as "at the entrance"
    casinoRange = 26,      -- blocks around the detector counted as "inside the casino"
    touchRange = 4,        -- a monitor touch counts for the one player within this many blocks
    doorSide = "back",     -- computer side touching the Redstone Link that opens the entrance
    alarmSide = "left",    -- computer side touching the Redstone Link that powers the alarm
    doorSeconds = 2,       -- how long the door stays open after someone agrees
    warnEvery = 15,        -- seconds between warnings to a player who is inside without agreeing
    alarmAfter = 3,        -- warnings before the alarm output turns on
    textScale = 1,
    admins = {Yeeetiamus_Games},           -- usernames allowed to use the !tos admin commands and skip the gate
}

local SIDES = {top = true, bottom = true, left = true, right = true, front = true, back = true}

local function clampN(v, lo, hi, d)
    v = tonumber(v)
    if v == nil then return d end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function TOS.loadConfig(path)
    local ok, all = pcall(dofile, path or "/casinoSettings.lua")
    local user = (ok and type(all) == "table" and type(all.tos) == "table") and all.tos or {}
    local c = {}
    for k, v in pairs(DEFAULTS) do c[k] = v end
    for k, v in pairs(user) do c[k] = v end
    c.casinoName = tostring(c.casinoName)
    c.tosVersion = clampN(c.tosVersion, 0, 1e9, 1)
    c.acceptDays = clampN(c.acceptDays, 0, 3650, 30)
    c.entryRange = clampN(c.entryRange, 1, 200, 6)
    c.casinoRange = clampN(c.casinoRange, c.entryRange, 500, 40)
    c.touchRange = clampN(c.touchRange, 1, 50, 4)
    c.doorSeconds = clampN(c.doorSeconds, 1, 600, 8)
    c.warnEvery = clampN(c.warnEvery, 1, 3600, 15)
    c.alarmAfter = clampN(c.alarmAfter, 1, 100, 3)
    c.textScale = clampN(c.textScale, 0.5, 5, 1)
    if not SIDES[c.doorSide] then c.doorSide = DEFAULTS.doorSide end
    if not SIDES[c.alarmSide] then c.alarmSide = DEFAULTS.alarmSide end
    c.adminSet = {}
    if type(c.admins) ~= "table" then c.admins = {} end
    for _, n in ipairs(c.admins) do c.adminSet[tostring(n):lower()] = true end
    local rules = {}
    if type(user.rules) == "table" then
        for _, r in ipairs(user.rules) do
            if type(r) == "table" and r[1] and r[2] then rules[#rules + 1] = {tostring(r[1]), tostring(r[2])} end
        end
    end
    c.rules = #rules > 0 and rules or DEFAULT_RULES
    return c
end

-- ---------- text layout ----------
local function wrap(text, width)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        while #word > width do
            if line ~= "" then lines[#lines + 1] = line; line = "" end
            lines[#lines + 1] = word:sub(1, width)
            word = word:sub(width + 1)
        end
        if line == "" then line = word
        elseif #line + 1 + #word <= width then line = line .. " " .. word
        else lines[#lines + 1] = line; line = word end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end
TOS.wrap = wrap

-- pages of {kind, text} lines; a rule is kept together on one page when it fits
function TOS.buildPages(rules, width, rows)
    local pages, cur = {}, {}
    for i, r in ipairs(rules) do
        local block = {{kind = "title", text = (i .. ". " .. r[1]):sub(1, width)}}
        for _, l in ipairs(wrap(r[2], width - 3)) do block[#block + 1] = {kind = "body", text = "   " .. l} end
        if #cur > 0 and #cur + 1 + #block > rows then pages[#pages + 1] = cur; cur = {} end
        if #cur > 0 then cur[#cur + 1] = {kind = "blank", text = ""} end
        for _, l in ipairs(block) do
            if #cur >= rows then pages[#pages + 1] = cur; cur = {} end
            cur[#cur + 1] = l
        end
    end
    if #cur > 0 then pages[#pages + 1] = cur end
    if #pages == 0 then pages[1] = {} end
    return pages
end

-- ---------- who has agreed ----------
function TOS.newStore(cfg, nowFn)
    local st = {rec = {}}
    local function key(n) return tostring(n):lower() end
    function st.accept(name) st.rec[key(name)] = {t = nowFn(), v = cfg.tosVersion} end
    function st.isValid(name)
        local r = st.rec[key(name)]
        if not r or r.v ~= cfg.tosVersion then return false end
        if cfg.acceptDays > 0 and nowFn() - r.t > cfg.acceptDays * 86400 then return false end
        return true
    end
    function st.revoke(name)
        local had = st.rec[key(name)] ~= nil
        st.rec[key(name)] = nil
        return had
    end
    function st.isAdmin(name) return cfg.adminSet[key(name)] == true end
    function st.allowed(name) return st.isAdmin(name) or st.isValid(name) end
    function st.list()
        local out = {}
        for k in pairs(st.rec) do if st.isValid(k) then out[#out + 1] = k end end
        table.sort(out)
        return out
    end
    return st
end

function TOS.save(store, path)
    local f = fs.open(path, "w")
    if not f then return false end
    f.write(textutils.serialise(store.rec))
    f.close()
    return true
end

function TOS.load(store, path)
    if not fs.exists(path) then return 0 end
    local f = fs.open(path, "r")
    if not f then return 0 end
    local data = textutils.unserialise(f.readAll())
    f.close()
    local n = 0
    if type(data) == "table" then
        for k, r in pairs(data) do
            if type(k) == "string" and type(r) == "table" and tonumber(r.t) and tonumber(r.v) then
                store.rec[k] = {t = tonumber(r.t), v = tonumber(r.v)}
                n = n + 1
            end
        end
    end
    return n
end

-- ---------- door + warnings ----------
-- open only when somebody is at the door and EVERY person there has agreed (stops tailgating)
function TOS.doorShouldOpen(near, store)
    if #near == 0 then return false end
    for _, n in ipairs(near) do if not store.allowed(n) then return false end end
    return true
end

-- people inside the casino, away from the entrance, who never agreed
function TOS.findViolators(inside, near, store)
    local nearSet = {}
    for _, n in ipairs(near) do nearSet[n:lower()] = true end
    local out = {}
    for _, n in ipairs(inside) do
        if not nearSet[n:lower()] and not store.allowed(n) then out[#out + 1] = n end
    end
    return out
end

function TOS.newWarner(cfg)
    local w = {state = {}}
    -- returns the warnings to send now and whether the alarm should be on
    function w.tick(violators, now)
        local actions, alarm, present = {}, false, {}
        for _, n in ipairs(violators) do
            local k = n:lower()
            present[k] = true
            local s = w.state[k]
            if not s then s = {strikes = 0, last = -1e9}; w.state[k] = s end
            if now - s.last >= cfg.warnEvery then
                s.strikes = s.strikes + 1
                s.last = now
                actions[#actions + 1] = {name = n, strikes = s.strikes}
            end
            if s.strikes >= cfg.alarmAfter then alarm = true end
        end
        for k in pairs(w.state) do if not present[k] then w.state[k] = nil end end
        return actions, alarm
    end
    return w
end

-- two right-clicks on the detector within `window` seconds count as agreeing
function TOS.newClickConfirm(window)
    local c = {pending = {}}
    function c.click(name, now)
        local k = name:lower()
        local t = c.pending[k]
        if t and now - t <= window then c.pending[k] = nil; return true end
        c.pending[k] = now
        return false
    end
    return c
end

-- chat text -> command, args   (needs ! or $ in front, or isHidden for messages whose $ was stripped)
function TOS.parseChat(message, isHidden)
    local m = tostring(message or ""):lower()
    m = m:gsub("^%s+", ""):gsub("%s+$", "")
    local first = m:sub(1, 1)
    local prefixed = false
    if first == "!" or first == "$" then m = m:sub(2); prefixed = true end
    if not prefixed and not isHidden then return nil end
    local words = {}
    for w in m:gmatch("%S+") do words[#words + 1] = w end
    if words[1] == "tos" then table.remove(words, 1); if #words == 0 then words[1] = "rules" end end
    local cmd = table.remove(words, 1)
    if cmd == "agree" or cmd == "rules" or cmd == "status" or cmd == "revoke" or cmd == "allow" or cmd == "list" then
        return cmd, words
    end
    return nil
end

-- ================= runtime =================
local function main()
    local cfg = TOS.loadConfig("/casinoSettings.lua")
    local mon = peripheral.find("monitor")
    local pd = peripheral.find("player_detector")
    local chat = peripheral.find("chat_box")
    local spk = peripheral.find("speaker")
    local missing = {}
    if not mon then missing[#missing + 1] = "advanced monitor" end
    if not pd then missing[#missing + 1] = "Player Detector" end
    if not chat then missing[#missing + 1] = "Chat Box" end
    if #missing > 0 then error("missing: " .. table.concat(missing, ", ") .. " (touching the computer or on a wired modem)") end
    if not mon.isColor() then error("the monitor must be an ADVANCED monitor") end
    mon.setTextScale(cfg.textScale)

    local function now() return (os.epoch and os.epoch("utc") or os.time() * 1000) / 1000 end
    local store = TOS.newStore(cfg, now)
    local DATA, LOG = "/tos_accepted.lua", "/tos_log.txt"
    TOS.load(store, DATA)
    local warner = TOS.newWarner(cfg)
    local clicks = TOS.newClickConfirm(15)

    local function log(line)
        local f = fs.open(LOG, "a")
        if f then f.writeLine(os.date("!%Y-%m-%d %H:%M:%S", math.floor(now())) .. " UTC  " .. line); f.close() end
    end

    local function say(name, msg)
        pcall(chat.sendMessageToPlayer, msg, name, "Casino", "[]", "&6")
    end
    local function toast(name, title, msg)
        pcall(chat.sendToastToPlayer, msg, title, name, "Casino", "[]", "&6")
    end
    local function sound(name, vol, pitch)
        if spk then pcall(spk.playSound, name, vol or 1, pitch or 1) end
    end

    -- ----- screen -----
    local W, H = mon.getSize()
    local pages, page, mode, modeUntil, modeName, status, statusUntil
    local function layout()
        W, H = mon.getSize()
        pages = TOS.buildPages(cfg.rules, W - 2, math.max(1, H - 5))
        if page == nil or page > #pages then page = 1 end
    end
    layout()
    mode = "rules"

    local function fill(x1, y1, x2, y2, bg)
        mon.setBackgroundColor(bg)
        for y = y1, y2 do mon.setCursorPos(x1, y); mon.write(string.rep(" ", x2 - x1 + 1)) end
    end
    local function txt(x, y, s, fg, bg)
        mon.setBackgroundColor(bg or colors.black)
        mon.setTextColor(fg or colors.white)
        mon.setCursorPos(x, y)
        mon.write(s)
    end
    local function ctext(y, s, fg, bg)
        txt(math.max(1, math.floor((W - #s) / 2) + 1), y, s, fg, bg)
    end
    local function button(x, w, label, bg, fg)
        fill(x, H - 1, x + w - 1, H, bg)
        txt(x + math.floor((w - #label) / 2), H - 1, label, fg or colors.black, bg)
        return {x1 = x, x2 = x + w - 1, y1 = H - 1, y2 = H}
    end
    local function inside(b, x, y) return b and x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 end

    local backB, nextB, agreeB
    local function render()
        mon.setBackgroundColor(colors.black)
        mon.clear()
        if mode == "welcome" then
            fill(1, 1, W, H, colors.green)
            ctext(math.floor(H / 2) - 1, "WELCOME", colors.white, colors.green)
            ctext(math.floor(H / 2), modeName:sub(1, W - 2), colors.yellow, colors.green)
            ctext(math.floor(H / 2) + 1, "terms accepted", colors.white, colors.green)
            ctext(math.floor(H / 2) + 2, "the door is open", colors.white, colors.green)
            return
        end
        fill(1, 1, W, 1, colors.blue)
        ctext(1, (cfg.casinoName .. " RULES"):sub(1, W), colors.white, colors.blue)
        txt(2, 2, "read every page, then agree", colors.lightGray)
        local y = 3
        for _, l in ipairs(pages[page]) do
            if l.kind == "title" then txt(2, y, l.text, colors.yellow)
            elseif l.kind == "body" then txt(2, y, l.text, colors.white) end
            y = y + 1
        end
        local info = "page " .. page .. "/" .. #pages
        if status and now() < statusUntil then info = status end
        fill(1, H - 2, W, H - 2, colors.black)
        txt(2, H - 2, info:sub(1, W - 2), (status and now() < statusUntil) and colors.orange or colors.lightGray)
        backB = page > 1 and button(1, 8, "BACK", colors.lightGray) or nil
        nextB = page < #pages and button(W - 7, 8, "NEXT", colors.lightGray) or nil
        if page == #pages then
            agreeB = button(10, W - 18, "I AGREE", colors.lime)
        else
            agreeB = nil
            fill(10, H - 1, W - 9, H, colors.gray)
            txt(10 + math.floor((W - 18 - 11) / 2), H - 1, "read all rules", colors.lightGray, colors.gray)
        end
    end
    local function flash(msg, secs)
        status, statusUntil = msg, now() + (secs or 4)
        render()
    end

    -- ----- door / alarm -----
    local doorUntil, doorOn, alarmOn = 0, false, false
    local function setDoor(on)
        if on ~= doorOn then doorOn = on; redstone.setOutput(cfg.doorSide, on) end
    end
    local function setAlarm(on)
        if on ~= alarmOn then
            alarmOn = on
            redstone.setOutput(cfg.alarmSide, on)
            if on then log("ALARM on") else log("ALARM off") end
        end
    end
    setDoor(false); setAlarm(false)

    local function accept(name, how)
        store.accept(name)
        TOS.save(store, DATA)
        log("AGREED " .. name .. " via " .. how)
        say(name, "&aThanks " .. name .. ", you agreed to the casino rules. Enjoy, and respect the build!")
        toast(name, "Casino", "Terms accepted. Welcome!")
        doorUntil = math.max(doorUntil, now() + cfg.doorSeconds)
        mode, modeName, modeUntil = "welcome", name, now() + 5
        sound("block.note_block.pling", 1, 2)
        render()
    end

    local function sendRules(name)
        say(name, "&eRules: " .. #cfg.rules .. " in total. Read them on the monitor at the entrance.")
        for i, r in ipairs(cfg.rules) do say(name, "&f" .. i .. ". &e" .. r[1] .. "&f - " .. r[2]) end
        say(name, "&aType !agree (or $agree to keep it private) to accept.")
    end

    -- ----- events -----
    local function playersNear(range)
        local ok, list = pcall(pd.getPlayersInRange, range)
        if not ok or type(list) ~= "table" then return nil end
        return list
    end

    local greeted, detectorWarned = {}, false
    local function tick()
        local t = now()
        if mode == "welcome" and t >= modeUntil then mode = "rules"; page = 1; render() end
        local near = playersNear(cfg.entryRange)
        local inside = playersNear(cfg.casinoRange)
        if near == nil or inside == nil then
            if not detectorWarned then detectorWarned = true; log("detector error (range too large for the Player Detector config?)") end
            near, inside = {}, {}
        end
        if TOS.doorShouldOpen(near, store) then doorUntil = math.max(doorUntil, t + 2) end
        setDoor(t < doorUntil)

        for _, n in ipairs(near) do
            if not store.allowed(n) and (greeted[n:lower()] or -1e9) + 60 <= t then
                greeted[n:lower()] = t
                say(n, "&6Welcome to " .. cfg.casinoName .. "! Read the rules on the monitor and agree to enter. Type !rules to see them here.")
                toast(n, cfg.casinoName, "Please agree to the rules at the entrance")
            end
        end

        local actions, alarm = warner.tick(TOS.findViolators(inside, near, store), t)
        for _, a in ipairs(actions) do
            log("WARNED " .. a.name .. " (" .. a.strikes .. ")")
            say(a.name, "&cWARNING " .. a.strikes .. "/" .. cfg.alarmAfter .. ": you have not agreed to the casino rules. Go back to the entrance and agree, or leave.")
            toast(a.name, "Casino warning", "Agree to the rules at the entrance or leave")
            sound("block.note_block.bass", 1, 0.8)
        end
        setAlarm(alarm)
        if alarm then sound("block.note_block.bell", 1, 0.5) end
    end

    local function onTouch(x, y)
        if mode ~= "rules" then return end
        if inside(backB, x, y) then page = page - 1; render()
        elseif inside(nextB, x, y) then page = page + 1; render()
        elseif inside(agreeB, x, y) then
            local list = playersNear(cfg.touchRange) or {}
            if #list == 1 then accept(list[1], "monitor")
            elseif #list == 0 then flash("step closer to the monitor")
            else flash("several players here: right-click detector or type !agree", 6) end
        end
    end

    local function onChat(name, message, isHidden)
        local cmd, args = TOS.parseChat(message, isHidden)
        if not cmd then return end
        if cmd == "agree" then accept(name, "chat")
        elseif cmd == "rules" then sendRules(name)
        elseif cmd == "status" then
            say(name, store.allowed(name) and "&aYou have agreed to the rules." or "&cYou have not agreed yet. Type !agree after reading !rules.")
        elseif store.isAdmin(name) then
            if cmd == "revoke" and args[1] then
                local had = store.revoke(args[1]); TOS.save(store, DATA)
                log("REVOKED " .. args[1] .. " by " .. name)
                say(name, had and ("&eRevoked " .. args[1]) or ("&c" .. args[1] .. " had not agreed"))
            elseif cmd == "allow" and args[1] then
                store.accept(args[1]); TOS.save(store, DATA)
                log("ALLOWED " .. args[1] .. " by " .. name)
                say(name, "&aMarked " .. args[1] .. " as agreed")
            elseif cmd == "list" then
                local l = store.list()
                say(name, "&e" .. #l .. " valid agreements" .. (#l > 0 and (": " .. table.concat(l, ", ")) or ""))
            end
        else
            say(name, "&cThat command is for casino admins.")
        end
    end

    local function onClick(name)
        if store.isValid(name) then say(name, "&aYou already agreed. Come on in!"); return end
        if clicks.click(name, now()) then accept(name, "detector")
        else
            say(name, "&eRead the rules on the monitor (or type !rules). Right-click the detector again within 15 seconds to agree.")
        end
    end

    render()
    log("TOS gate started, version " .. cfg.tosVersion)
    local timer = os.startTimer(1)
    while true do
        local ev = {os.pullEvent()}
        local e = ev[1]
        if e == "timer" and ev[2] == timer then
            tick()
            timer = os.startTimer(1)
        elseif e == "monitor_touch" then onTouch(ev[3], ev[4])
        elseif e == "chat" then onChat(ev[2], ev[3], ev[5])
        elseif e == "playerClick" then onClick(ev[2])
        elseif e == "monitor_resize" then layout(); render()
        end
    end
end

if not TOS_TEST then
    local ok, err = pcall(main)
    if not ok then
        redstone.setOutput("back", false)
        term.clear(); term.setCursorPos(1, 1)
        print("TOS gate stopped: " .. tostring(err))
        print("rebooting in 15 seconds")
        sleep(15)
        os.reboot()
    end
end
