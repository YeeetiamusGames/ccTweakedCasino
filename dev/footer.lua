
-- ================= main loop (shared) =================
local function idleScreen()
    local blink = true
    while true do
        if cardPresent() then
            local id = readCard()
            if id and id ~= "" then
                userId = id
                return
            end
        end
        clear(colors.green)
        ctext(math.floor(H / 2) - 2, GAME.name, colors.yellow, colors.green)
        ctext(math.floor(H / 2), "casino fortuna", colors.white, colors.green)
        if GAME.idle then GAME.idle(blink) end
        ctext(H - 2, blink and "insert your casino card" or "                       ", colors.black, colors.green)
        blink = not blink
        local timer = os.startTimer(1.5)
        while true do
            local e, a = os.pullEvent()
            if e == "timer" and a == timer then break end
            if cardPresent() then
                local id = readCard()
                if id and id ~= "" then
                    userId = id
                    return
                end
            end
            if e == "disk" then break end
        end
    end
end

local function notEnough()
    clear(colors.black)
    ctext(math.floor(H / 2), "not enough chips", colors.yellow, colors.black)
    ctext(math.floor(H / 2) + 2, "take your card to leave", colors.gray, colors.black)
    while cardPresent() do sleep(0.5) end
end

local function main()
    assert(monitor ~= nil, "no monitor connected =[")
    assert(casinoNetwerk ~= nil, "no modem connected =[")
    assert(drive ~= nil, "no disk drive connected =[")
    casinoNetwerk.open(os.getComputerID())
    monitor.setTextScale(GAME.scale)
    term.redirect(monitor)
    W, H = term.getSize()
    if W < GAME.minW or H < GAME.minH then
        term.redirect(term.native())
        error("Monitor is " .. W .. "x" .. H .. " characters, needs at least " .. GAME.minW .. "x" .. GAME.minH
            .. " (about " .. GAME.blocks .. " blocks wide x tall). Build it bigger =]")
    end
    math.randomseed(os.epoch("utc") % 2147483647)
    for _ = 1, 5 do math.random() end

    while true do
        idleScreen()
        snd("entity.villager.yes")
        while cardPresent() do
            local balance = updateLabel(userId)
            if balance < 1 then
                notEnough()
                break
            end
            local delta = GAME.round(userId, balance)
            if delta == nil then break end   -- card was taken before the round started
            if delta ~= 0 then changeBalance(delta, userId) end
        end
        userId = nil
    end
end

main()
