--[[
#3DreamEngine - 3D library by Luke100000
#Copyright 2020 Luke100000
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local lib = { }

if love.filesystem.read("debugEnabled") == "true" then
	_DEBUGMODE = true
end

--load libraries
mat2 = require((...) .. "/libs/luaMatrices/mat2")
mat3 = require((...) .. "/libs/luaMatrices/mat3")
mat4 = require((...) .. "/libs/luaMatrices/mat4")

vec2 = require((...) .. "/libs/luaVectors/vec2")
vec3 = require((...) .. "/libs/luaVectors/vec3")
vec4 = require((...) .. "/libs/luaVectors/vec4")

quat = require((...) .. "/libs/quat")
cimg = require((...) .. "/libs/cimg")
utils = require((...) .. "/libs/utils")
require((...) .. "/libs/saveTable")
lib.ffi = require("ffi")

--load sub modules
_3DreamEngine = lib
lib.root = (...)
require((...) .. "/functions")
require((...) .. "/settings")
require((...) .. "/classes")
require((...) .. "/shader")
require((...) .. "/loader")
require((...) .. "/materials")
require((...) .. "/resources")
require((...) .. "/render")
require((...) .. "/renderLight")
require((...) .. "/renderSky")
require((...) .. "/jobs")
require((...) .. "/particlesystem")
require((...) .. "/particles")
require((...) .. "/3doExport")
require((...) .. "/animations")

--loader
lib.loader = { }
for d,s in pairs(love.filesystem.getDirectoryItems((...) .. "/loader")) do
	lib.loader[s:sub(1, #s-4)] = require((...) .. "/loader/" .. s:sub(1, #s-4))
end

--get color of sun based on sunrise sky texture
lib.sunlight = require(lib.root .. "/res/sunlight")
lib.skylight = require(lib.root .. "/res/skylight")

--supported canvas formats
lib.canvasFormats = love.graphics and love.graphics.getCanvasFormats() or { }

--default material library
lib.materialLibrary = { }

--default settings
lib:setAO(16, 0.75)
lib:setBloom(1.0, 1.5, 0.5)
lib:setFog()
lib:setFogHeight(1, -1)
lib:setDaytime(0.3)
lib:setGamma(false)
lib:setExposure(1.0)

--shadows
lib:setShadowResolution(1024, 256)
lib:setShadowSmoothing(false)
lib:setShadowCascade(8, 4)

--loader settings
lib:setResourceLoader(true, true)
lib:setSmoothLoading(1 / 1000)
lib:setSmoothLoadingBufferSize(128)
lib:setMipmaps(true)

--TODO, replace sun and moon with particle-like billboarding
lib.sun_offset = 0.25
lib.sun_shadow = true

--TODO
lib.deferredShaderType = "Phong"
lib.max_lights = 16
lib.nameDecoder = "blender"
lib.frustumCheck = true
lib.LoDDistance = 100

--canvas set settings
lib.default_settings = lib:newSetSettings()
lib.default_settings:setPostEffects(true)
lib.default_settings:setRefractions(true)

lib.reflections_settings = lib:newSetSettings()
lib.reflections_settings:setDirect(true)

lib.mirror_settings = lib:newSetSettings()
lib.mirror_settings:setDirect(true)

--TODO
lib.reflections_levels = 5

--TODO
lib.autoExposure_enabled = false
lib.autoExposure_resolution = 128
lib.autoExposure_targetBrightness = 0.25
lib.autoExposure_interval = 1 / 15
lib.autoExposure_adaptionSpeed = 0.4

--TODO, move sky_refreshRate to FPS, remove sky_as_reflection and add setSky() which accepts a cubemap, an hdri and a boolean wether to use the sky
lib.sky_as_reflection = true
lib.sky_refreshRate = 1/15
lib.sky_refreshRateTexture = 0
lib.sky_cube = false
lib.sky_hdri = false
lib.sky_hdri_exposure = 1.0
lib.sky_resolution = 512
lib.sky_format = "rgba16f"

lib.stars_enabled = true
lib.sunMoon_enabled = true

--TODO, resolution missing
lib.clouds_enabled = true
lib.clouds_resolution = 1024
lib.clouds_scale = 2.0
lib.clouds_wind = vec2(0.01, 0.0)
lib.clouds_pos = vec2(0.0, 0.0)

--TODO move to settings
lib:setWeather(0.5)

--default camera
lib.cam = lib:newCam()

--default scene
lib.scene = lib:newScene()

--delton, disabled when not in debug mode
lib.delton = require((...) .. "/libs/delton"):new(512)
if not _DEBUGMODE then
	lib.delton.start = function() end
	lib.delton.stop = lib.delton.start
	lib.delton.step = lib.delton.start
end

--default objects
lib.object_sky = lib:loadObject(lib.root .. "/objects/sky", "Phong", {splitMaterials = false})
lib.object_cube = lib:loadObject(lib.root .. "/objects/cube", "simple", {splitMaterials = false})
lib.object_plane = lib:loadObject(lib.root .. "/objects/plane", "Phong", {splitMaterials = false})

--default textures
local pix = love.image.newImageData(2, 2)
lib.textures = {
	default = love.graphics.newImage(lib.root .. "/res/default.png"),
	default_normal = love.graphics.newImage(lib.root .. "/res/default_normal.png"),
	
	brdfLUT = lib.root .. "/res/brdfLut.png",
	
	sky_fallback = love.graphics.newCubeImage({pix, pix, pix, pix, pix, pix}),
	
	sky = lib.root .. "/res/sky.png",
	stars_hdri = lib.root .. "/res/stars_hdri.png",
	moon = lib.root .. "/res/moon.png",
	moon_normal = lib.root .. "/res/moon_normal.png",
	sun = lib.root .. "/res/sun.png",
	
	clouds = love.graphics.newImage(lib.root .. "/res/clouds.png"),
	clouds_base = love.graphics.newImage(lib.root .. "/res/clouds_base.png"),
}

--TODO use this for moon,clouds, ...
lib.textures.get = function(self, path)
	if type(self[path]) == "string" then
		self[path] = love.graphics.newImage(self[path])
	end
	return self[path]
end

--a canvas set is used to render a scene to
function lib.newCanvasSet(self, settings, w, h)
	local set = { }
	w = w or settings.resolution
	h = h or settings.resolution
	
	--settings
	set.width = w
	set.height = h
	set.msaa = settings.msaa
	set.direct = settings.direct
	set.deferred = settings.deferred and not set.direct
	set.postEffects = settings.postEffects
	set.refractions = settings.refractions and not set.direct
	set.format = settings.format
	
	assert(not set.deferred or not set.direct, "Deferred rendering is not compatible with direct rendering!")
	
	if not set.direct then
		--depth
		set.depth_buffer = love.graphics.newCanvas(w, h, {format = self.canvasFormats["depth32f"] and "depth32f" or self.canvasFormats["depth24"] and "depth24" or "depth16", readable = false, msaa = set.msaa})
		
		--temporary HDR color
		set.color = love.graphics.newCanvas(w, h, {format = settings.format, readable = true, msaa = set.msaa})
		
		--additional color if using refractions
		if set.refractions then
			set.colorAlpha = love.graphics.newCanvas(w, h, {format = settings.format, readable = true, msaa = set.msaa})
		end
		
		--depth
		set.depth = love.graphics.newCanvas(w, h, {format = "r16f", readable = true, msaa = set.msaa})
	end
	
	--deferred rendering
	if set.deferred then
		set.position = love.graphics.newCanvas(w, h, {format = settings.format, readable = true, msaa = set.msaa})
		set.normal = love.graphics.newCanvas(w, h, {format = settings.format, readable = true, msaa = set.msaa})
		set.material = love.graphics.newCanvas(w, h, {format = settings.format, readable = true, msaa = set.msaa})
		set.albedo = love.graphics.newCanvas(w, h, {format = settings.format, readable = true, msaa = set.msaa})
	end
	
	--screen space ambient occlusion blurring canvases
	if self.AO_enabled and not set.direct then
		set.AO_1 = love.graphics.newCanvas(w*self.AO_resolution, h*self.AO_resolution, {format = "r8", readable = true, msaa = 0})
		set.AO_2 = love.graphics.newCanvas(w*self.AO_resolution, h*self.AO_resolution, {format = "r8", readable = true, msaa = 0})
	end
	
	--post effects
	if set.postEffects then
		--bloom blurring canvases
		if self.bloom_enabled then
			set.bloom_1 = love.graphics.newCanvas(w*self.bloom_resolution, h*self.bloom_resolution, {format = settings.format, readable = true, msaa = 0})
			set.bloom_2 = love.graphics.newCanvas(w*self.bloom_resolution, h*self.bloom_resolution, {format = settings.format, readable = true, msaa = 0})
		end
	end
	
	return set
end

--release set and free memory
function lib:unloadCanvasSet(set)
	if set then
		for d,s in pairs(set) do
			if type(set) == "userdata" and set.release then
				set:release()
			end
		end
	end
end

--load canvases
function lib.resize(self, w, h)
	--fully unload previous sets
	self:unloadCanvasSet(self.canvases)
	self:unloadCanvasSet(self.canvases_reflections)
	
	--canvases sets
	self.canvases = self:newCanvasSet(self.default_settings, w, h)
	self.canvases_reflections = self:newCanvasSet(self.reflections_settings)
	
	--sky box
	if self.sky_as_reflection then
		assert(not self.defaultReflection or self.defaultReflection.canvas, "defaultReflection seems to be a static reflection, disable dream.sky_as_reflection!")
		
		self.defaultReflection = {
			canvas = love.graphics.newCanvas(self.sky_resolution, self.sky_resolution, {format = self.sky_format, readable = true, msaa = 0, type = "cube", mipmaps = "manual"})
		}
	end
	
	self:loadShader()
	self:initJobs()
end

--applies settings and load canvases
function lib.init(self, w, h)
	if self.default_settings.direct then
		local width, height, flags = love.window.getMode()
		if flags.depth == 0 then
			print("Direct render is enabled, but there is no depth buffer! Using 16-bit depth from now on.")
			love.window.updateMode(width, height, {depth = 16})
		end
	end
	
	if self.autoExposure_enabled and self.default_settings.direct then
		print("Autoexposure does not work with direct render! Autoexposure has been disabled.")
		self.autoExposure_enabled = false
	end
	
	self:resize(w or love.graphics.getWidth(), h or love.graphics.getHeight())
	
	--reset shader
	self:loadShader()
	
	--reset lighting
	self.lighting = { }
	
	--reset cache
	self.cache = { }
	
	--create sun shadow if requested
	--TODO sun strength should receive setting
	self.sunObject = lib:newLight(1, 1, 1, 1, 1, 1, 5, "sun")
	if self.sun_shadow then
		self.sunObject.shadow = lib:newShadow("sun")
	else
		self.sunObject.shadow = nil
	end
end

--clears the current scene
function lib.prepare(self)
	self.scenes = { }
	
	lib:drawScene(self.scene)
	self.scene:clear()
	
	self.particleBatches = { }
	self.particleBatchesActive = { }
	self.particles = { }
	self.particlesEmissive = { }
	
	--keep track of reflections
	self.reflections_last = self.reflections or { }
	self.reflections = { }
	
	--shader modules referenced this frame
	self.allActiveShaderModules = { }
end

--add an object to the default scene
function lib:draw(obj, x, y, z, sx, sy, sz)
	self.delton:start("draw")
	
	--prepare transform matrix
	local transform
	if x then
		--simple transform with arguments, ignores object transformation matrix
		transform = mat4(
			sx or 1, 0, 0, x,
			0, sy or sx or 1, 0, y,
			0, 0, sz or sx or 1, z,
			0, 0, 0, 1
		)
		
		--also applies objects own transformation if present
		if obj.transform then
			transform = transform * obj.transform
		end
	else
		--pre defined transform
		transform = obj.transform
	end
	
	--fetch current color
	local col = vec4(love.graphics.getColor())
	
	--add to scene
	self.scene:add(obj, transform, col)
	
	self.delton:stop()
end

--will render this scene
function lib:drawScene(scene)
	self.scenes[scene] = true
end

--will render this batch
function lib:drawParticleBatch(batch)
	self.particleBatchesActive[batch.emissionTexture and true or false] = true
	self.particleBatches[batch] = true
end

--set vertical level of next particles
local vertical = 0.0
function lib:setParticleVertical(v)
	assert(type(v) == "number", "number expected, got " .. type(v))
	vertical = v
end
function lib:getParticleVertical()
	return vertical
end

--set emission multiplier of next particles
local emission = false
function lib:setParticleEmission(e)
	emission = e or false
end
function lib:getParticleEmission()
	return emission
end

--draw a particle
function lib:drawParticle(drawable, quad, x, y, z, ...)
	local r, g, b, a = love.graphics.getColor()
	if type(quad) == "userdata" and quad:typeOf("Quad") then
		self.particles[#self.particles+1] = {drawable, quad, {x, y, z}, {r, g, b, a}, vertical, emission or 0.0, {...}}
	else
		self.particles[#self.particles+1] = {drawable, {quad, x, y}, {r, g, b, a}, vertical, emission or 0.0, {z, ...}}
	end
end

--draw a particle with emission texture
function lib:drawEmissionParticle(drawable, emissionDrawable, quad, x, y, z, ...)
	local r, g, b, a = love.graphics.getColor()
	if type(quad) == "userdata" and quad:typeOf("Quad") then
		self.particlesEmissive[#self.particlesEmissive+1] = {drawable, emissionDrawable, quad, {x, y, z}, {r, g, b, a}, vertical, emission or 0.0, {...}}
	else
		self.particlesEmissive[#self.particlesEmissive+1] = {drawable, emissionDrawable, {quad, x, y}, {r, g, b, a}, vertical, emission or 0.0, {z, ...}}
	end
end

return lib