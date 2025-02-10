local type = type
local math_floor = math.floor
local table_new = require('table.new')

---Appends all k-vs from t2 to t1, if not exists in t1
---@param t1 table?
---@param t2 table?
local function merge(t1, t2)
	if type(t1) ~= 'table' or type(t2) ~= 'table' then return end

	for k in pairs(t2) do
		if t1[k] == nil then
			t1[k] = t2[k]
		end
	end
end

local map_mt  = { __serialize = 'map' }
local list_mt = { __serialize = 'seq' }
local weak_mt = { __mode = 'v' }


---Creates new list with null values
---@param size number
---@param init number? initial value
---@private
---@return number[]
local function new_list(size, init)
	size = math_floor(size)
	local t = setmetatable(table_new(size, 0), list_mt)
	if not init then return t end
	for i = 0, size do
		t[i] = init
	end
	return t
end

---Creates new list with zero values
---@param size number
---@private
---@return number[]
local function new_zero_list(size)
	return new_list(size, 0)
end

local function _list_serialize(list)
	local r = {}
	for i = 1, #list do
		r[i] = tostring(list[i])
	end
	return r
end

local pretty_list_mt = {__serialize = _list_serialize}

local function make_list_pretty(rv)
	return setmetatable(rv, pretty_list_mt)
end


return {
	merge = merge,
	map_mt = map_mt,
	list_mt = list_mt,
	weak_mt = weak_mt,

	new_list = new_list,
	new_zero_list = new_zero_list,
	make_list_pretty = make_list_pretty,
}