--- Benchmarks for array vs table performance
---
--- Resolution: Tables are faster than arrays with (x2) and without JIT (x3)
local M = {}

local math_floor = math.floor
local table_new = table.new
local setmetatable = setmetatable
local list_mt = {__serialize='seq'}

---Creates new list
---@param size number
---@return number[]
local function new_list(size)
	size = math_floor(size)
	local t = setmetatable(table_new(size, 0), list_mt)
	return t
end

---Creates new list with zero values
---@param size number
---@private
---@return number[]
local function new_zero_list(size)
	local t = new_list(size)
	-- we start iteration from 0
	-- we abuse how lua stores arrays
	for i = 0, size do
		t[i] = 0
	end
	return t
end

local lists = {
	[1] = new_zero_list(1),
	[5] = new_zero_list(5),
	[10] = new_zero_list(10),
	[20] = new_zero_list(20),
	[50] = new_zero_list(50),
	[100] = new_zero_list(100),
}


-- 30ns/op | 0.7691ns/op
---@param b luabench.B
function M.bench_tbls(b)

	for tb_size, _ in pairs(lists) do
		b:run(""..tb_size, function (sb)
			local key = tb_size
			local self = lists
			for _ = 1, sb.N do
				self[key][0] = self[key][0] + 1
			end
		end)
	end
end

function M.bench_sum_tbls(b)
	b:skip("skip for now")
	for tb_size, _ in pairs(lists) do
		b:run(""..tb_size, function (sb)
			local key = tb_size
			local self = lists
			for _ = 1, sb.N do
				local s = 0
				for i = 1, tb_size do
					s = s + self[key][i]
				end
			end
		end)
	end
end

local ffi = require 'ffi'

local function new_array(size)
	size = math_floor(size)
	local t = ffi.new('double[?]', size)
	return t
end

local function new_zero_array(size)
	return new_array(size)
end

local arrs = {
	[1] = new_zero_array(1),
	[5] = new_zero_array(5),
	[10] = new_zero_array(10),
	[20] = new_zero_array(20),
	[50] = new_zero_array(50),
	[100] = new_zero_array(100),
}

--- 104ns/op | 1.5ns/op
---@param b luabench.B
function M.bench_arrs(b)
	b:skip("skip for now")
	for size, _ in pairs(arrs) do
		b:run(""..size, function (sb)
			local key = size
			local self = arrs
			for _ = 1, sb.N do
				self[key][0] = self[key][0] + 1
			end
		end)
	end
end

function M.bench_sum_arrs(b)
	for size, _ in pairs(arrs) do
		b:run(""..size, function (sb)
			local key = size
			local self = arrs
			for _ = 1, sb.N do
				local s = 0
				for i = 1, size do
					s = s + self[key][i]
				end
			end
		end)
	end
end

return M

--[[
Tarantool version: Tarantool 3.3.0-0-g5fc82b8
Tarantool build: Darwin-arm64-RelWithDebInfo (static)
Tarantool build flags:  -fexceptions -funwind-tables -fasynchronous-unwind-tables -fno-common  -fmacro-prefix-map=/var/folders/8x/1m5v3n6d4mn62g9w_65vvt_r0000gn/T/tarantool_install1980638789=. -std=c11 -Wall -Wextra -Wno-gnu-alignof-expression -Wno-cast-function-type -O2 -g -DNDEBUG -ggdb -O2
CPU: Apple M1 @ 8
JIT: Disabled
Duration: 5s
Global timeout: 60

--- BENCH: arr_vs_tbl_bench::bench_arrs:5
58489223               105.8 ns/op         9454136 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_arrs:100
56514203               108.7 ns/op         9200601 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_arrs:50
56669531               107.2 ns/op         9327758 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_arrs:1
58135028               104.0 ns/op         9618124 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_arrs:10
58186332               104.1 ns/op         9610380 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_arrs:20
54986345               112.9 ns/op         8855729 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:5
203393139               28.65 ns/op       34902561 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:100
195765143               32.05 ns/op       31205992 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:50
196708412               31.85 ns/op       31399384 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:1
220661816               28.85 ns/op       34661519 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:10
221371009               28.78 ns/op       34747648 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:20
178823591               34.93 ns/op       28631065 op/s        0 B/op   +928B

==============================================================================

Tarantool version: Tarantool 3.3.0-0-g5fc82b8
Tarantool build: Darwin-arm64-RelWithDebInfo (static)
Tarantool build flags:  -fexceptions -funwind-tables -fasynchronous-unwind-tables -fno-common  -fmacro-prefix-map=/var/folders/8x/1m5v3n6d4mn62g9w_65vvt_r0000gn/T/tarantool_install1980638789=. -std=c11 -Wall -Wextra -Wno-gnu-alignof-expression -Wno-cast-function-type -O2 -g -DNDEBUG -ggdb -O2
CPU: Apple M1 @ 8
JIT: Enabled
JIT: fold cse dce fwd dse narrow loop abc sink fuse
Duration: 5s
Global timeout: 60

--- BENCH: arr_vs_tbl_bench::bench_arrs:5
1000000000               1.598 ns/op     625938125 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_arrs:100
1000000000               1.543 ns/op     648050341 op/s        0 B/op   +1.78KB

--- BENCH: arr_vs_tbl_bench::bench_arrs:50
1000000000               1.538 ns/op     650200554 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_arrs:1
1000000000               1.573 ns/op     635698407 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_arrs:10
1000000000               1.538 ns/op     649993468 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_arrs:20
1000000000               1.539 ns/op     649850274 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_tbls:5
1000000000               0.7691 ns/op   1300297118 op/s        0 B/op   +928B

--- BENCH: arr_vs_tbl_bench::bench_tbls:100
1000000000               0.7690 ns/op   1300449305 op/s        0 B/op   +1.90KB

--- BENCH: arr_vs_tbl_bench::bench_tbls:50
1000000000               0.7690 ns/op   1300368134 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_tbls:1
1000000000               0.7691 ns/op   1300185536 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_tbls:10
1000000000               0.7702 ns/op   1298288207 op/s        0 B/op   +880B

--- BENCH: arr_vs_tbl_bench::bench_tbls:20
1000000000               0.7694 ns/op   1299778258 op/s        0 B/op   +880B
]]
