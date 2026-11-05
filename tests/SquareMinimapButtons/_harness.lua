-- Square Minimap Buttons tests: a tiny test API (describe, it, assertions). The runner
-- tools/addon_test.mjs loads stubs.lua and this file before the addon files and each test file
-- and reads the result through __summary().

local results = { passed = 0, failed = 0 }
local path = {}

local function describeValue(v)
    if type(v) == "string" then
        return string.format("%q", v)
    elseif type(v) ~= "table" then
        return tostring(v)
    end
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = tostring(k) .. "=" .. describeValue(v[k])
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a, b)
    if a == b then
        return true
    end
    if type(a) == "number" and type(b) == "number" then
        return a == b
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

DeepEqual = deepEqual

function describe(name, fn)
    path[#path + 1] = name
    fn()
    path[#path] = nil
end

function it(name, fn)
    local full = table.concat(path, " > ") .. " > " .. name
    local ok, err = xpcall(fn, function(e)
        return debug and debug.traceback and debug.traceback(tostring(e), 2) or tostring(e)
    end)
    if ok then
        results.passed = results.passed + 1
        print("  ok    " .. full)
    else
        results.failed = results.failed + 1
        print("  FAIL  " .. full)
        print("        " .. tostring(err):gsub("\n", "\n        "))
    end
end

local function fail(msg, level)
    error(msg, (level or 2) + 1)
end

function assert_eq(actual, expected, msg)
    if not deepEqual(actual, expected) then
        fail(string.format("%s\n  expected: %s\n  actual:   %s", msg or "values differ",
            describeValue(expected), describeValue(actual)))
    end
end

function assert_true(v, msg)
    if not v then
        fail(msg or "expected a true value, got " .. describeValue(v))
    end
end

function assert_false(v, msg)
    if v then
        fail(msg or "expected a false value, got " .. describeValue(v))
    end
end

function assert_nil(v, msg)
    if v ~= nil then
        fail(msg or "expected nil, got " .. describeValue(v))
    end
end

function assert_near(actual, expected, eps, msg)
    eps = eps or 1e-6
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        fail(string.format("%s: expected %s +- %s, got %s", msg or "not near", tostring(expected), tostring(eps), describeValue(actual)))
    end
end

function assert_contains(haystack, needle, msg)
    if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
        fail(string.format("%s: %s does not contain %s", msg or "missing text", describeValue(haystack), describeValue(needle)))
    end
end

function __summary()
    return results.passed, results.failed
end
