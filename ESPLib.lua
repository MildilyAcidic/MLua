-- Made by @nulare, just hosting it on my github for  him --
--[[
v1.03b esp lib
@nulare on discord

ESPLib.new<GroupBehaviour> -> ESPGroup

{ESPComponent} ESPLib.Component
{ESPMode} ESPLib.Mode

ESPGroup:SetGroupContainer(<Folder | Model>)
ESPGroup:Add(entity) -> entity
ESPGroup:Unadd(entity)
ESPGroup:Toggle(boolean | nil)
ESPGroup:ToggleComponent(ESPComponent)
ESPGroup:SetAccent(Color3 | nil)
ESPGroup:SetMaxDistance(number | nil)
ESPGroup:Step()
ESPGroup:Destroy()

<Color3 | function> GroupBehaviour.Accent
<number> GroupBehaviour.MaxDistance
<ESPMode> GroupBehaviour.Mode
<function> GroupBehaviour.ValidateEntry(entry)
<function> GroupBehaviour.FetchEntryName(entry)
<function> GroupBehaviour.TraverseEntry(entry)
<function> GroupBehaviour.MeasureEntry(entry)
{Flag} GroupBehaviour.Flags

<function> Flag -> boolean | string

Games Unite Testing Place
local espGroup = ESPLib.new{
    TraverseEntry = function(entry)
        return entry:FindFirstChild('Accessories')
    end,

    FetchEntryName = function(_entry)
        return 'Enemy'
    end,
}

espGroup:SetGroupContainer(workspace.Playermodels)

pcall(function()
    while true do
        espGroup:Step()

        wait(1/240)
    end
end)

espGroup:Destroy()

Zombie Attack
local zombies = ESPLib.new{Accent = RED}
zombies:SetGroupContainer(workspace.enemies)

pcall(function()
    while true do
        zombies:Step()

        wait(1/240)
    end
end)

zombies:Destroy()

]]

ESPLib = {}
ESPLib.__index = ESPLib

RED = Color3(1, 0, 0)
GREEN = Color3(0, 1, 0)
BLUE = Color3(0, 0, 1)
YELLOW = Color3(1, 1, 0)
CYAN = Color3(0, 1, 1)
PINK = Color3(1, 0, 1)
WHITE = Color3(1, 1, 1)
BLACK = Color3(0, 0, 0)

ESP_FONTSIZE = 7 -- works great with ProggyClean
DEFAULT_PARTS_SIZING = {
    Head = Vector3(2, 1, 1),

    Torso = Vector3(2, 2, 1),
    ['Left Arm'] = Vector3(1, 2, 1),
    ['Right Arm'] = Vector3(1, 2, 1),
    ['Left Leg'] = Vector3(1, 2, 1),
    ['Right Leg'] = Vector3(1, 2, 1),

    UpperTorso = Vector3(2, 1, 1),
    LowerTorso = Vector3(2, 1, 1),
    LeftUpperArm = Vector3(1, 1, 1),
    LeftLowerArm = Vector3(1, 1, 1),
    LeftHand = Vector3(0.3, 0.3, 1),
    RightUpperArm = Vector3(1, 1, 1),
    RightLowerArm = Vector3(1, 1, 1),
    RightHand = Vector3(0.3, 0.3, 1),
    LeftUpperLeg = Vector3(1, 1, 1),
    LeftLowerLeg = Vector3(1, 1, 1),
    LeftFoot = Vector3(0.3, 0.3, 1),
    RightUpperLeg = Vector3(1, 1, 1),
    RightLowerLeg = Vector3(1, 1, 1),
    RightFoot = Vector3(0.3, 0.3, 1),
}

local myCamera = workspace.CurrentCamera

local function vec3Magnitude(vec)
    return math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
end

local function vec3Unit(vec)
    local magnitude = vec3Magnitude(vec)
    if magnitude == 0 then
        return Vector3(0, 0, 0)
    end

    return Vector3(vec.x / magnitude, vec.y / magnitude, vec.z / magnitude)
end

local function rotateY(vec, angle)
    local x = math.sin(angle)
    local y = math.cos(angle)

    return Vector3(vec.x * x - vec.z * y, 0, vec.x * y + vec.z * x)
end

