dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("slots.lua")
math.randomseed(9)

-- every result must be drawable: the triple shown evaluates to exactly the chosen return
for _, ret in ipairs({0, 1, 2, 4, 5, 8, 12, 25, 60, 150}) do
    for _ = 1, 300 do
        local a, b, c = GAME.makeTriple(ret)
        assert(GAME.eval(a, b, c) == ret, "triple for " .. ret .. " evaluates to " .. GAME.eval(a, b, c))
    end
end

local function check(rtp, hit, push, expectClamp)
    local t = GAME.slotTable(rtp, hit, push)
    local sum, ret, h, pu = 0, 0, 0, 0
    for _, o in ipairs(t.list) do
        assert(o.p >= 0)
        sum = sum + o.p; ret = ret + o.p * o.ret
        if o.ret >= 2 then h = h + o.p elseif o.ret == 1 then pu = pu + o.p end
    end
    assert(math.abs(sum - 1) < 1e-9, "probabilities sum")
    assert(math.abs(ret - t.rtp) < 1e-6, string.format("rtp %.6f vs %.6f", ret, t.rtp))
    assert(math.abs(h - t.hit) < 1e-9 and math.abs(pu - t.push) < 1e-9)
    if not expectClamp then
        assert(math.abs(h - hit) < 1e-9 and math.abs(ret - rtp) < 1e-6)
    else
        assert(#t.notes > 0, "a clamped setting must produce a warning")
    end
    print(string.format("slots rtp %.2f hit %.2f push %.2f -> exact return %.4f, wins %.1f%%, bet back %.1f%%, 150x once per %d spins",
        rtp, hit, push, ret, h * 100, pu * 100, math.floor(1 / t.list[6].p + 0.5)))
    return t
end
check(0.97, 0.35, 0.10)          -- defaults
check(0.97, 0.20, 0.10)
check(0.99, 0.40, 0.05)
check(0.92, 0.25, 0.10)
check(1.00, 0.30, 0.00)
check(0.97, 0.90, 0.10, true)    -- impossible: clamped
check(0.97, 0.001, 0.10, true)   -- impossible: clamped

-- sampling follows the table
local t = GAME.TABLE
local N, cnt = 500000, {}
for _ = 1, N do local r = GAME.pickOutcome(t); cnt[r] = (cnt[r] or 0) + 1 end
for _, o in ipairs(t.list) do
    assert(math.abs((cnt[o.ret] or 0) / N - o.p) < 0.004, "frequency of " .. o.ret)
end
local tot = 0
for r, n in pairs(cnt) do tot = tot + r * n end
print(string.format("slots default: simulated return %.4f over %d spins", tot / N, N))
assert(math.abs(tot / N - 0.97) < 0.03)
print("slots asserts ok")
