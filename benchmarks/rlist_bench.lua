local M = {}

local rlist = require 'algo.rlist'

local function insert_size(size)
	local rl = rlist.new()
	for i = 1, size do
		local item = { num = i }
		rl:add_tail(item)
	end
	return rl
end

local _sizes = {8, 16, 32, 64, 128, 512, 1024, 2048, 4096}
local sizes = {}

for _, size in pairs(_sizes) do
	sizes[size] = function()
		return insert_size(size)
	end
end

function M.bench_rlist_creation(b)
	for _ = 1, b.N do
		local _ = rlist.new()
	end
end

function M.bench_rlist_insertion_8(b)
	for _ = 1, b.N do
		insert_size(8)
	end
end

function M.bench_rlist_insertion_128(b)
	for _ = 1, b.N do
		insert_size(128)
	end
end

local rl8192 = insert_size(8192)
function M.bench_rlist_traverse_8192(b)
	for _ = 1, b.N do
		local sum = 0
		for _, item in rl8192:items() do
			sum = sum + item.num
		end
	end
end

local rl4096 = insert_size(4096)
function M.bench_rlist_traverse_4096(b)
	for _ = 1, b.N do
		local sum = 0
		for _, item in rl4096:items() do
			sum = sum + item.num
		end
	end
end

-- function M.bench_rlist_stack_8192(b)

-- end

-- error("xxxx")
return M