local function destroyAllDrawings(drawingsTable)
    for _, drawing in ipairs(drawingsTable) do
        drawing:Remove()
    end
end

local function undrawAll(drawingsTable)
    for _, drawing in ipairs(drawingsTable) do
        drawing.Visible = false
    end
end

function ESPLib.new(groupBehaviour)
    local self = setmetatable({}, ESPLib)

    self._objects = {}
    self._objectContainer = nil
    self._objectContainerLength = -1
    self._containerLastUpdate = 0
    -- people dont like snapline :(
    self._components = { bbox = true, name = true, distance = true, flags = groupBehaviour.Flags ~= nil, snapline = false }
    self._running = true
    
    self._gb_accent = groupBehaviour.Accent or WHITE
    self._gb_distance = groupBehaviour.MaxDistance or nil
    self._gb_mode = groupBehaviour.Mode or ESPLib.Mode['Standard']
    self._gb_validateEntry = groupBehaviour.ValidateEntry or nil
    self._gb_fetchEntryName = groupBehaviour.FetchEntryName or nil
    self._gb_traverseEntry = groupBehaviour.TraverseEntry or nil
    self._gb_measureEntry = groupBehaviour.MeasureEntry or nil
    self._gb_isEntryLocal = groupBehaviour.IsEntryLocal or nil
    self._gb_flags = groupBehaviour.Flags or nil

    return self
end

ESPLib.Component = {
    ['Box'] = 'bbox',
    ['Name'] = 'name',
    ['Distance'] = 'distance',
    ['Flags'] = 'flags',
    ['Snapline'] = 'snapline'
}

ESPLib.Mode = {
    ['Critical'] = 0,
    ['Standard'] = 1,
    ['Lazy'] = nil
}

ESPLib.Validation = {
    ['Matching Name'] = function(pattern)
        return function(entry)
            return entry.Name:lower():find(pattern:lower()) ~= nil
        end
    end
}

function ESPLib._IsBasePart(part)
    return part.ClassName:lower():find('part') ~= nil
end

function ESPLib._GetTextBounds(str)
    return #str * ESP_FONTSIZE, ESP_FONTSIZE
end

function ESPLib:_DistanceFromLocal(root)
    if not self._IsBasePart(root) then
        root = root:FindFirstChildOfClass('Part') or root:FindFirstChildOfClass('MeshPart')
    end

    if root == nil then
        return 0
    end

    local rootPos = root.Position
    return vec3Magnitude(myCamera.Position + Vector3(-rootPos.x, -rootPos.y, -rootPos.z))
end

function ESPLib:_BoundingBox(instance)
    local minX, minY, maxX, maxY = 0, 0, 0, 0

    local children = self._IsBasePart(instance) and {instance} or instance:GetChildren()
    local cameraPos = myCamera.Position
    local allVisible = #children > 0
    for _, child in ipairs(children) do
        local childName = child.Name

        if allVisible and self._IsBasePart(child) then
            local childOrigin = child.Position
            local childSize = self._gb_measureEntry and self._gb_measureEntry(instance) or (DEFAULT_PARTS_SIZING[childName] ~= nil and DEFAULT_PARTS_SIZING[childName] or Vector3(1, 1, 1))
            
            local direction = vec3Unit(Vector3(childOrigin.x - cameraPos.x, 0, childOrigin.z - cameraPos.z))
            local angle = math.atan2(direction.x, direction.z)

            local halvedSize = Vector3(childSize.x / 2, childSize.y / 2, childSize.z / 2)
            local vertices = math.abs(vec3Magnitude(childSize)) < 0.2 and {childOrigin} or {
                childOrigin + rotateY(Vector3(-halvedSize.x, 0, -halvedSize.z), angle) + Vector3(0, halvedSize.y, 0),
                childOrigin + rotateY(Vector3(halvedSize.x, 0, halvedSize.z), angle) + Vector3(0, -halvedSize.y, 0),
            }

            for _, vertex in ipairs(vertices) do
                local screenPos, onScreen = WorldToScreen(vertex)
                if not onScreen and allVisible then
                    allVisible = false
                elseif allVisible then
                    minX = minX == 0 and screenPos.x or math.min(minX, screenPos.x)
                    minY = minY == 0 and screenPos.y or math.min(minY, screenPos.y)

                    maxX = math.max(maxX, screenPos.x)
                    maxY = math.max(maxY, screenPos.y)
                end
            end
        elseif allVisible and child.ClassName == 'Model' or child.ClassName == 'Folder' then
            local _, childMinX, childMinY, childWidth, childHeight = self:_BoundingBox(child)

            minX = minX == 0 and childMinX or math.min(minX, childMinX)
            minY = minY == 0 and childMinY or math.min(minY, childMinY)

            maxX = math.max(maxX, childMinX + childWidth)
            maxY = math.max(maxY, childMinY + childHeight)
        end
    end

    -- dumb
    return allVisible and minX > 0, minX, minY, maxX - minX, maxY - minY
end

function ESPLib:Toggle(state)
    self._running = type(state) == 'boolean' and state or not self._running
end

function ESPLib:ToggleComponent(componentName, state)
    local component = self._components[componentName]
    if component ~= nil then
        self._components[componentName] = type(state) == 'boolean' and state or not component
    end
end

function ESPLib:SetMaxDistance(distance)
    self._gb_distance = tonumber(distance) or nil
end

function ESPLib:SetAccent(accent)
    self._gb_accent = accent or WHITE
end

function ESPLib:SetGroupContainer(container)
    self._objectContainer = container
end

function ESPLib:Add(entry)
    -- meta objects
    local espBbox = Drawing.new('Square')
    espBbox.Thickness = 1
    espBbox.Filled = false
    local espBboxOutlineInner = Drawing.new('Square')
    espBboxOutlineInner.Thickness = 1
    espBboxOutlineInner.Filled = false
    local espBboxOutlineOuter = Drawing.new('Square')
    espBboxOutlineOuter.Thickness = 1
    espBboxOutlineOuter.Filled = false

    local espSnapline = Drawing.new('Line')
    espSnapline.Thickness = 1

    local espName = Drawing.new('Text')
    espName.Outline = true
    local espDistance = Drawing.new('Text')
    espDistance.Outline = true

    local espFlags = {}
    if self._gb_flags then
        for _, _ in pairs(self._gb_flags) do
            local flagText = Drawing.new('Text')
            flagText.Outline = true
            flagText.Color = Color3(1, 1, 1)

            table.insert(espFlags, flagText)
        end
    end

    self._objects[entry] = {
        ['class'] = entry.ClassName,
        ['_drawings'] = { espBbox, espBboxOutlineInner, espBboxOutlineOuter, espName, espDistance, espSnapline, unpack(espFlags) }
    }

    return entry
end

function ESPLib:Unadd(entry)
    if self._objects[entry] then
        destroyAllDrawings(self._objects[entry]['_drawings'])

        self._objects[entry] = nil
    end
end

function ESPLib:Clear()
    for entry, _ in pairs(self._objects) do
        self:Unadd(entry)
    end
end

function ESPLib:Step()
    -- refresh container
    local now = os.clock()
    if self._objectContainer and now - self._containerLastUpdate > (self._gb_mode and (self._gb_mode == 1 and 0 or 0.33) or 1) then
        local children = self._objectContainer:GetChildren()
        if #children ~= self._objectContainerLength then
            self:Clear()
    
            self._objectContainerLength = #children
            for _, child in ipairs(children) do
                if self._gb_validateEntry == nil or self._gb_validateEntry and self._gb_validateEntry(child) == true then
                    self:Add(child)
                end
            end
        end
    
        self._containerLastUpdate = now
    end

    -- draw all entries
    for root, entryData in pairs(self._objects) do
        local drawings = entryData['_drawings']

        -- does the entry exist?
        local shouldDraw = self._running
        if root == nil then
            self:Unadd(root)

            shouldDraw = false
        end

        -- is the entry valid?
        if shouldDraw and self._gb_validateEntry then
            shouldDraw = self._gb_validateEntry(root)
        end

        -- point to our entry model
        local entryModel = shouldDraw and (self._gb_traverseEntry and self._gb_traverseEntry(root) or root) or nil
        local distance = 0

        local onScreen, bboxLeft, bboxTop, bboxWidth, bboxHeight = false, 0, 0, 0, 0
        if shouldDraw and entryModel then
            distance = math.floor(self:_DistanceFromLocal(entryModel))

            if self._gb_distance == nil or self._gb_distance ~= nil and distance <= self._gb_distance then
                onScreen, bboxLeft, bboxTop, bboxWidth, bboxHeight = self:_BoundingBox(entryModel)
            else
                shouldDraw = false
            end
        end

        if onScreen and shouldDraw and root then
            local rootName = tostring(root.Name)
            if self._gb_fetchEntryName then
                rootName = self._gb_fetchEntryName(root)
            end

            local rootAccent = type(self._gb_accent) == 'function' and self._gb_accent(root) or self._gb_accent

            -- draw bbox
            local espBbox = drawings[1]
            local espBboxOutlineInner = drawings[2]
            local espBboxOutlineOuter = drawings[3]

            if self._components['bbox'] == true then
                espBboxOutlineInner.Position = Vector2(bboxLeft + 1, bboxTop + 1)
                espBboxOutlineInner.Size = Vector2(bboxWidth - 2, bboxHeight - 2)
                espBboxOutlineInner.Color = BLACK
                espBboxOutlineInner.Visible = true
    
                espBboxOutlineOuter.Position = Vector2(bboxLeft - 1, bboxTop - 1)
                espBboxOutlineOuter.Size = Vector2(bboxWidth + 2, bboxHeight + 2)
                espBboxOutlineOuter.Color = BLACK
                espBboxOutlineOuter.Visible = true
    
                espBbox.Position = Vector2(bboxLeft, bboxTop)
                espBbox.Size = Vector2(bboxWidth, bboxHeight)
                espBbox.Color = rootAccent
                espBbox.Visible = true
            else
                espBbox.Visible = false
                espBboxOutlineInner.Visible = false
                espBboxOutlineOuter.Visible = false
            end

            -- draw name
            local espName = drawings[4]

            if self._components['name'] then
                local nameSizeX, nameSizeY = self._GetTextBounds(rootName)

                espName.Position = Vector2(bboxLeft - nameSizeX / 2 + bboxWidth / 2, bboxTop - nameSizeY - 6)
                espName.Color = WHITE
                espName.Text = rootName
                espName.Visible = true
            else
                espName.Visible = false
            end

            -- draw distance
            local espDistance = drawings[5]

            if self._components['distance'] then
                local distanceString = '[' .. tostring(distance) .. 'm]'
                local distanceSizeX, distanceSizeY = self._GetTextBounds(distanceString) 
    
                espDistance.Position = Vector2(bboxLeft - distanceSizeX / 2 + bboxWidth / 2, bboxTop + bboxHeight + 2)
                espDistance.Color = WHITE
                espDistance.Text = distanceString
                espDistance.Visible = true
            else
                espDistance.Visible = false
            end

            -- draw snapline
            local espSnapline = drawings[6]

            if self._components['snapline'] then
                espSnapline.From = Vector2(0, 0)
                espSnapline.To = Vector2(bboxLeft + bboxWidth / 2, bboxTop)
                espSnapline.Color = rootAccent
                espSnapline.Visible = true
            else
                espSnapline.Visible = false
            end

            -- draw user flags
            if self._gb_flags and self._components['flags'] then
                local flagEntryY = 0
                local _, flagHeight = self._GetTextBounds('')

                local i = 0
                for flagName, flagFunc in pairs(self._gb_flags) do
                    i = i + 1

                    local espFlag = drawings[6 + i]
                    local flagValue = flagFunc(root)
                    if flagValue == true then
                        flagValue = '*' .. flagName .. '*'
                    elseif flagValue == false or flagValue == '' then
                        flagValue = nil
                    elseif flagValue ~= nil then
                        flagValue = tostring(flagValue)
                    end

                    if flagValue then
                        espFlag.Position = Vector2(bboxLeft + bboxWidth + 2, bboxTop + flagEntryY)
                        espFlag.Text = flagValue
                        espFlag.Visible = true

                        flagEntryY = flagEntryY + flagHeight + 4
                    else
                        espFlag.Visible = false
                    end
                end
            end
        elseif root ~= nil then
            undrawAll(drawings)
        end
    end
end

function ESPLib:Destroy()
    self:Toggle(false)
    self:Clear()
end

-- ESPLib end
