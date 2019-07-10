--[[
#part of the 3DreamEngine by Luke100000
#see init.lua for license and documentation
loader.lua - loads .obj files, loads vertex lists
--]]

local lib = _3DreamEngine

--master resource loader
lib.performance = 3
lib.performance_vertex = 1024
lib.performance_particlesystem = 64
lib.performance_parser = 512
lib.resourceLoader = {jobs = { }, self = lib, progress = 1, subProgress = 1}
function lib.resourceLoader.add(self, object, priority)
	self.jobs[#self.jobs+1] = {object = object, priority = priority or 3}
end
function lib.resourceLoader.update(self, time)
	time = (time or 1) / 1000
	local worked = false
	while time > 0 do
		if #self.jobs > 0 then
			if not self.jobs[self.progress] then
				self.progress = 1
			end
			
			local t = love.timer.getTime()
			self.jobs[self.progress].object:resume()
			time = time - (love.timer.getTime() - t)
			worked = true
			
			if self.jobs[self.progress].object.loaded then
				self.subProgress = 1
				table.remove(self.jobs, self.progress)
			else
				self.subProgress = self.subProgress + 1
				if self.subProgress > self.jobs[self.progress].priority then
					self.subProgress = 1
					self.progress = self.progress + 1
				end
			end
		else
			break
		end
	end
	if not worked then
		worked = self.self.textures:update()
	end
	return worked
end

function lib.loadObject(self, ...)
	local obj = self:loadObjectLazy(...)
	while obj:resume() do end
	obj.loaded = true
	return obj
end

function lib.loadObjectLazy(self, path, args)
	if args and type(args) ~= "table" then
		error("arguments are now packed in a table, check init.lua for example")
	end
	args = args or { }
	
	--make absolute
	for _,typ in ipairs({
		"mtl",
		"vox",
		"3de",
		"obj",
	}) do
		if love.filesystem.getInfo(self.objectDir .. path .. "." .. typ) then
			path = self.objectDir .. path
			break
		end
	end
	
	--get name and dir
	local n = self:split(path, "/")
	name = n[#n] or path
	local dir = #n > 1 and table.concat(n, "/", 1, #n-1) or ""
	
	if rasterMargin == true then rasterMargin = 2 end
	local obj = {
		materials = {None = {color = {1.0, 1.0, 1.0, 1.0}, specular = 0.5, name = "None", ID = 1}},
		materialsID = {"None"},
		objects = {
			default = {		
				--store final vertices (vertex position + extra float used for anim, normal, material index, UV [pos] will be removed if not needed before sync, [tangent, bitangent] if not flat shading)
				final = { },
				
				--store final faces, 3 final indices
				faces = { },
				
				name = "default",
			}
		},
		
		lights = { },
		
		path = path, --absolute path to object
		name = name, --name of object
		dir = dir, --dir containing the object
		splitMaterials = args.splitMaterials,
		raster = args.raster,
		forceTextured = args.forceTextured,
		noMesh = args.noMesh,
		cleanup = (args.cleanup == nil or args.cleanup),
		
		transform = matrix{
			{1, 0, 0, 0},
			{0, 1, 0, 0},
			{0, 0, 1, 0},
			{0, 0, 0, 1},
		},
		
		reset = self.reset,
		translate = self.translate,
		scale = self.scale,
		rotateX = self.rotateX,
		rotateY = self.rotateY,
		rotateZ = self.rotateZ,
		
		self = self,
	}
	
	obj.co = coroutine.create(self.loadObjectC)
	
	obj.loaded = false
	obj.resume = function(self)
		if not self.loaded then
			local ok, err = coroutine.resume(self.co, self.self, self)
			if not ok and err ~= "cannot resume dead coroutine" then
				error("loader coroutine crashed:\n" .. tostring(err) .. "\n" .. debug.traceback(self.co))
			end
			return ok
		end
	end
	
	return obj
end

function lib.loadObjectC(self, obj)
	obj.objects.default.material = obj.materials.None
	
	--load textures
	self.textures:add(obj.dir, true)
	
	--load files
	--if two object files are available (.obj and .vox) it might crash, since it loads all
	local found = false
	for _,typ in ipairs({
		"mtl",
		"vox",
		"3de",
		"obj",
	}) do
		if love.filesystem.getInfo(obj.path .. "." .. typ) then
			found = true
			--load the simplified objects if existing
			for i = 8, 1, -1 do
				if love.filesystem.getInfo(obj.path .. "_simple_" .. i .. "." .. typ) then
					--load object and insert it to current
					self.loader[typ](self, obj, obj.name .. "_simple_" .. i, obj.path, i)
					
					coroutine.yield()
					
					--sync
					self:syncObj(obj)
					coroutine.yield()
				end
			end
			
			self.loader[typ](self, obj, obj.name, obj.path)
			for d,s in pairs(obj.objects) do
				if not s.simpler and obj.objects[d .. "_simple_1"] then
					s.simpler = d .. "_simple_1"
				end
			end
			coroutine.yield()
		end
	end
	if not found then
		error("object " .. obj.name .. " not found (" .. obj.path .. ")")
	end
	
	--link textures
	for d,s in pairs(obj.materials) do
		local p_material = (d .. "_")
		local p_name = (obj.name .. "_")
		for _,t in ipairs({"diffuse", "normal", "specular"}) do
			local custom = s["tex_" .. t]
			s["tex_" .. t] = nil
			for _,p in ipairs({
				custom and (obj.dir .. "/" .. custom) or false,
				custom or false,
				obj.dir .. "/" .. p_material .. t,
				p_material .. t,
				obj.dir .. "/" .. p_name .. t,
				p_name .. t,
			}) do
				if p and self.textures:get(p) then
					s["tex_" .. t] = p
					break
				end
			end
			
			--failed to load custom iamge set in mtl
			if custom and not s["tex_" .. t] then
				error("can not find texture specified in the .mtl file: " .. tostring(custom))
			end
		end
	end
	
	--if raster is enabled, calculate their position in the grid
	if obj.raster then
		for d,o in pairs(obj.objects) do
			--move objects to their center
			local x, y, z = 0, 0, 0
			for i,v in ipairs(o.final) do
				x = x + v[1]
				y = y + v[2]
				z = z + v[3]
			end
			o.x = math.ceil(x / #o.final)
			o.y = math.ceil(y / #o.final)
			o.z = math.ceil(z / #o.final)
			
			for i,v in ipairs(o.final) do
				v[1] = v[1] - o.x
				v[2] = v[2] - o.y
				v[3] = v[3] - o.z
			end
		end
	end
	
	--load objects first
	self:syncObj(obj)
	coroutine.yield()
	
	--create particle systems
	self:addParticlesystems(obj)
	coroutine.yield()
	
	--and their meshes
	self:syncObj(obj)
	coroutine.yield()
	
	--cleaning up
	if obj.cleanup then
		for d,s in pairs(obj.objects) do
			s.faces = nil
			s.final = nil
		end
		collectgarbage()
	end
	coroutine.yield()
	
	--if raster is enabled, rename the objects to a 3 dim array based on the position calculated before
	if obj.raster then
		local objects = obj.objects
		obj.objects = { }
		for d,o in pairs(objects) do
			obj.objects[o.x] = obj.objects[o.x] or { }
			obj.objects[o.x][o.y] = obj.objects[o.x][o.y] or { }
			if obj.objects[o.x][o.y][o.z] then
				print("object atlas intersection at " .. o.x .. "*" .. o.y .. "*" .. o.z .. ": " .. d)
			end
			obj.objects[o.x][o.y][o.z] = o
		end
	end
	
	obj.loaded = true
	return true
end

function lib.syncObj(self, obj)
	--add light sources
	for d,s in pairs(obj.objects) do
		pos = s.name:find("LAMP")
		if pos then
			local x, y, z = 0, 0, 0
			for i,v in ipairs(s.final) do
				x = x + v[1]
				y = y + v[2]
				z = z + v[3]
			end
			x = x / #s.final
			y = y / #s.final
			z = z / #s.final
			obj.lights[#obj.lights+1] = {
				name = s.name:sub(pos+5),
				x = x,
				y = y,
				z = z,
			}
			obj.objects[d] = nil
		end
	end
	
	--remove empty objects
	for d,s in pairs(obj.objects) do
		if s.final and #s.final == 0 then
			obj.objects[d] = nil
		end
	end
	
	--fill mesh(es)
	if not obj.noMesh then
		for d,s in pairs(obj.objects) do
			if not s.finished then
				s.finished = true
				self:createMesh(s, obj, nil, obj.forceTextured)
				coroutine.yield()
			end
		end
	end
end

--takes an final and face table (inside obj) and generates the mesh and vertexMap
--if a faceMap is provided, it will generate the mesh by adding the face faceMap[1] linked to the final vertex data faceMap[2] with translation faceMap[3-5] and Y-rotation faceMap[6]
function lib.createMesh(self, o, obj, faceMap, forceTextured)
	if not o.material then
		o.material = {color = {1.0, 1.0, 1.0, 1.0}, specular = 0.5, name = "None"}
	end
	local atypes
	if o.material.tex_diffuse or forceTextured then
		atypes = {
		  {"VertexPosition", "float", 4},	-- x, y, z
		  {"VertexTexCoord", "float", 2},	-- UV
		  {"VertexNormal", "float", 3},		-- normal
		  {"VertexTangent", "float", 3},	-- normal tangent
		  {"VertexBitangent", "float", 3},	-- normal bitangent
		}
	else
		atypes = {
		  {"VertexPosition", "float", 4},	-- x, y, z
		  {"VertexTexCoord", "float", 4},	-- normal, specular
		  {"VertexColor", "byte", 4},		-- color
		}
	end
	
	--compress finals (not all used)
	local vertexMap = { }
	local finals = { }
	local finalsIDs = { }
	if faceMap then
		for d,f in ipairs(faceMap) do
			finalsIDs = { }
			for i = 1, 3 do
				if not finalsIDs[f[1][i]] then
					local fc = f[2][f[1][i]]
					local x, z = self:rotatePoint(fc[1], fc[3], -f[6])
					local nx, nz = self:rotatePoint(fc[5], fc[7], -f[6])
					finals[#finals+1] = {x + f[3], fc[2] + f[4], z + f[5], 1.0, nx, fc[6], nz, fc[8], fc[9], fc[10]}
					finalsIDs[f[1][i]] = #finals
				end
				vertexMap[#vertexMap+1] = finalsIDs[f[1][i]]
			end
		end
	else
		for d,f in ipairs(o.faces) do
			for i = 1, 3 do
				if not finalsIDs[f[i]] then
					finals[#finals+1] = o.final[f[i]]
					finalsIDs[f[i]] = #finals
				end
				vertexMap[#vertexMap+1] = finalsIDs[f[i]]
			end
		end
	end
	coroutine.yield()
	
	--calculate vertex normals and uv normals
	if o.material.tex_diffuse or forceTextured then
		for f = 1, #vertexMap, 3 do
			local P1 = finals[vertexMap[f+0]]
			local P2 = finals[vertexMap[f+1]]
			local P3 = finals[vertexMap[f+2]]
			local N1 = finals[vertexMap[f+0]]
			local N2 = finals[vertexMap[f+1]]
			local N3 = finals[vertexMap[f+2]]
			
			local tangent = { }
			local bitangent = { }
			
			local edge1 = {P2[1] - P1[1], P2[2] - P1[2], P2[3] - P1[3]}
			local edge2 = {P3[1] - P1[1], P3[2] - P1[2], P3[3] - P1[3]}
			local edge1uv = {N2[9] - N1[9], N2[10] - N1[10]}
			local edge2uv = {N3[9] - N1[9], N3[10] - N1[10]}
			
			local cp = edge1uv[2] * edge2uv[1] - edge1uv[1] * edge2uv[2]
			
			if cp ~= 0.0 then
				for i = 1, 3 do
					tangent[i] = (edge1[i] * edge2uv[2] - edge2[i] * edge1uv[2]) / cp
					bitangent[i] = (edge2[i] * edge1uv[1] - edge1[i] * edge2uv[1]) / cp
				end
				
				local l = math.sqrt(tangent[1]^2+tangent[2]^2+tangent[3]^2)
				tangent[1] = tangent[1] / l
				tangent[2] = tangent[2] / l
				tangent[3] = tangent[3] / l
				
				local l = math.sqrt(bitangent[1]^2+bitangent[2]^2+bitangent[3]^2)
				bitangent[1] = bitangent[1] / l
				bitangent[2] = bitangent[2] / l
				bitangent[3] = bitangent[3] / l
				
				for i = 1, 3 do
					finals[vertexMap[f+i-1]][11] = (finals[vertexMap[f+i-1]][11] or 0) + tangent[1]
					finals[vertexMap[f+i-1]][12] = (finals[vertexMap[f+i-1]][12] or 0) + tangent[2]
					finals[vertexMap[f+i-1]][13] = (finals[vertexMap[f+i-1]][13] or 0) + tangent[3]
					
					finals[vertexMap[f+i-1]][14] = (finals[vertexMap[f+i-1]][14] or 0) + bitangent[1]
					finals[vertexMap[f+i-1]][15] = (finals[vertexMap[f+i-1]][15] or 0) + bitangent[2]
					finals[vertexMap[f+i-1]][16] = (finals[vertexMap[f+i-1]][16] or 0) + bitangent[3]
				end
			end
			
			if f % 1024*3 == 0 then
				coroutine.yield()
			end
		end
		
		coroutine.yield()
		
		--complete smoothing step
		for d,f in ipairs(finals) do
			if f[11] then
				--Gram-Schmidt orthogonalization
				local dot = (f[11] * f[5] + f[12] * f[6] + f[13] * f[7])
				f[11] = f[11] - f[5] * dot
				f[12] = f[12] - f[6] * dot
				f[13] = f[13] - f[7] * dot
				
				local l = math.sqrt(f[11]^2+f[12]^2+f[13]^2)
				f[11] = -f[11] / l
				f[12] = -f[12] / l
				f[13] = -f[13] / l
				
				l = math.sqrt(f[14]^2+f[15]^2+f[16]^2)
				f[14] = f[14] / l
				f[15] = f[15] / l
				f[16] = f[16] / l
			end
		end
	end
	coroutine.yield()
	
	--create mesh
	o.mesh = love.graphics.newMesh(atypes, #finals, "triangles", "static")
	coroutine.yield()
	
	--vertex map
	o.mesh:setVertexMap(vertexMap)
	coroutine.yield()
	
	local t = love.timer.getTime()
	local yield = 0
	for d,s in ipairs(finals) do
		vertexMap[#vertexMap+1] = s[i]
		local m = o.materialsID and o.materialsID[s[8]] or  obj.materialsID[s[8]]
		local c = m.color
		if o.material.tex_diffuse or forceTextured then
			o.mesh:setVertex(d,
				s[1], s[2], s[3], s[4],
				s[9], s[10],
				s[5], s[6], s[7],
				s[11], s[12], s[13],
				s[14], s[15], s[16]
			)
		else
			o.mesh:setVertex(d,
				s[1], s[2], s[3], s[4],
				s[5], s[6], s[7],
				m.specular,
				c[1], c[2], c[3], c[4]
			)
		end
		
		yield = yield + 1
		if yield > self.performance_vertex then
			yield = 0
			local diff = (love.timer.getTime() - t) * 1000
			self.performance_vertex = self.performance_vertex + (diff < self.performance and 32 or -32)
			coroutine.yield()
			t = love.timer.getTime()
		end
	end
	
	o.mesh:flush()
	o.meshLoaded = true
	coroutine.yield()
end