local M = {}

local rlist = require 'algo.rlist'

local function insert_size(size)
	local rl = rlist.new()
	for i = 1, size do
		-- local item = { num = i }
		local item = table.new(0, 4)
		item.num = i
		-- local item = { num = i }
		rl:add_tail(item)
	end
	return rl
end

local function array(size)
	local arr = table.new(size, 0)
	for i = 1, size do
		local item = { num = i }
		arr[i] = item
	end
	return arr
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

local arl1024 = array(1024)
function M.bench_array_traverse_1024(b)
	for _ = 1, b.N do
		local sum = 0
		for _, item in ipairs(arl1024) do
			sum = sum + item.num
		end
	end
end

local arl4096 = array(4096)
function M.bench_array_traverse_4096(b)
	for _ = 1, b.N do
		local sum = 0
		for _, item in ipairs(arl4096) do
			sum = sum + item.num
		end
	end
end

function M.bench_rlist_1prcnt_create(b)
	local rl = rlist.new()
	local rm
	for _ = 1, b.N do
		local coin = math.random()
		if coin < 0.01 then
			rl:remove_first()
		elseif coin < 0.02 then
			if rm then
				rl:remove(rm)
			end
		elseif coin < 0.5 then
			rl:push({ num = rl.count })
		end
		local s = 0
		local pos = math.floor(rl.count *coin)
		for x, it in rl:pairs() do
			s = s + it.num
			if x == pos then
				rm = it
			end
		end
	end
end

function M.bench_arr_1prcnt_create(b)
	local rl = array(1)
	local rm
	for _ = 1, b.N do
		local coin = math.random()
		if coin < 0.01 then
			table.remove(rl, 1)
		elseif coin < 0.02 then
			if rm then
				table.remove(rl, rm)
			end
		elseif coin < 0.5 then
			table.insert(rl, { num = #rl })
		end
		local s = 0
		local pos = math.floor(#rl*coin)
		for x, it in ipairs(rl) do
			s = s + it.num
			if x == pos then
				rm = x
			end
		end
	end
end

-- function M.bench_rlist_stack_8192(b)

-- end

-- error("xxxx")
return M
