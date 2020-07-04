--load the matrix and the 3D lib
dream = require("3DreamEngine")
love.window.setTitle("Lamborghini Example")
love.graphics.setBackgroundColor(0.8, 0.8, 0.8)

--settings
local projectDir = "examples/Lamborghini/"

dream.secondPass = true
dream.deferred_lighting = false
dream.lighting_engine = "PBR"

dream.shadow_distance = 4
dream.shadow_factor = 2
dream.shadow_resolution = 4096

dream.sky_hdri = love.graphics.newImage(projectDir .. "garage.hdr")

dream.cam.fov = 70

dream:init()

car = dream:loadObject(projectDir .. "Lamborghini Aventador", {splitMaterials = true})
socket = dream:loadObject(projectDir .. "socket")

function love.draw()
	dream:update()
	
	dream.sun = vec3(-1.0, 1.0, 1.0)
	dream.sun_color = vec3(1, 1, 1)
	
	dream:resetLight()
	
	dream:prepare()
	
	--draw the car
	love.graphics.setColor(1, 1, 1)
	car:reset()
	car:scale(0.1)
	car:rotateY(love.mouse.isDown(1) and (-2.25-(love.mouse.getX()/love.graphics.getWidth()-0.5)*4.0) or love.timer.getTime()*0.5)
	car:translate(0, -1.1225, -3.5)
	dream:draw(car)
	
	dream:draw(socket, 0, -1, -4.5, 4, 0.25, 4)
	
	dream:present(true)
	
	--stats
	love.graphics.setColor(0.1, 0.1, 0.1)
	love.graphics.print("Stats" ..
		"\ndifferent shaders: " .. dream.stats.shadersInUse ..
		"\ndifferent materials: " .. dream.stats.materialDraws ..
		"\ndraws: " .. dream.stats.draws, 15, 500)
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
end

function love.resize()
	dream:init()
end