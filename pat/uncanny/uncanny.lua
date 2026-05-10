local Uncanny = {}
pat_uncanny = Uncanny

function Uncanny:init()
  local cfg = root.assetJson("/pat/uncanny/uncanny.config")

  self.phases = {}
  for _, phase in pairs(cfg.phases) do
    phase.size = root.imageSize(phase.image)
    phase.size[1] = phase.size[1] / 8
    phase.size[2] = phase.size[2] / 8
    phase.area = phase.size[1] * phase.size[2]
    self.phases[#self.phases + 1] = phase
  end
  table.sort(self.phases, function(a, b) return a.sort < b.sort end)

  self.phaseTimer = 0
  self.phaseCount = #self.phases - 1
  self.speed = cfg.speed

  self.scaleMin = cfg.scaleMin * cfg.screenScale
  self.scaleMax = cfg.scaleMax * cfg.screenScale
  self.scaleSpeed = (self.scaleMax - self.scaleMin) / self.speed
  self.scale = (self.scaleMin + self.scaleMax) / 2

  local r = sb.makeRandomSource()
  self.directions = { x = r:randb(), y = r:randb(), z = r:randb() }

  self.drawable = {
    fullbright = true,
    centered = false
  }
end

function Uncanny:update(dt)
  self.phaseTimer = math.max(0, self.phaseTimer - dt)
  local phase = self:getPhase()

  local rect = world.clientWindow()
  local ePos = entity.position()
  rect[1] = world.nearestTo(ePos[1], rect[1])
  rect[3] = world.nearestTo(ePos[1], rect[3])

  local d = self.drawable
  local dir = self.directions
  self.scale, dir.z = self:move(self.scale, self.scaleSpeed * dt, self.scaleMin, self.scaleMax, dir.z)
  d.image = phase.image
  d.scale = self.scale * ((rect[3] - rect[1]) / phase.size[1])

  local xMin = rect[1] - ePos[1]
  local yMin = rect[2] - ePos[2]
  local xMax = rect[3] - ePos[1] - (phase.size[1] * d.scale)
  local yMax = rect[4] - ePos[2] - (phase.size[2] * d.scale)
  
  local diag = math.sqrt((xMax - xMin) ^ 2 + (yMax - yMin) ^ 2)
  local speed = diag / self.speed * dt

  if not d.position then
    local r = sb.makeRandomSource()
    d.position = { r:randf(xMin, xMax), r:randf(yMin, yMax) }
  end
  
  local pos = d.position
  pos[1], dir.x = self:move(pos[1], speed, xMin, xMax, dir.x)
  pos[2], dir.y = self:move(pos[2], speed, yMin, yMax, dir.y)

  localAnimator.addDrawable(d, "Overlay+67")
end

function Uncanny:move(n, speed, min, max, neg)
  n = n + (neg and -speed or speed)
  if n <= min then return min, false end
  if n >= max then return max, true end
  return n, neg
end

function Uncanny:getPhase()
  if self.currentPhase and self.phaseTimer > 0 then
    return self.phases[self.currentPhase]
  end

  local v = self:cannyPercentage()
  local i = math.floor(self.phaseCount * v) + 1
  local phase = self.phases[i]
  if i ~= self.currentPhase then
    self.currentPhase = i
    self.phaseTimer = phase.time
    self:playSound(phase.sound)
  end

  return phase
end

function Uncanny:cannyPercentage()
  local health = status.resourcePercentage("health")
  local energy = status.resourcePercentage("energy")
  if status.resourceLocked("energy") then energy = 0 end
  local v = math.min(health, (health + energy) / 2)
  return math.max(0, math.min(v, 1))
end

local soundPane = {
  gui = jobject(),
  scripts = { "/pat/uncanny/playsound.lua" }
}
function Uncanny:playSound(file)
  if not file then return end
  soundPane.sound = file
  player.interact("ScriptPane", soundPane)
end

local _init, _update = init, update
function init() _init() Uncanny:init() end
function update(dt) _update(dt) Uncanny:update(dt) end
