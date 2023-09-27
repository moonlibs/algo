--
-- A subset of rlist methods from the main repository. Rlist is a
-- doubly linked list.
--
--Copyright: Tarantool owners
---@class algo.rlist
---@field first? algo.rlist.item first item in the list
---@field last? algo.rlist.item last item in the list
---@field count number
local rlist_index = {}

---
---@param x table
---@return table
local function __item_serialize(x)
    local r = {}
    for k in pairs(x) do
        if k ~= 'next' and k ~= 'prev' then
            r[k]=x[k]
        end
    end
    return r
end

---@class algo.rlist.item:table
---@field prev algo.rlist.item
---@field next algo.rlist.item
local rlist_item_mt = {__serialize = __item_serialize}

---@param node table
local function to_rlist_item(node)
    assert(type(node)=='table')
    local mt = getmetatable(node)
    if not mt then
        setmetatable(node, rlist_item_mt)
    elseif not mt.__serialize then
        mt.__serialize = __item_serialize
    end
end

---Adds object into rlist
---@param rlist algo.rlist
---@param object algo.rlist.item
function rlist_index.add_tail(rlist, object)
    local last = rlist.last
    if last then
        last.next = object
        object.prev = last
    else
        rlist.first = object
    end
    rlist.last = object
    to_rlist_item(object)
    rlist.count = rlist.count + 1
end

rlist_index.push = rlist_index.add_tail

---Adds object into rlist
---@param rlist algo.rlist
---@param object algo.rlist.item
function rlist_index.add_head(rlist, object)
    local first = rlist.first
    if first then
        first.prev = object
        object.next = first
    else
        rlist.last = object
    end
    rlist.first = object
    to_rlist_item(object)
    rlist.count = rlist.count + 1
end

rlist_index.unshift = rlist_index.add_head

---Adds object after anchor in rlist
---@param rlist algo.rlist
---@param anchor algo.rlist.item
---@param object algo.rlist.item
function rlist_index.add_after(rlist, anchor, object)
    assert(anchor, "anchor not given")
    assert(object, "object not given")
    assert(anchor ~= object, "object can't be same as anchor")

    if anchor.next then
        anchor.next.prev = object
        object.next = anchor.next
    else
        rlist.last = object
    end
    object.prev = anchor
    anchor.next = object
    to_rlist_item(object)
    rlist.count = rlist.count + 1
end

---Adds object before anchor in rlist
---@param rlist algo.rlist
---@param anchor algo.rlist.item
---@param object algo.rlist.item
function rlist_index.add_before(rlist, anchor, object)
    assert(anchor, "anchor not given")
    assert(object, "object not given")
    assert(anchor ~= object, "object can't be equal to anchor")

    if anchor.prev then
        object.next, object.prev, anchor.prev.next, anchor.prev = anchor, anchor.prev, object, object
    else
        local first = rlist.first
        if first then
            first.prev = object
            object.next = first
        else
            rlist.last = object
        end
        rlist.first = object
    end
    to_rlist_item(object)
    rlist.count = rlist.count + 1
end

---Removes object from rlist
---@param rlist algo.rlist
---@param object algo.rlist.item
---@return boolean belongs_to_list
function rlist_index.remove(rlist, object)
    local prev = object.prev
    local next = object.next
    local belongs_to_list = false
    if prev then
        belongs_to_list = true
        prev.next = next
    end
    if next then
        belongs_to_list = true
        next.prev = prev
    end
    object.prev = nil
    object.next = nil
    if rlist.last == object then
        belongs_to_list = true
        rlist.last = prev
    end
    if rlist.first == object then
        belongs_to_list = true
        rlist.first = next
    end
    if belongs_to_list then
        rlist.count = rlist.count - 1
    end
    return belongs_to_list
end

---Removes first item from the list
---@param rlist algo.rlist
---@return algo.rlist.item? item
function rlist_index.remove_first(rlist)
    local node = rlist.first
    if node and rlist:remove(node) then
        return node
    end
end

rlist_index.shift = rlist_index.remove_first

---Removes last item from the list
---@param rlist algo.rlist
---@return algo.rlist.item? item
function rlist_index.remove_last(rlist)
    local node = rlist.last
    if node and rlist:remove(node) then
        return node
    end
end

rlist_index.pop = rlist_index.remove_last

function rlist_index:next(last)
    if last then
        return last.next, last.next
    else
        return self.first, self.first
    end
end

function rlist_index:prev(last)
    if last then
        return last.prev, last.prev
    else
        return self.last, self.last
    end
end

---returns forward iterator over double linked list
---@param rlist algo.rlist
function rlist_index.pairs(rlist)
    return rlist.next, rlist, nil
end

---returns reverse iterator over double linked list
---@param rlist algo.rlist
function rlist_index.rpairs(rlist)
    return rlist.prev, rlist, nil
end

local rlist_mt = {
    __index = rlist_index,
	__serialize = function(self)
		return ("rlist<%s>"):format(self.count)
	end,
}

---Creates new rlist
---@return algo.rlist
local function rlist_new()
    return setmetatable({count = 0}, rlist_mt)
end

return {
    new = rlist_new,
}
