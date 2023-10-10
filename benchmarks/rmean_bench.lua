local M = {}

local rmean = require 'algo.rmean'

local rm = rmean.default:collector()
function M.bench_rmean_observe(b)
	for i = 1, b.N do
		rm:observe(i)
	end
end

function M.bench_rmean_mean(b)
	for _ = 1, b.N do
		local x = rm:per_second()
	end
end

function M.bench_rmean_sum(b)
	for _ = 1, b.N do
		local x = rm:sum()
	end
end

function M.bench_rmean_min(b)
	for _ = 1, b.N do
		local x = rm:min()
	end
end

function M.bench_rmean_max(b)
	for _ = 1, b.N do
		local x = rm:max()
	end
end

function M.bench_rmean_thousands(b)
	local cols = table.new(1000, 0)
	for i = 1, b.N do
		local col = rmean.default:collector()
		cols[i%1000+1] = col
		col:observe(i)
	end
end

return M
