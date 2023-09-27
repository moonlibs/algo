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
		for _, item in rl8192:pairs() do
			sum = sum + item.num
		end
	end
end

local rl4096 = insert_size(4096)
function M.bench_rlist_traverse_4096(b)
	for _ = 1, b.N do
		local sum = 0
		for _, item in rl4096:pairs() do
			sum = sum + item.num
		end
	end
end

local rl1024 = insert_size(1024)
function M.bench_rlist_traverse_1024(b)
	for _ = 1, b.N do
		local sum = 0
		for _, item in rl1024:pairs() do
			sum = sum + item.num
		end
	end
end

-- function M.bench_rlist_stack_8192(b)

-- end

-- error("xxxx")
return M
