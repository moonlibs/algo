local t = require 'luatest' --[[@as luatest]]
local fiber = require 'fiber'
local g = t.group('rmean')

local rmean = require 'algo.rmean'

function g.test_rmean_module()
	t.assert_type(rmean, 'table', 'rmean module must be a table')
	t.assert_type(rmean.new, 'function', 'rmean must export function new')
	t.assert_is(require 'algo'.rmean, require 'algo.rmean', "rmean module can be required from algo and algo.rmean")
end

function g.test_rmean_ints()
	local r = rmean.collector()
	t.assert_type(r, 'table', 'rmean.collector always a table')

	-- align to evloop
	fiber.sleep(r._resolution)

	local sum = 0
	for i = 1, 100 do
		r:observe(i)
		sum = sum + i
	end

	t.assert_is(r.count, 100, 'rmean observed 100 values')
	t.assert_is(r.sum_value[0], sum, 'rmean:sum is correct')
	t.assert_is(r.total, sum, 'rmean.total is correct')

	t.assert_is(r.min_value[0], 1, 'rmean:min is 1')
	t.assert_is(r.max_value[0], 100, 'rmean:max is 100')

	local t0 = fiber.time()
	fiber.sleep(r._resolution)
	local t1 = fiber.time()-t0

	t.assert_is(r.total, sum, 'rmean.total is correct')
	t.assert_is(r:min(), 1, 'rmean:min is correct')
	t.assert_is(r:max(), 100, 'rmean:max is correct')
	t.assert_almost_equals(r:sum(), sum, sum*0.01, 'rmean:sum() ≈ ± 1%')
	t.assert_almost_equals(r:per_second(), sum / t1 / r.window, sum / r.window * 0.01, 'rmean:per_second ≈ ±1%')
end

function g.test_rmean_destroyer()
	local r = rmean.collector()

	for _ = 1, 100 do
		r:observe(1)
	end

	t.assert_is(rmean:get('anon'), r, 'rmean:get')

	local clt = r:collect()

	t.assert_covers(clt, {
		{ metric_name = 'rmean_per_second', value = 0, label_pairs = { window = 5, name = 'anon' }, timestamp = fiber.time64() },
		{ metric_name = 'rmean_sum', value = 0, label_pairs = { window = 5, name = 'anon' }, timestamp = fiber.time64() },
		{ metric_name = 'rmean_min', label_pairs = { window = 5, name = 'anon' }, timestamp = fiber.time64() },
		{ metric_name = 'rmean_max', label_pairs = { window = 5, name = 'anon' }, timestamp = fiber.time64() },
		{ metric_name = 'rmean_total', value = 100, label_pairs = { window = 5, name = 'anon' }, timestamp = fiber.time64() },
		{ metric_name = 'rmean_count', value = 100, label_pairs = { window = 5, name = 'anon' }, timestamp = fiber.time64() },
	}, 'collector:collect')

	r:reset()

	r = nil
	collectgarbage('collect')
	collectgarbage('collect')

	t.assert_is(rmean:get('anon'), nil, 'rmean:get - nil')

	t.assert_type(rmean.default:collect(), 'table', 'rmean:collect is callable')
end
