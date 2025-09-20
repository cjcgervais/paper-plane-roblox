local HttpService = game:GetService("HttpService")
local PlaneMetrics = {}
PlaneMetrics._buffer = {}
function PlaneMetrics.push(sample)
	table.insert(PlaneMetrics._buffer, sample)
	if #PlaneMetrics._buffer > 300 then table.remove(PlaneMetrics._buffer,1) end
end
function PlaneMetrics.flushToString()
	local out = {}
	for _, s in ipairs(PlaneMetrics._buffer) do
		out[#out+1] = HttpService:JSONEncode(s)
	end
	return table.concat(out, "\n")
end
return PlaneMetrics
