local luabenchmark = require "src.luabenchmark"
local ONE_MILLION = 1000000

local benchmark = luabenchmark.benchmark
local member = luabenchmark.member

-- Remove inherent overheads (i.e, call construction & third-party loop instructions) from the results.
luabenchmark.ignoreOverhead = false
-- Output memory usage offsets.
luabenchmark.outputMemoryUsage = true
-- Setting the file that we'll write the results to.
luabenchmark.outputFileHandle = io.open("LuaBenchmarkResults.txt", "w+")

benchmark("String Operations:", function ()
    -- ====================================== --
    member("Length Calculation", function ()
        local _ = ("hello world"):len()
    end, ONE_MILLION)

    member("Substring Generation", function ()
        local _ = ("hello world"):sub(1, 7)
    end, ONE_MILLION)
    -- ====================================== --
end)

benchmark("Integral Operations:", function ()
    -- ====================================== --
    member("Multiplication", function ()
        local _ = 1231083 * 1324081293 ^ 2142390 / 23940 * 99999
    end, ONE_MILLION * 10)
    -- ====================================== --
end)

benchmark("Table Operations:", function ()
    member("1M Dead Table Test", function ()
        for i = 1, ONE_MILLION do
            local _ = {}
        end
    end, 10)
end)

-- Closing the benchmark data file.
luabenchmark.outputFileHandle:close()
