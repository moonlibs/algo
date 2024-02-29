local slist = require 'algo.skiplist'
local rlist = require 'algo.rlist'

local M = {}

local rls = rlist.new()
local sl = slist.new(function(a, b)
	return a[1] < b[1]
end)

for _ = 1, 5000 do
	local k = math.random(100)
	rls:add_tail({ [1] = k })
	sl:add({ [1] = k })
end

function M.bench_rlist(b)
	for _ = 1, b.N do
		local x = math.random(100)
		for _, item in rls:pairs() do
			if item[1] == x then
				break
			end
		end
	end
end

function M.bench_slist(b)
	local cont = {  }
	for _ = 1, b.N do
		local x = math.random(100)
		cont[1] = x
		local n = sl:get(cont)
	end
end

return M
