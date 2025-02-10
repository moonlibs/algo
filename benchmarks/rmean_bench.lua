local M = {}

local rmean = require 'algo.rmean'

local random_value = math.random(1e9)

local rm = rmean.default:collector()
function M.bench_rmean_observe(b)
	local rand = random_value
	for i = 1, b.N do
		rm:observe(rand+i)
	end
end

function M.bench_rmean_per_second(b)
	for _ = 1, b.N do
		local _ = rm:per_second()
	end
end

function M.bench_rmean_collect(b)
	for _ = 1, b.N do
		local _ = rm:collect()
	end
end

function M.bench_rmean_sum(b)
	for _ = 1, b.N do
		local _ = rm:sum()
	end
end

function M.bench_rmean_min(b)
	for _ = 1, b.N do
		local _ = rm:min()
	end
end

function M.bench_rmean_max(b)
	for _ = 1, b.N do
		local _ = rm:max()
	end
end

function M.bench_rmean_new_collector(b)
	b:skip()
	local cols = table.new(1000, 0)
	for i = 1, b.N do
		local col = rmean.default:collector()
		cols[i%1000+1] = col
		col:observe(i)
	end
end

return M
