local job = { }
local lib = _3DreamEngine

job.cost = 1

function job:init()
	if lib.autoExposure_enabled then
		lib.canvas_exposure = love.graphics.newCanvas(1, 1, {format = "r16f", readable = true, msaa = 0, mipmaps = "none"})
		love.graphics.setCanvas(lib.canvas_exposure)
		love.graphics.clear(1, 1, 1)
		love.graphics.setCanvas()
	end
end

function job:queue(times)
	if lib.autoExposure_enabled then
		lib:addOperation("autoExposure", 0.25, false, lib.autoExposure_frameSkip)
	end
end

function job:execute(times, delta)
	love.graphics.push("all")
	love.graphics.reset()
	
	--vignette and downscale
	local c = lib.canvas_exposure
	local shader = lib:getShader("autoExposure")
	love.graphics.setCanvas(c)
	love.graphics.setShader(shader)
	shader:send("adaptionSpeed", lib.autoExposure_adaptionSpeed * delta)
	shader:send("targetBrightness", lib.autoExposure_targetBrightness)
	love.graphics.draw(lib.canvases.color, 0, 0, 0, 1 / lib.canvases.width, 1 / lib.canvases.height)
	
	love.graphics.pop()
end

return job