---@class algo.slist
---@field cmp algo.slist.comparator
---@field nexts? algo.slist.item[]
local slist = {}

local max_level = 32
local p = 0.25

local random = math.random

---@return integer
local function _random_level()
	local lvl = 0
	repeat
		lvl = lvl + 1
	until random() <= p or lvl == max_level
	return lvl
end

---@param node algo.slist.item
---@return table
local function node_serialize(node)
	local r = {}
	for k, v in pairs(node) do
		if k ~= 'prev' and k ~= 'nexts' then
			r[k] = v
		end
	end
	return r
end

---@class algo.slist.item:table
---@field prev? algo.slist.item
---@field nexts? algo.slist.item[]

---Performs lessThan search
---@param start any
---@param key algo.slist.item
---@param preds? algo.slist.item[]
---@return algo.slist.item candidate
function slist:_get_path(start, key, preds)
	local node = start
	local cmp = self.cmp
	for i = #start.nexts, 1, -1 do
		while node.nexts[i] and cmp(node.nexts[i], key) do
			node = node.nexts[i]
		end
		if preds then
			preds[i] = node
		end
	end
	return node.nexts[1]
end

---Inserts new node into the list
---@param node algo.slist.item
function slist:add(node)
	local preds = table.new(max_level, 0)
	local _ = self:_get_path(self, node, preds)

	local nL = _random_level()
	local cL = #self.nexts

	if nL > cL then
		-- level increased
		for i = cL + 1, nL do
			preds[i] = self
		end
	end

	node.nexts = table.new(nL, 0)
	if preds[1] then
		node.prev = preds[1]
	end

	for i = 1, nL do
		node.nexts[i] = preds[i].nexts[i]
		preds[i].nexts[i] = node
	end

	self.count = self.count + 1
	if node.nexts[1] then
		node.nexts[1].prev = node
	end

	local node_mt = getmetatable(node)
	if node_mt then
		node_mt.__serialize = node_serialize
	else
		setmetatable(node, { __serialize = node_serialize })
	end
end

---@return algo.slist.item
function slist:min()
	return self.nexts[1]
end

---removes node from the list
---@param node algo.slist.item
function slist:remove(node)
	local preds = table.new(max_level, 0)
	local candidate = self:_get_path(self, node, preds)

	if candidate ~= node then
		return
	end

	local nxt = node.nexts[1]
	if nxt then
		nxt.prev = node.prev
	end

	for i = 1, #self.nexts do
		if not preds[i] or preds[i].nexts[i] ~= node then
			break
		end
		preds[i].nexts[i] = node.nexts[i]
	end

	table.clear(node.nexts)
	node.prev = nil

	self.count = self.count - 1
end

---Searches given node in the list
---@param key algo.slist.item
function slist:get(key)
	return self:_get_path(self, key)
end


local slist_mt = {
	__index = slist,
	__serialize = function(self)
		return ("slist<%s>"):format(self.count)
	end,
}

---@alias algo.slist.comparator fun(a: algo.slist.item, b: algo.slist.item): boolean

---Creates new slist
---@param comparator algo.slist.comparator
---@return algo.slist
local function slist_new(comparator)
	assert(comparator, 'comparator is required')
	return setmetatable({ count = 0, cmp = comparator, nexts = {} }, slist_mt)
end

return {
	new = slist_new,
}
