local ok = true
for i = 1, #arg do
    local f, e = loadfile(arg[i])
    if f then print("syntax ok: " .. arg[i]) else print("SYNTAX ERROR: " .. e); ok = false end
end
os.exit(ok and 0 or 1)
