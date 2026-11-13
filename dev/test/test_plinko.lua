dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("plinko.lua")
math.randomseed(5)
local R = GAME.rows

local s = 0
for _, p in ipairs(GAME.binProbs) do s = s + p end
assert(math.abs(s - 1) < 1e-12 and GAME.binProbs[1] == 1 / 256 and GAME.binProbs[5] == 70 / 256)

local function exact(plan)
    local sum, ret, hit = 0, 0, 0
    for j = 1, R + 1 do
        sum = sum + plan.probs[j]
        ret = ret + plan.probs[j] * math.floor(1000 * plan.cents[j] / 100) / 1000
        if plan.cents[j] >= 100 then hit = hit + plan.probs[j] end
    end
    assert(math.abs(sum - 1) < 1e-9)
    return ret, hit
end

for _, risk in ipairs({"low", "medium", "high"}) do
    for _, cfg in ipairs({{0.97, 0.40}, {0.97, 0.289}, {0.99, 0.50}, {0.92, 0.25}, {0.97, 0.60}, {1.0, 0.45}}) do
        local plan = GAME.buildPlan(risk, cfg[1], cfg[2])
        assert(#plan.cents == R + 1 and #plan.notes == 0, risk .. " " .. cfg[1] .. "/" .. cfg[2] .. " " .. table.concat(plan.notes, ";"))
        for j = 1, R + 1 do assert(plan.cents[j] == plan.cents[R + 2 - j] and plan.probs[j] == plan.probs[R + 2 - j]) end
        local ret, hit = exact(plan)
        assert(math.abs(ret - cfg[1]) < 0.006, string.format("%s rtp %.4f vs %.2f", risk, ret, cfg[1]))
        assert(math.abs(hit - cfg[2]) < 1e-9, string.format("%s hit %.4f vs %.2f", risk, hit, cfg[2]))
        if cfg[1] == 0.97 and cfg[2] == 0.40 then
            local top = 0
            for _, c in ipairs(plan.cents) do top = math.max(top, c) end
            print(string.format("plinko %-6s defaults: return %.4f, balls paying 1x+ %.1f%%, top prize x%.1f", risk, ret, hit * 100, top / 100))
        end
    end
end
-- an unreachable combination must be reported, not silently wrong
local bad = GAME.buildPlan("low", 0.5, 0.85)
assert(#bad.notes > 0)

-- bin selection follows the plan; paths end in the chosen bin and each step is fair for a middle bin
local plan = GAME.PLANS.medium
local N, cnt = 400000, {}
for j = 0, R do cnt[j] = 0 end
for _ = 1, N do local b = GAME.pickBin(plan.probs); cnt[b] = cnt[b] + 1 end
for j = 0, R do assert(math.abs(cnt[j] / N - plan.probs[j + 1]) < 0.004, "bin " .. j) end
local rights = {}
for i = 1, R do rights[i] = 0 end
for bin = 0, R do
    for _ = 1, 200 do
        local path = GAME.makePath(bin)
        assert(#path == R)
        local sum = 0
        for _, v in ipairs(path) do assert(v == 0 or v == 1); sum = sum + v end
        assert(sum == bin)
    end
end
for _ = 1, 40000 do
    local path = GAME.makePath(4)
    for i = 1, R do rights[i] = rights[i] + path[i] end
end
for i = 1, R do assert(math.abs(rights[i] / 40000 - 0.5) < 0.012, "step " .. i .. " biased") end
print("plinko asserts ok")
