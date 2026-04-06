local IDsCache = {}

--- services \\\

local HttpService = game:GetService("HttpService")

---///----------

--- functions \\\

function IDsCache.clean(id)

	IDsCache[id] = nil

end

function IDsCache.generate(value)

	local id

	repeat
		id = HttpService:GenerateGUID(false)
	until not IDsCache[id]

	IDsCache[id] = value

	return id

end

---///-----------

return IDsCache
