--[[
    LuaBenchmark: Native module for benchmarking Lua code.
        - Features:
            - File output.
            - Console output.
            - Memory usage benchmarking.
            - Comparison/rival benchmarking. (WIP)
            - Full LuaJIT & Lua 5.1+ compatibility.
            - Optional exclusion of natural Lua overheads.
                - Removes the overhead created by the internal loops used to perform iterations.
                - Callbacks cost ~2.8e008 CPU seconds to construct a call. This obfuscates the results often.
--]]

local module = {
    --- The overhead it takes to construct a function call. Used internally for the <code>ignoreOverhead</code> option.
    callOverhead = nil,
    --- The overhead it takes to construct a loop. Used internally for the <code>ignoreOverhead</code> option.
    loopOverhead = nil,
    --- Whether to remove inherent Lua function call overhead from callbacks.
    ignoreOverhead = false,
    --- Whether to display memory usage offsets during benchmarks.
    outputMemoryUsage = false,
    --- Setting this to a file will write all the benchmark data into it.
    outputFileHandle = nil
}

local clock = os.clock
local wentFirst = false
local function formatNumber(i)
    return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local ver = nil                                      -- The version of this intepreter. Reads for LuaJIT and Lua.
local jit = _G["jit"]                                -- Self-evident.
local sep = "LuaBenchmark || Running benchmark -> "  -- Separator string used in benchmark outputs.

if jit ~= nil then
    ver = jit.version
else
    ver = _VERSION
end

-- Calculate the size of the separator.
do
    local res = {}

    for i = 1, #sep + #ver + 2 do
        res[i] = "="
    end

    sep = ("%s(%s)\n%s\n"):format(sep, ver, table.concat(res))
end

-- Calculate call overheads (i.e, third-party loop instructions, callback function overhead).
-- This module will optionally remove these metrics from the final result to measure the true cost of your operation.
do
    -- Call overhead.
    local function dummyCall() end
    local currentTime = clock()
    for i = 1, 1000000 do dummyCall() end
    local finishedTime = clock()
    module.callOverhead = (finishedTime - currentTime) / 1000000 -- 2.8e-008, Lua 5.4

    -- Loop overhead.
    currentTime = clock()
    for i = 1, 1000000 do dummyCall() end
    finishedTime = clock()
    module.loopOverhead = (finishedTime - (module.callOverhead * 1000000)) / 1000000 -- 3e-008, Lua 5.4

    -- If you're wondering why so many iterations are used, it produces an average per-iteration.
    -- Some Lua interpreters would also optimize away the loop instructions if I only used 1 iteration.
    -- Some Lua interpreters would also optimize away the loop if nothing was done inside it.
end

--- Define a benchmark category. This is used to nest <code>member</code> calls.
-- @tparam string description The name or description for these operations.
-- @tparam function callback A callback nesting <code>member</code> calls.
function module.benchmark(description, callback)
    local s
    local handle = module.outputFileHandle

    if wentFirst == true then
        s = "\n" .. description
    else
        s = sep .. description
        wentFirst = true
    end

    if io.type(handle) == "file" then
        handle:write(s)
    end

    io.write(s)
    callback()
end

--- Benchmark the performance of a function.
-- @tparam function callback The function to execute.
-- @tparam number itercount The amount of times to execute this function.
-- @param ... The arguments to pass to your callback.
-- @treturn number The execution time.
-- @treturn number A memory usage offset during the benchmark.
function module.docallback(callback, itercount, ...)
    assert(type(callback) == "function", "function 'docallback' expected function.")
    assert(type(itercount) == "number" and itercount > 0, "function 'docallback' expected number or number greater than 0.")

    local startMemory = collectgarbage("count")
    local startTime = clock()
    for i = 1, itercount do
        callback(...)
    end
    local endTime = clock()
    local endMemory = collectgarbage("count")

    if module.ignoreOverhead == true then
        return (endTime - startTime) - (module.callOverhead * itercount) - module.loopOverhead, startMemory, endMemory
    else
        return endTime - startTime, startMemory, endMemory
    end
end

--- The function meant to be nested within <code>benchmark</code> calls.
-- @tparam string description The description of this operation.
-- @tparam function callback The callback to execute for this operation.
-- @tparam number itercount The amount of iterations to perform.
-- @param ... The arguments to pass towards the callback.
function module.member(description, callback, itercount, ...)
    local s
    local handle = module.outputFileHandle
    local time, startMemory, endMemory = module.docallback(callback, itercount, ...)
    local endMemoryOffset = (endMemory - startMemory) / startMemory * 100

    if module.outputMemoryUsage == false then
        s = ("\n\tPerformed '%s'\n\t\tTime: %ss\n\t\tIteration Count: %s\n")
        :format(
            description,
            tostring(time),
            formatNumber(itercount))
    else
        s = ("\n\tPerformed '%s'\n\t\tTime: %ss\n\t\tMemory Offset: %s\n\t\tIteration Count: %s\n")
        :format(
            description,
            tostring(time),
            ("%.2f%% || (start) %.2fkb vs (now) %.2fkb"):format(endMemoryOffset, startMemory, endMemory),
            formatNumber(itercount))
    end

    io.write(s)

    if io.type(handle) == "file" then
        handle:write(s)
    end
end

return module