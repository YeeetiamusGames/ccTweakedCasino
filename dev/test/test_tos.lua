TOS_TEST = true
local dir = (arg[0]:match("^(.*)/test/") or ".")
-- minimal CC stubs
local files = {}
fs = {exists = function(p) return files[p] ~= nil end,
      open = function(p, m)
        if m == "r" then local d = files[p]; return {readAll = function() return d end, close = function() end} end
        local buf = (m == "a" and files[p]) or ""
        return {write = function(s) buf = buf .. s end, writeLine = function(s) buf = buf .. s .. "\n" end,
                close = function() files[p] = buf end}
      end}
textutils = {
  serialise = function(t) local o = {} for k, r in pairs(t) do o[#o+1] = k .. "," .. r.t .. "," .. r.v end return table.concat(o, ";") end,
  unserialise = function(s) local t = {} for k, a, b in s:gmatch("([^,;]+),([^,;]+),([^,;]+)") do t[k] = {t = tonumber(a), v = tonumber(b)} end return t end}
dofile(dir .. "/tos.lua")

-- 1. shipped settings load, with sane values
local real = dofile
local cfg = TOS.loadConfig(dir .. "/casinoSettings.lua")
assert(cfg.doorSide == "back" and cfg.alarmSide == "left" and cfg.warnEvery == 15 and #cfg.rules == 9, "default config")
-- bad settings are repaired
local badpath = os.tmpname()
local f = io.open(badpath, "w")
f:write('return {tos={doorSide="sideways",alarmSide=5,entryRange=-3,casinoRange=2,warnEvery="x",admins={"Bob"},rules={{"A","aaa"},{"bad"}}}}'); f:close()
local bad = TOS.loadConfig(badpath)
assert(bad.doorSide == "back" and bad.alarmSide == "left", "bad sides fall back")
assert(bad.entryRange == 1 and bad.casinoRange >= bad.entryRange and bad.warnEvery == 15, "numbers clamped")
assert(bad.adminSet.bob and #bad.rules == 1 and bad.rules[1][1] == "A", "admins + custom rules")
assert(#TOS.loadConfig("/does/not/exist").rules == 9, "missing file -> defaults")
os.remove(badpath)

-- 2. wrapping and pages
for _, w in ipairs({20, 33, 37}) do
    for _, l in ipairs(TOS.wrap("Do not break, place, replace or change any block in the casino supercalifragilisticexpialidocious", w)) do
        assert(#l <= w, "line too long at width " .. w)
    end
end
for _, size in ipairs({{37, 14}, {20, 6}, {60, 30}}) do
    local pages = TOS.buildPages(cfg.rules, size[1], size[2])
    local titles = 0
    for _, p in ipairs(pages) do
        assert(#p <= size[2] and #p > 0, "page rows")
        assert(p[1].kind ~= "blank", "page starts with blank")
        for _, l in ipairs(p) do assert(#l.text <= size[1], "text wider than screen"); if l.kind == "title" then titles = titles + 1 end end
    end
    assert(titles == #cfg.rules, "every rule appears exactly once")
end

-- 3. store: accept, expire, version bump, revoke, admin, persistence
local clock = 1000000
local c2 = TOS.loadConfig("/none"); c2.adminSet = {boss = true}
local st = TOS.newStore(c2, function() return clock end)
assert(not st.allowed("Steve"))
st.accept("Steve"); assert(st.isValid("STEVE") and st.allowed("steve"), "case-insensitive")
clock = clock + 29 * 86400; assert(st.isValid("steve"), "still valid after 29 days")
clock = clock + 2 * 86400; assert(not st.isValid("steve"), "expired after 31 days")
st.accept("Steve"); c2.tosVersion = 2; assert(not st.isValid("steve"), "version bump forces re-agree")
c2.tosVersion = 1; assert(st.isValid("steve"))
assert(st.revoke("steve") and not st.isValid("steve") and not st.revoke("steve"))
assert(st.allowed("Boss") and not st.isValid("boss"), "admins skip the gate")
c2.acceptDays = 0; st.accept("Al"); clock = clock + 9999 * 86400; assert(st.isValid("al"), "acceptDays 0 = forever")
st.accept("Zed"); assert(table.concat(st.list(), ",") == "al,zed")
assert(TOS.save(st, "/d.lua")); local st2 = TOS.newStore(c2, function() return clock end)
assert(TOS.load(st2, "/d.lua") == 2 and st2.isValid("zed") and st2.isValid("al"), "save/load")
assert(TOS.load(TOS.newStore(c2, function() return 0 end), "/missing") == 0)
files["/garbage"] = ""; assert(TOS.load(TOS.newStore(c2, function() return 0 end), "/garbage") == 0)

-- 4. door only opens when everybody near has agreed
local s3 = TOS.newStore(TOS.loadConfig("/none"), function() return 1 end); s3.accept("ok")
assert(not TOS.doorShouldOpen({}, s3))
assert(TOS.doorShouldOpen({"OK"}, s3))
assert(not TOS.doorShouldOpen({"ok", "sneaky"}, s3), "tailgater blocks the door")

-- 5. violators + warning ladder + alarm
local inside = {"ok", "Newbie", "Reader", "Ghost"}
local v = TOS.findViolators(inside, {"reader"}, s3)
assert(#v == 2 and v[1] == "Newbie" and v[2] == "Ghost", "agreed + people still at the entrance are not violators")
local w = TOS.newWarner({warnEvery = 15, alarmAfter = 3})
local a, alarm = w.tick({"Newbie"}, 100); assert(#a == 1 and a[1].strikes == 1 and not alarm)
a, alarm = w.tick({"Newbie"}, 110); assert(#a == 0 and not alarm, "no spam inside warnEvery")
a, alarm = w.tick({"Newbie"}, 115); assert(#a == 1 and a[1].strikes == 2 and not alarm)
a, alarm = w.tick({"Newbie"}, 130); assert(#a == 1 and a[1].strikes == 3 and alarm, "alarm after 3 warnings")
a, alarm = w.tick({}, 131); assert(#a == 0 and not alarm, "alarm off when they leave or agree")
a, alarm = w.tick({"Newbie"}, 200); assert(a[1].strikes == 1, "strikes reset after leaving")

-- 6. two-click confirm
local cc = TOS.newClickConfirm(15)
assert(not cc.click("Amy", 0) and cc.click("amy", 10), "second click inside window agrees")
assert(not cc.click("Amy", 100) and not cc.click("Amy", 120), "too slow = starts over")
assert(cc.click("Amy", 130))

-- 7. chat commands
local function p(m, h) local c, a = TOS.parseChat(m, h); return c, a and a[1] end
assert(p("!agree") == "agree" and p("$agree") == "agree" and p("  !AGREE  ") == "agree")
assert(p("agree") == nil, "bare word in public chat is ignored")
assert(p("agree", true) == "agree", "hidden message with $ stripped")
assert(p("!tos") == "rules" and p("!rules") == "rules" and p("!tos rules") == "rules")
local c, arg1 = p("!tos revoke Steve"); assert(c == "revoke" and arg1 == "steve")
assert(p("!tos list") == "list" and p("!tos allow Bob") == "allow" and p("!status") == "status")
assert(p("hello everyone") == nil and p("!dance") == nil and p("") == nil and p(nil) == nil)
print("tos asserts ok")
