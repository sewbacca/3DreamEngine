--load the 3D lib
dream = require("3DreamEngine")
love.window.setTitle("PBR Tavern")
love.mouse.setRelativeMode(true)

--settings
local projectDir = "examples/Tavern/"
dream.nameDecoder = false
dream.sky_enabled = false
dream.sun_ambient = {0.1, 0.1, 0.1}
dream.lighting_engine = "PBR"

dream:loadMaterialLibrary(projectDir .. "materials")

dream:init()

local scene = dream:loadObject(projectDir .. "scene", {shaderType = "PBR"})

local player = {
	x = 4,
	y = 1.5,
	z = 4,
	ax = 0,
	ay = 0,
	az = 0,
}

--because it is easier to work with two rotations
dream.cam.rx = 0
dream.cam.ry = math.pi/4

local texture_candle = love.graphics.newImage(projectDir .. "candle.png")
local factor = texture_candle:getHeight() / texture_candle:getWidth()
local quads = { }
for y = 1, 5 do
	for x = 1, 5 do
		quads[#quads+1] = love.graphics.newQuad(x-1, (y-1)*factor, 1, factor, 5, 5*factor)
	end
end
local particles = { }
local lastParticleID = 0

local lights = { }
for d,s in ipairs(scene.positions) do
	if s.name == "LIGHT" then
		lights[d] = dream:newLight(s.x, s.y + 0.1, s.z, 1.0, 0.75, 0.2)
		lights[d].shadow = dream:newShadow("point", true)
		lights[d].shadow.size = 0.1
	elseif s.name == "FIRE" then
		lights[d] = dream:newLight(s.x, s.y + 0.1, s.z, 1.0, 0.75, 0.2)
		lights[d].shadow = dream:newShadow("point", true)
		lights[d].shadow.size = 0.1
	end
end

local hideTooltips = false

function love.draw()
	--update camera
	dream.cam:reset()
	dream.cam:translate(-player.x, -player.y, -player.z)
	dream.cam:rotateY(dream.cam.ry)
	dream.cam:rotateX(dream.cam.rx)
	
	dream:prepare()
	
	--update lights
	dream:resetLight(true)
	for d,s in ipairs(scene.positions) do
		if s.name == "LIGHT" then
			local power = (0.5 + 0.3 * love.math.noise(love.timer.getTime() / math.sqrt(s.size) * 0.25, d)) * s.size * 200.0
			lights[d]:setBrightness(power)
			dream:addLight(lights[d])
			dream:drawParticle(texture_candle, quads[math.ceil(d + love.timer.getTime() * 24) % 25 + 1], s.x, s.y + 0.02, s.z, power * 0.003, 0.0, 5.0)
		elseif s.name == "CANDLE" then
			local power = (0.5 + 0.3 * love.math.noise(love.timer.getTime() / math.sqrt(s.size) * 0.25, d)) * s.size * 200.0
			dream:drawParticle(texture_candle, quads[math.ceil(d + love.timer.getTime() * 24) % 25 + 1], s.x, s.y + 0.02, s.z, power * 0.003, 0.0, 5.0)
		elseif s.name == "FIRE" then
			local power = (0.5 + 0.3 * love.math.noise(love.timer.getTime() / math.sqrt(s.size) * 0.25, d)) * s.size * 200.0
			lights[d]:setBrightness(power)
			dream:addLight(lights[d])
		end
	end
	
	dream:draw(scene)

	dream:present()
	
	if not hideTooltips then
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("R to toggle rain (" .. tostring(dream.rain_isRaining) .. ")\nU to toggle auto exposure (" .. tostring(dream.autoExposure_enabled) .. ")\nG to toggle deferred shading (note the shadows) (may be not supported by your GPU) (" .. tostring(dream.deferred_lighting) .. ")\nH to toggle SSR (required deferred) (" .. tostring(dream.SSR_enabled) .. ")", 10, 10)
	end
end

function love.mousemoved(_, _, x, y)
	local speedH = 0.005
	local speedV = 0.005
	dream.cam.ry = dream.cam.ry - x * speedH
	dream.cam.rx = math.max(-math.pi/2, math.min(math.pi/2, dream.cam.rx + y * speedV))
end

function love.update(dt)
	local d = love.keyboard.isDown
	local speed = 7.5*dt
	
	--particles
	for d,s in pairs(particles) do
		s[2] = s[2] + dt*0.25
		s[4] = s[4] - dt
		if s[4] < 0 then
			particles[d] = nil
		end
	end
	
	--collision
	player.x = player.x + player.ax * dt
	player.y = player.y + player.ay * dt
	player.z = player.z + player.az * dt
	
	if d("w") then
		player.ax = player.ax + math.cos(-dream.cam.ry-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry-math.pi/2) * speed
	end
	if d("s") then
		player.ax = player.ax + math.cos(-dream.cam.ry+math.pi-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry+math.pi-math.pi/2) * speed
	end
	if d("a") then
		player.ax = player.ax + math.cos(-dream.cam.ry-math.pi/2-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry-math.pi/2-math.pi/2) * speed
	end
	if d("d") then
		player.ax = player.ax + math.cos(-dream.cam.ry+math.pi/2-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry+math.pi/2-math.pi/2) * speed
	end
	if d("space") then
		player.ay = player.ay + speed
	end
	if d("lshift") then
		player.ay = player.ay - speed
	end
	
	--air resistance
	player.ax = player.ax * (1 - dt*3)
	player.ay = player.ay * (1 - dt*3)
	player.az = player.az * (1 - dt*3)
	
	--mount cam
	dream.cam.x = player.x
	dream.cam.y = player.y+0.3
	dream.cam.z = player.z
	
	dream:update()
end

function love.keypressed(key)
	--screenshots!
	if key == "f2" then
		if love.keyboard.isDown("lctrl") then
			love.system.openURL(love.filesystem.getSaveDirectory() .. "/screenshots")
		else
			love.filesystem.createDirectory("screenshots")
			if not screenShotThread then
				screenShotThread = love.thread.newThread([[
					require("love.image")
					channel = love.thread.getChannel("screenshots")
					while true do
						local screenshot = channel:demand()
						screenshot:encode("png", "screenshots/screen_" .. tostring(os.time()) .. ".png")
					end
				]]):start()
			end
			love.graphics.captureScreenshot(love.thread.getChannel("screenshots"))
		end
	end

	--fullscreen
	if key == "f11" then
		love.window.setFullscreen(not love.window.getFullscreen())
		dream:init()
	end
	
	if key == "f1" then
		hideTooltips = not hideTooltips
	end
	
	if key == "r" then
		dream.rain_isRaining = not dream.rain_isRaining
		if not dream.rain_enabled then
			dream.rain_enabled = true
			dream:init()
		end
	end
	
	if key == "u" then
		dream.autoExposure_enabled = not dream.autoExposure_enabled
		dream:init()
	end
	
	if key == "g" then
		dream.deferred_lighting = not dream.deferred_lighting
		dream:init()
	end
	
	if key == "h" then
		dream.SSR_enabled = not dream.SSR_enabled
		dream:init()
	end
end

function love.resize()
	dream:init()
end