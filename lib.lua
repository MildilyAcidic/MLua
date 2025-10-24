-- > setup UserInputService and drawing wrapper libraries
local Camera = workspace.CurrentCamera
local allDrawings = {}

local UDim2 = {}
UDim2.__index = UDim2

-- normal constructor (Scale + Offset)
local function new(scaleX, offsetX, scaleY, offsetY)
    return {
        X = { Scale = scaleX or 0, Offset = offsetX or 0 },
        Y = { Scale = scaleY or 0, Offset = offsetY or 0 }
    }
end

-- .fromOffset constructor (Offset-only)
function UDim2.fromOffset(xOffset, yOffset)
    return {
        X = { Scale = 0, Offset = xOffset or 0 },
        Y = { Scale = 0, Offset = yOffset or 0 }
    }
end

-- make UDim2 callable like a function
setmetatable(UDim2, {
    __call = function(_, scaleX, offsetX, scaleY, offsetY)
        return new(scaleX, offsetX, scaleY, offsetY)
    end
})

_G.UDim2 = UDim2

local function Signal()
    local self = {
        Connections = {},
        WaitingThreads = {}
    }

    function self:Connect(fn)
        table.insert(self.Connections, fn)
        return {
            Disconnect = function()
                for i, f in ipairs(self.Connections) do
                    if f == fn then
                        table.remove(self.Connections, i)
                        break
                    end
                end
            end
        }
    end

    function self:Once(fn)
        local connection
        connection = self:Connect(function(...)
            fn(...)
            connection.Disconnect()
        end)
        return connection
    end

    function self:Fire(...)
        local connections = table.clone and table.clone(self.Connections) or {table.unpack(self.Connections)}
        for _, fn in ipairs(connections) do
            fn(...)
        end

        for i, thread in ipairs(self.WaitingThreads) do
            task.spawn(thread, ...)
        end
        table.clear(self.WaitingThreads)
    end

    function self:Wait()
        local thread = coroutine.running()
        table.insert(self.WaitingThreads, thread)
        return coroutine.yield()
    end
    self.Event = self

    return self
end

local DrawingWrapper = {}
DrawingWrapper.__index = DrawingWrapper

function DrawingWrapper.new(className, properties)
    local real = Drawing.new(className)
    local self = setmetatable({
        _real = real,
        _pseudo = {
            Parent = nil,
            UDimPosition = nil,
            UDimSize = nil,
            AnchorPoint = Vector2.new(0, 0),
            BorderColor3 = nil,
            BorderSizePixel = 1,
            BorderMode = "Outset"
        },
        MouseEnter = Signal(),
        MouseLeave = Signal(),
        _wasMouseOver = false,
        _borderSquare = nil
    }, DrawingWrapper)

    for k, v in pairs(properties or {}) do
        self[k] = v
    end

    table.insert(allDrawings, self)
    return self
end

function DrawingWrapper:__index(key)
    if rawget(DrawingWrapper, key) then
        return DrawingWrapper[key]
    end

    local pseudo = rawget(self, "_pseudo")
    local real = rawget(self, "_real")

    if pseudo and pseudo[key] ~= nil then
        return pseudo[key]
    end

    if pcall(function()
        return real[key]
    end) then
        return real[key]
    end
end

function DrawingWrapper:__newindex(key, value)
    local real = rawget(self, "_real")
    local pseudo = rawget(self, "_pseudo")

    if key == "Parent" then
        pseudo.Parent = value
        self:UpdateLayout()
        
  
        if self._borderSquare then
            self._borderSquare._pseudo.Parent = value
        end
        
   
        if value and value._listLayout then
            task.defer(function()
                value._listLayout:Update()
            end)
        end
        return
    elseif key == "BorderColor3" then
        pseudo.BorderColor3 = value
        self:UpdateBorder()
        return
    elseif key == "BorderSizePixel" then
        pseudo.BorderSizePixel = value
        self:UpdateBorder()
        return
    elseif key == "BorderMode" then
        pseudo.BorderMode = value
        self:UpdateBorder()
        return
    elseif key == "LayoutOrder" then
        pseudo.LayoutOrder = value

        if pseudo.Parent and pseudo.Parent._listLayout then
            task.defer(function()
                pseudo.Parent._listLayout:Update()
            end)
        end
        return
    elseif key == "Visible" then
        real.Visible = value
        pseudo.Visible = value
        

        if self._borderSquare then
            self._borderSquare._real.Visible = value
        end
        
   
        if pseudo.Parent and pseudo.Parent._listLayout then
            task.defer(function()
                pseudo.Parent._listLayout:Update()
            end)
        end
        return
    elseif key == "UDimPosition" then
        pseudo.UDimPosition = value
        self:UpdateLayout()
        return
    elseif key == "UDimSize" then
        pseudo.UDimSize = value
        self:UpdateLayout()
        
      
        if pseudo.Parent then
            if pseudo.Parent._padding then
                task.defer(function()
                    pseudo.Parent._padding:Apply()
                end)
            end
            if pseudo.Parent._listLayout then
                task.defer(function()
                    pseudo.Parent._listLayout:Update()
                end)
            end
        end
        return
    elseif key == "Size" then
        local success = pcall(function()
            real.Size = value
        end)
        
        if success then
            self:UpdateBorder()
            
    
            if pseudo.Parent then
                if pseudo.Parent._padding then
                    task.defer(function()
                        pseudo.Parent._padding:Apply()
                    end)
                end
                if pseudo.Parent._listLayout then
                    task.defer(function()
                        pseudo.Parent._listLayout:Update()
                    end)
                end
            end
        end
        return
    elseif key == "Position" then
        local success = pcall(function()
            real.Position = value
        end)
        
        if success then
            self:UpdateBorder()
        end
        return
    end

    local success = pcall(function()
        real[key] = value
    end)

    if not success then
        pseudo[key] = value
    end
end

function DrawingWrapper:UpdateBorder()
    local pseudo = self._pseudo
    local real = self._real
    

    if tostring(real):match("Square") == nil then
        return
    end
    
    if pseudo.BorderColor3 and pseudo.BorderSizePixel and pseudo.BorderSizePixel > 0 then

        if not self._borderSquare then
            self._borderSquare = DrawingWrapper.new("Square", {
                Filled = false,
                Thickness = 1,
                ZIndex = (real.ZIndex or 1) - 1,
                Visible = real.Visible or true
            })
        end
        
        local border = self._borderSquare._real
        local borderPseudo = self._borderSquare._pseudo
        
      
        border.Color = pseudo.BorderColor3
        
   
        local borderSize = pseudo.BorderSizePixel
        
        if pseudo.BorderMode == "Inset" then
    
            border.Position = Vector2.new(
                real.Position.X + borderSize,
                real.Position.Y + borderSize
            )
            border.Size = Vector2.new(
                real.Size.X - (borderSize * 2),
                real.Size.Y - (borderSize * 2)
            )
        else 
   
            border.Position = Vector2.new(
                real.Position.X - borderSize,
                real.Position.Y - borderSize
            )
            border.Size = Vector2.new(
                real.Size.X + (borderSize * 2),
                real.Size.Y + (borderSize * 2)
            )
        end
        
        border.Thickness = borderSize
        
  
        if pseudo.Parent and not borderPseudo.Parent then
            borderPseudo.Parent = pseudo.Parent
        end
        
    elseif self._borderSquare then
        self._borderSquare:Destroy()
        self._borderSquare = nil
    end
end

function DrawingWrapper:UpdateLayout()
    local real = self._real
    local pseudo = self._pseudo
    local parent = pseudo.Parent

    local parentPos = (parent and parent.Position) or Vector2.new(0, 0)
    local vpSize = (parent and parent.Size) or Camera.ViewportSize

    if pseudo.UDimSize then
        local size = pseudo.UDimSize
        real.Size = Vector2.new(size.X.Scale * vpSize.X + size.X.Offset, size.Y.Scale * vpSize.Y + size.Y.Offset)
    end

    if pseudo.UDimPosition then
        local pos = pseudo.UDimPosition
        local anchor = pseudo.AnchorPoint or Vector2.new(0, 0)
        local size = real.Size

        real.Position = parentPos +
                            Vector2.new(pos.X.Scale * vpSize.X + pos.X.Offset, pos.Y.Scale * vpSize.Y + pos.Y.Offset) -
                            Vector2.new(size.X * anchor.X, size.Y * anchor.Y)
    end
    

    self:UpdateBorder()
end


function DrawingWrapper:Destroy()
 
    if self._borderSquare then
        self._borderSquare:Destroy()
        self._borderSquare = nil
    end
    
    gui_Destroy(self)
end

function DrawingWrapper:Refresh()
    self:UpdateLayout()
end

function DrawingWrapper:IsMouseOver()
    local Mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local mouseX, mouseY = Mouse.X, Mouse.Y
    local pos = self._real.Position
    local size = self._real.Size

    return mouseX >= pos.X and mouseX <= pos.X + size.X and mouseY >= pos.Y and mouseY <= pos.Y + size.Y
end

local function UpdateMouseStates()
    for _, drawing in ipairs(allDrawings) do
        if drawing._real.Visible then
            local isOver = drawing:IsMouseOver()

            if isOver and not drawing._wasMouseOver then
                drawing._wasMouseOver = true
                drawing.MouseEnter:Fire()
            elseif not isOver and drawing._wasMouseOver then
                drawing._wasMouseOver = false
                drawing.MouseLeave:Fire()
            end
        end
    end
end

local function GetActualSize(element)
    if element.Size then
        if type(element.Size) == "table" and element.Size.X then
            if element.Size.X.Offset then
                return Vector2.new(element.Size.X.Offset, element.Size.Y.Offset)
            end
            return element.Size
        end
    end
    if element._real and element._real.Size then
        return element._real.Size
    end
    return Vector2.new(0, 0)
end

local function GetActualPosition(element)
    if element._real and element._real.Position then
        return element._real.Position
    end
    return Vector2.new(0, 0)
end

local function gui_GetChildren(parent)
    local children = {}
    
    for _, child in ipairs(allDrawings) do
        if child._pseudo and child._pseudo.Parent == parent then
            table.insert(children, child)
        end
    end
    
    return children
end

local function gui_IsA(element, className)

    if className == "UIListLayout" then
        return element._listLayout ~= nil or getmetatable(element) == UIListLayout
    elseif className == "UIPadding" then
        return element._padding ~= nil or getmetatable(element) == UIPadding
    end
    
    -- Check for drawing types
    if element._real then
        local drawingType = tostring(element._real):match("^Drawing%.(%w+)")
        return drawingType == className
    end
    
    return false
end

local function gui_Destroy(element)
    -- Remove from parent
    if element._pseudo then
        element._pseudo.Parent = nil
    end
    
    -- Remove from allDrawings table
    for i = #allDrawings, 1, -1 do
        if allDrawings[i] == element then
            table.remove(allDrawings, i)
            break
        end
    end
    
    -- Remove the actual drawing
    if element._real and element._real.Remove then
        element._real:Remove()
    end
    
    -- Trigger parent layout update if needed
    if element._pseudo and element._pseudo.Parent then
        local parent = element._pseudo.Parent
        if parent._listLayout then
            task.defer(function()
                parent._listLayout:Update()
            end)
        end
    end
end


local UIListLayout = {}
UIListLayout.__index = UIListLayout

function UIListLayout.new(properties)
    local self = setmetatable({
        FillDirection = properties.FillDirection or "Vertical", -- "Vertical" or "Horizontal"
        HorizontalAlignment = properties.HorizontalAlignment or "Left", -- "Left", "Center", "Right"
        VerticalAlignment = properties.VerticalAlignment or "Top", -- "Top", "Center", "Bottom"
        SortOrder = properties.SortOrder or "LayoutOrder", -- "LayoutOrder" or "Name"
        -- Padding now supports: number, UDim {Scale=0, Offset=5}, or UDim2-style
        Padding = properties.Padding or 0,
        AbsoluteContentSize = Vector2.new(0, 0);
        Parent = properties.Parent,
        _children = {},
        _enabled = true}, UIListLayout)
    
    if self.Parent then
        self.Parent._listLayout = self
        -- Initial layout update
        task.defer(function()
            self:Update()
        end)
    end
    
    return self
end

function UIListLayout:Update()
    if not self._enabled or not self.Parent then return end
    
    local children = self:GetSortedChildren()
    local parentSize = GetActualSize(self.Parent)
    local parentPos = GetActualPosition(self.Parent)
    
    -- Get padding info from UIPadding if it exists
    local paddingInfo = self.Parent._paddingInfo or {Left = 0, Right = 0, Top = 0, Bottom = 0}
    
    -- Start position accounts for UIPadding
    local currentOffset = 0
    
    for i, child in ipairs(children) do
        local childVisible = child._pseudo.Visible
        if childVisible == nil then childVisible = true end
        
        if childVisible then
            local childSize = GetActualSize(child)
            
            if self.FillDirection == "Vertical" then
                -- Vertical layout
                local xPos = paddingInfo.Left -- Start with left padding
                
                -- Calculate available width for alignment (accounting for padding)
                local availableWidth = parentSize.X - paddingInfo.Left - paddingInfo.Right
                
                -- Horizontal alignment
                if self.HorizontalAlignment == "Center" then
                    xPos = paddingInfo.Left + (availableWidth - childSize.X) / 2
                elseif self.HorizontalAlignment == "Right" then
                    xPos = parentSize.X - paddingInfo.Right - childSize.X
                end
                
                -- Apply top padding on first item
                local yPos = currentOffset + (i == 1 and paddingInfo.Top or 0)
                
                -- Set position
                if child.UDimPosition or child._pseudo.UDimPosition then
                    child.UDimPosition = UDim2.fromOffset(xPos, yPos)
                    child:UpdateLayout()
                else
                    child._real.Position = Vector2.new(
                        parentPos.X + xPos,
                        parentPos.Y + yPos
                    )
                end
                
                -- Increment offset
                currentOffset = yPos + childSize.Y
                
                -- Add padding between items (supports UDim format)
                if i < #children then
                    local paddingValue = UDimPaddingToPixels(self.Padding, parentSize.Y)
                    currentOffset = currentOffset + paddingValue
                end
                
            else
                -- Horizontal layout
                local yPos = paddingInfo.Top -- Start with top padding
                
                -- Calculate available height for alignment (accounting for padding)
                local availableHeight = parentSize.Y - paddingInfo.Top - paddingInfo.Bottom
                
                -- Vertical alignment
                if self.VerticalAlignment == "Center" then
                    yPos = paddingInfo.Top + (availableHeight - childSize.Y) / 2
                elseif self.VerticalAlignment == "Bottom" then
                    yPos = parentSize.Y - paddingInfo.Bottom - childSize.Y
                end
                
                -- Apply left padding on first item
                local xPos = currentOffset + (i == 1 and paddingInfo.Left or 0)
                
                -- Set position
                if child.UDimPosition or child._pseudo.UDimPosition then
                    child.UDimPosition = UDim2.fromOffset(xPos, yPos)
                    child:UpdateLayout()
                else
                    child._real.Position = Vector2.new(
                        parentPos.X + xPos,
                        parentPos.Y + yPos
                    )
                end
                
                -- Increment offset
                currentOffset = xPos + childSize.X
                
                -- Add padding between items (supports UDim format)
                if i < #children then
                    local paddingValue = UDimPaddingToPixels(self.Padding, parentSize.X)
                    currentOffset = currentOffset + paddingValue
                end
            end
        end
    end

    -- Compute AbsoluteContentSize
    local totalWidth, totalHeight = 0, 0
    local visibleCount = 0

    for _, child in ipairs(children) do
        local childVisible = child._pseudo.Visible
        if childVisible == nil then childVisible = true end

        if childVisible then
            local size = GetActualSize(child)
            visibleCount = visibleCount + 1

            if self.FillDirection == "Vertical" then
                totalHeight = totalHeight + size.Y
                if visibleCount < #children then
                    totalHeight = totalHeight + UDimPaddingToPixels(self.Padding, parentSize.Y)
                end
                totalWidth = math.max(totalWidth, size.X)
            else
                totalWidth = totalWidth + size.X
                if visibleCount < #children then
                    totalWidth = totalWidth + UDimPaddingToPixels(self.Padding, parentSize.X)
                end
                totalHeight = math.max(totalHeight, size.Y)
            end
    end
end

-- Include UIPadding
totalWidth = totalWidth + paddingInfo.Left + paddingInfo.Right
totalHeight = totalHeight + paddingInfo.Top + paddingInfo.Bottom

self.AbsoluteContentSize = Vector2.new(totalWidth, totalHeight)

end

-- Add IsA method to UIListLayout
function UIListLayout:IsA(className)
    return className == "UIListLayout"
end

function UIListLayout:Destroy()
    if self.Parent then
        self.Parent._listLayout = nil
    end
    self.Parent = nil
    self._enabled = false
end

function UIListLayout:GetSortedChildren()
    local children = {}
    
    -- Collect all children from the parent
    for _, child in ipairs(allDrawings) do
        if child._pseudo and child._pseudo.Parent == self.Parent then
            table.insert(children, child)
        end
    end
    
    -- Sort children
    if self.SortOrder == "LayoutOrder" then
        table.sort(children, function(a, b)
            local orderA = (a._pseudo and a._pseudo.LayoutOrder) or 0
            local orderB = (b._pseudo and b._pseudo.LayoutOrder) or 0
            return orderA < orderB
        end)
    elseif self.SortOrder == "Name" then
        table.sort(children, function(a, b)
            local nameA = (a._pseudo and a._pseudo.Name) or ""
            local nameB = (b._pseudo and b._pseudo.Name) or ""
            return nameA < nameB
        end)
    end
    
    return children
end

function UIListLayout:SetEnabled(enabled)
    self._enabled = enabled
    if enabled then
        self:Update()
    end
end

-- Helper function to convert UDim to actual pixel value
local function UDimToPixels(udim, parentSize)
    if type(udim) == "number" then
        return udim
    elseif type(udim) == "table" then
        -- Support for UDim format: {Scale = 0, Offset = 0}
        if udim.Scale and udim.Offset then
            return (udim.Scale * parentSize) + udim.Offset
        end
    end
    return 0
end

-- Helper function to convert UDim2 Padding to pixel values
-- Supports: UDim.new(0, 5) format from Roblox
local function UDimPaddingToPixels(padding, parentSize)
    if type(padding) == "number" then
        return padding
    elseif type(padding) == "table" then
        -- If it's a UDim {Scale = 0, Offset = 5}
        if padding.Scale ~= nil and padding.Offset ~= nil then
            return (padding.Scale * parentSize) + padding.Offset
        end
    end
    return 0
end

-- UIPadding Implementation
local UIPadding = {}
UIPadding.__index = UIPadding

function UIPadding.new(properties)
    local self = setmetatable({
        -- Accept both UDim format and raw numbers
        PaddingLeft = properties.PaddingLeft or properties.Left or 0,
        PaddingRight = properties.PaddingRight or properties.Right or 0,
        PaddingTop = properties.PaddingTop or properties.Top or 0,
        PaddingBottom = properties.PaddingBottom or properties.Bottom or 0,
        Parent = properties.Parent
    }, UIPadding)
    
    if self.Parent then
        self.Parent._padding = self
        -- Store original size for recalculations
        self.Parent._originalSize = GetActualSize(self.Parent)
        -- Apply padding to all existing children
        task.defer(function()
            self:Apply()
        end)
    end
    
    return self
end

function UIPadding:Apply()
    if not self.Parent then return end
    
    local parentSize = GetActualSize(self.Parent)
    local parentPos = GetActualPosition(self.Parent)
    
    -- Get padding values using UDim conversion
    local paddingLeft = UDimToPixels(self.PaddingLeft, parentSize.X)
    local paddingRight = UDimToPixels(self.PaddingRight, parentSize.X)
    local paddingTop = UDimToPixels(self.PaddingTop, parentSize.Y)
    local paddingBottom = UDimToPixels(self.PaddingBottom, parentSize.Y)
    
    -- Store padding info for UIListLayout to use
    self.Parent._paddingInfo = {
        Left = paddingLeft,
        Right = paddingRight,
        Top = paddingTop,
        Bottom = paddingBottom
    }
    
    -- If parent has a UIListLayout, trigger it to update with new padding
    if self.Parent._listLayout then
        self.Parent._listLayout:Update()
    else
        -- Apply padding offset to all children manually if no list layout
        for _, child in ipairs(allDrawings) do
            if child._pseudo and child._pseudo.Parent == self.Parent then
                if child._listLayout or child._padding then
                    continue
                end
                
                local currentPos = child._real.Position or Vector2.new(0, 0)
                
                -- Calculate relative position
                local relativeX = currentPos.X - parentPos.X
                local relativeY = currentPos.Y - parentPos.Y
                
                -- Apply padding if this hasn't been done yet
                if not child._paddingApplied then
                    child._real.Position = Vector2.new(
                        parentPos.X + paddingLeft + relativeX,
                        parentPos.Y + paddingTop + relativeY
                    )
                    child._paddingApplied = true
                    
                    if child.UpdateLayout then
                        child:UpdateLayout()
                    end
                end
            end
        end
    end
end

function UIPadding:SetPadding(left, right, top, bottom)
    self.PaddingLeft = left or self.PaddingLeft
    self.PaddingRight = right or self.PaddingRight
    self.PaddingTop = top or self.PaddingTop
    self.PaddingBottom = bottom or self.PaddingBottom
    self:Apply()
end

-- Add IsA method to UIPadding
function UIPadding:IsA(className)
    return className == "UIPadding"
end

function UIPadding:Destroy()
    if self.Parent then
        self.Parent._padding = nil
        self.Parent._paddingInfo = nil
    end
    self.Parent = nil
end

drawing_constructor = setmetatable({}, {
    __index = function(_, className)
        if className == "UIListLayout" then
            return function(props)
                return UIListLayout.new(props)
            end
        elseif className == "UIPadding" then
            return function(props)
                return UIPadding.new(props)
            end
        else
            return function(props)
                return DrawingWrapper.new(className, props)
            end
        end
    end
})

task.spawn(function()
    while true do
        UpdateMouseStates()
        wait(0.01)
    end
end)


-- > uis 



function DrawingWrapper:GetChildren()
    return gui_GetChildren(self)
end

function DrawingWrapper:IsA(className)
    return gui_IsA(self, className)
end

function DrawingWrapper:Destroy()
    gui_Destroy(self)
end



local Enum = {}
local function CreateEnumCategory(name, items)
    local category = {}
    local reverse = {}
    for k, v in pairs(items) do
        category[k] = v
        reverse[v] = k
    end
    function category:GetNameFromValue(value)
        return reverse[value]
    end
    Enum[name] = category
end
CreateEnumCategory("KeyCode", {
    A = 0x41,
    B = 0x42,
    C = 0x43,
    D = 0x44,
    E = 0x45,
    F = 0x46,
    G = 0x47,
    H = 0x48,
    I = 0x49,
    J = 0x4A,
    K = 0x4B,
    L = 0x4C,
    M = 0x4D,
    N = 0x4E,
    O = 0x4F,
    P = 0x50,
    Q = 0x51,
    R = 0x52,
    S = 0x53,
    T = 0x54,
    U = 0x55,
    V = 0x56,
    W = 0x57,
    X = 0x58,
    Y = 0x59,
    Z = 0x5A,
    Zero = 0x30,
    One = 0x31,
    Two = 0x32,
    Three = 0x33,
    Four = 0x34,
    Five = 0x35,
    Six = 0x36,
    Seven = 0x37,
    Eight = 0x38,
    Nine = 0x39,
    F1 = 0x70,
    F2 = 0x71,
    F3 = 0x72,
    F4 = 0x73,
    F5 = 0x74,
    F6 = 0x75,
    F7 = 0x76,
    F8 = 0x77,
    F9 = 0x78,
    F10 = 0x79,
    F11 = 0x7A,
    F12 = 0x7B,
    Up = 0x26,
    Down = 0x28,
    Left = 0x25,
    Right = 0x27,
    Shift = 0x10,
    Control = 0x11,
    Alt = 0x12,
    Space = 0x20,
    Enter = 0x0D,
    Escape = 0x1B,
    Tab = 0x09,
    Backspace = 0x08;
    RightShift = 0xA1;
    RightControl = 0xA3;
})
CreateEnumCategory("UserInputType", {
    MouseButton1 = 0x01,
    MouseButton2 = 0x02,
    MouseButton3 = 0x04,
    MouseWheel = 0xFF01,
    MouseMove = 0xFF02,
    Keyboard = 0xFF03
})



local function MakeInputObject(keyCode, userInputType)
    return {
        KeyCode = keyCode,
        UserInputType = userInputType or Enum.UserInputType.Keyboard
    }
end

local UserInputService = {
    InputBegan = Signal(),
    InputEnded = Signal(),
    _keyStates = {},
    _keysToMonitor = {}
}

function UserInputService:RegisterMouseButton(mouseEnum)
    self._keysToMonitor[mouseEnum] = true
    self._keyStates[mouseEnum] = false
end

function UserInputService:RegisterKey(vk)
    self._keysToMonitor[vk] = true
    self._keyStates[vk] = false
end

function UserInputService:IsMouseButtonPressed(mouseEnum)
    return self._keyStates[mouseEnum] or false
end

function UserInputService:GetKeysPressed()
    local pressedKeys = {}
    for vk, pressed in pairs(self._keyStates) do
        if pressed then
            table.insert(pressedKeys, vk)
        end
    end
    return pressedKeys
end

function UserInputService:IsKeyDown(keycode)
    return self._keyStates[keycode] or false
end

function UserInputService:_Update()
    for vk in pairs(self._keysToMonitor) do
        local pressed

        if vk == Enum.UserInputType.MouseButton1 then
            pressed = ismouse1pressed()
        elseif vk == Enum.UserInputType.MouseButton2 then
            pressed = ismouse2pressed()
        elseif vk == Enum.UserInputType.MouseButton3 then
            pressed = iskeypressed(0x04)
        else
            pressed = iskeypressed(vk)
        end

        local wasPressed = self._keyStates[vk]

        if pressed and not wasPressed then
            self._keyStates[vk] = true
            local isMouseInput = vk == Enum.UserInputType.MouseButton1 or vk == Enum.UserInputType.MouseButton2 or vk ==
                                     Enum.UserInputType.MouseButton3 or vk == Enum.UserInputType.MouseWheel or vk ==
                                     Enum.UserInputType.MouseMove

            local inputType = isMouseInput and vk or Enum.UserInputType.Keyboard

            self.InputBegan:Fire(MakeInputObject(vk, inputType))

        elseif not pressed and wasPressed then
            self._keyStates[vk] = false
            local isMouseInput = vk == Enum.UserInputType.MouseButton1 or vk == Enum.UserInputType.MouseButton2 or vk ==
                                     Enum.UserInputType.MouseButton3 or vk == Enum.UserInputType.MouseWheel or vk ==
                                     Enum.UserInputType.MouseMove

            local inputType = isMouseInput and vk or Enum.UserInputType.Keyboard

            self.InputEnded:Fire(MakeInputObject(vk, inputType))
        end
    end
end
UserInputService:RegisterMouseButton(Enum.UserInputType.MouseButton1)
spawn(function()
    while true do
        UserInputService:_Update()
        wait(0.01)
    end
end)

-- > services 

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- > const

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local Toggles = {}
local Options = {}

_G.Toggles = Toggles
_G.Options = Options

local FocusedTextBox = nil

local function KeyCodeToChar(keyCode, isShiftPressed)
    local keyMap = {
        [Enum.KeyCode.A] = isShiftPressed and "A" or "a",
        [Enum.KeyCode.B] = isShiftPressed and "B" or "b",
        [Enum.KeyCode.C] = isShiftPressed and "C" or "c",
        [Enum.KeyCode.D] = isShiftPressed and "D" or "d",
        [Enum.KeyCode.E] = isShiftPressed and "E" or "e",
        [Enum.KeyCode.F] = isShiftPressed and "F" or "f",
        [Enum.KeyCode.G] = isShiftPressed and "G" or "g",
        [Enum.KeyCode.H] = isShiftPressed and "H" or "h",
        [Enum.KeyCode.I] = isShiftPressed and "I" or "i",
        [Enum.KeyCode.J] = isShiftPressed and "J" or "j",
        [Enum.KeyCode.K] = isShiftPressed and "K" or "k",
        [Enum.KeyCode.L] = isShiftPressed and "L" or "l",
        [Enum.KeyCode.M] = isShiftPressed and "M" or "m",
        [Enum.KeyCode.N] = isShiftPressed and "N" or "n",
        [Enum.KeyCode.O] = isShiftPressed and "O" or "o",
        [Enum.KeyCode.P] = isShiftPressed and "P" or "p",
        [Enum.KeyCode.Q] = isShiftPressed and "Q" or "q",
        [Enum.KeyCode.R] = isShiftPressed and "R" or "r",
        [Enum.KeyCode.S] = isShiftPressed and "S" or "s",
        [Enum.KeyCode.T] = isShiftPressed and "T" or "t",
        [Enum.KeyCode.U] = isShiftPressed and "U" or "u",
        [Enum.KeyCode.V] = isShiftPressed and "V" or "v",
        [Enum.KeyCode.W] = isShiftPressed and "W" or "w",
        [Enum.KeyCode.X] = isShiftPressed and "X" or "x",
        [Enum.KeyCode.Y] = isShiftPressed and "Y" or "y",
        [Enum.KeyCode.Z] = isShiftPressed and "Z" or "z",
        [Enum.KeyCode.Zero] = isShiftPressed and ")" or "0",
        [Enum.KeyCode.One] = isShiftPressed and "!" or "1",
        [Enum.KeyCode.Two] = isShiftPressed and "@" or "2",
        [Enum.KeyCode.Three] = isShiftPressed and "#" or "3",
        [Enum.KeyCode.Four] = isShiftPressed and "$" or "4",
        [Enum.KeyCode.Five] = isShiftPressed and "%" or "5",
        [Enum.KeyCode.Six] = isShiftPressed and "^" or "6",
        [Enum.KeyCode.Seven] = isShiftPressed and "&" or "7",
        [Enum.KeyCode.Eight] = isShiftPressed and "*" or "8",
        [Enum.KeyCode.Nine] = isShiftPressed and "(" or "9",
        [Enum.KeyCode.Space] = " "
    }

    return keyMap[keyCode]
end

-- > subhelpers

local function CreateConnection(stopFlag, index)
    return {
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            stopFlag[index] = true
        end
    }
end

for key, vk in pairs(Enum.KeyCode) do
    UserInputService:RegisterKey(vk)
end

-- > main 

local Library = {
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(30, 30, 30),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    AccentColor = Color3.fromRGB(0, 170, 255),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    RiskColor = Color3.fromRGB(255, 50, 50),
    HudRegistry = {};
    Registry = {};
    RegistryMap = {};

    Black = Color3.fromRGB(0, 0, 0),

    OpenedFrames = {},
    DependencyBoxes = {},

    Signals = {}
}

local function GetPlayersString()
    local Playerlist = Players:GetPlayers()
    for i = 1, #Playerlist do
        Playerlist[i] = Playerlist[i].Name
    end

    table.sort(Playerlist, function(str1, str2)
        return str1 < str2
    end);

    return Playerlist;
end

local function GetTeamsString()
    -- > we cant directly call teams:getteams, so we have to check each players .team value

    local TeamNames = {}
    for i, v in pairs(Players:GetPlayers()) do
        local team = v.Team
        if team and not table.find(TeamNames, team.Name) then
            table.insert(TeamNames, team.Name)
        end
    end

    table.sort(TeamNames, function(str1, str2)
        return str1 < str2
    end);

    return TeamNames;
end

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end

    if not Library.NotifyOnError then
        return f(...);
    end

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end

        return Library:Notify(event:sub(i + 1), 3);
    end
end

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end
end

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = drawing_constructor[Class]();
    end

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end

    return _Instance;
end

local CustomTextBox = {}
CustomTextBox.__index = CustomTextBox

function CustomTextBox.new(properties)
    local self = setmetatable({}, CustomTextBox)

    -- Text properties
    self.Text = properties.Text or ""
    self.PlaceholderText = properties.PlaceholderText or ""
    self.TextColor = properties.TextColor or Color3.new(1, 1, 1)
    self.PlaceholderColor = properties.PlaceholderColor or Color3.fromRGB(190, 190, 190)
    self.TextSize = properties.TextSize or Vector2.new(14, 14)

    -- Drawing object
    self.TextLabel = properties.Parent or error("TextBox needs a parent")
    self.Position = properties.Position or Vector2.new(0, 0)
    self.Size = properties.Size or Vector2.new(100, 20)
    self.ZIndex = properties.ZIndex or 7

    -- Focus properties
    self.IsFocused = false
    self.CursorPosition = 0
    self.CursorVisible = false

    -- Signals
    self.FocusLost = Signal()
    self.Focused = Signal()
    self.Changed = Signal()

    -- Create the actual text drawing
    self.DrawingText = Library:Create('Text', {
        Text = self.PlaceholderText,
        Color = self.PlaceholderColor,
        Size = self.TextSize.X,
        Outline = true,
        Center = false,
        Position = self.Position,
        ZIndex = self.ZIndex,
        Parent = self.TextLabel
    })

    -- Create cursor
    self.Cursor = Library:Create('Line', {
        From = Vector2.new(0, 0),
        To = Vector2.new(0, 0),
        Color = Color3.new(1, 1, 1),
        Thickness = 1,
        Visible = false,
        ZIndex = self.ZIndex + 1
    })

    -- Setup click detection for focus
    self:SetupFocusDetection()

    -- Setup cursor blink
    self:SetupCursorBlink()

    return self
end

function CustomTextBox:SetupFocusDetection()
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouseX, mouseY = Mouse.X, Mouse.Y
            local pos = self.Position
            local size = self.Size

            -- Check if click is within textbox bounds
            if mouseX >= pos.X and mouseX <= pos.X + size.X and mouseY >= pos.Y and mouseY <= pos.Y + size.Y then
                self:Focus()
            else
                if self.IsFocused then
                    self:Unfocus(false)
                end
            end
        end
    end)
end

function CustomTextBox:SetupCursorBlink()
    spawn(function()
        while true do
            if self.IsFocused then
                self.CursorVisible = not self.CursorVisible
                self.Cursor.Visible = self.CursorVisible
            end
            wait(0.5)
        end
    end)
end

function CustomTextBox:Focus()
    if self.IsFocused then
        return
    end

    -- Unfocus previous textbox
    if FocusedTextBox and FocusedTextBox ~= self then
        FocusedTextBox:Unfocus(false)
    end

    self.IsFocused = true
    FocusedTextBox = self

    -- Update text display
    if self.Text == "" then
        self.DrawingText.Text = ""
    else
        self.DrawingText.Text = self.Text
    end
    self.DrawingText.Color = self.TextColor

    self.CursorPosition = #self.Text
    self:UpdateCursor()
    self.Cursor.Visible = true

    self.Focused:Fire()
end

function CustomTextBox:Unfocus(enterPressed)
    if not self.IsFocused then
        return
    end

    self.IsFocused = false
    FocusedTextBox = nil

    self.Cursor.Visible = false

    -- Show placeholder if empty
    if self.Text == "" then
        self.DrawingText.Text = self.PlaceholderText
        self.DrawingText.Color = self.PlaceholderColor
    end

    self.FocusLost:Fire(enterPressed or false)
end

function CustomTextBox:UpdateCursor()
    -- Calculate cursor position based on text width
    local textBeforeCursor = self.Text:sub(1, self.CursorPosition)
    local textWidth = self.DrawingText.TextBounds.X

    -- Estimate cursor position (simple calculation)
    local charWidth = textWidth / math.max(1, #self.Text)
    local cursorX = self.Position.X + (charWidth * self.CursorPosition) + 2

    self.Cursor.From = Vector2.new(cursorX, self.Position.Y + 2)
    self.Cursor.To = Vector2.new(cursorX, self.Position.Y + self.Size.Y - 2)
end

function CustomTextBox:AddCharacter(char)
    if not self.IsFocused then
        return
    end

    -- Insert character at cursor position
    local before = self.Text:sub(1, self.CursorPosition)
    local after = self.Text:sub(self.CursorPosition + 1)

    self.Text = before .. char .. after
    self.CursorPosition = self.CursorPosition + 1

    self:UpdateDisplay()
    self.Changed:Fire(self.Text)
end

function CustomTextBox:RemoveCharacter()
    if not self.IsFocused or self.CursorPosition == 0 then
        return
    end

    local before = self.Text:sub(1, self.CursorPosition - 1)
    local after = self.Text:sub(self.CursorPosition + 1)

    self.Text = before .. after
    self.CursorPosition = self.CursorPosition - 1

    self:UpdateDisplay()
    self.Changed:Fire(self.Text)
end

function CustomTextBox:UpdateDisplay()
    self.DrawingText.Text = self.Text
    self:UpdateCursor()
end

function CustomTextBox:MoveCursorLeft()
    if self.CursorPosition > 0 then
        self.CursorPosition = self.CursorPosition - 1
        self:UpdateCursor()
    end
end

function CustomTextBox:MoveCursorRight()
    if self.CursorPosition < #self.Text then
        self.CursorPosition = self.CursorPosition + 1
        self:UpdateCursor()
    end
end

UserInputService.InputBegan:Connect(function(input)
    if not FocusedTextBox then
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        local keyCode = input.KeyCode
        local isShiftPressed = UserInputService:IsKeyDown(Enum.KeyCode.Shift)

        if keyCode == Enum.KeyCode.Enter then
            FocusedTextBox:Unfocus(true)
        elseif keyCode == Enum.KeyCode.Backspace then
            FocusedTextBox:RemoveCharacter()
        elseif keyCode == Enum.KeyCode.Left then
            FocusedTextBox:MoveCursorLeft()
        elseif keyCode == Enum.KeyCode.Right then
            FocusedTextBox:MoveCursorRight()
        elseif keyCode == Enum.KeyCode.Escape then
            FocusedTextBox:Unfocus(false)
        else
            local char = KeyCodeToChar(keyCode, isShiftPressed)
            if char then
                FocusedTextBox:AddCharacter(char)
            end
        end
    end
end)

local ScrollingFrame = {}
ScrollingFrame.__index = ScrollingFrame

function ScrollingFrame.new(properties)
    local self = setmetatable({}, ScrollingFrame)

    -- Frame properties
    self.Position = properties.Position or Vector2.new(0, 0)
    self.Size = properties.Size or Vector2.new(200, 300)
    self.Parent = properties.Parent
    self.ZIndex = properties.ZIndex or 5

    -- Scrolling properties
    self.CanvasSize = properties.CanvasSize or Vector2.new(0, 500) -- Content height
    self.ScrollOffset = 0
    self.MaxScroll = math.max(0, self.CanvasSize.Y - self.Size.Y)
    self.ScrollSpeed = properties.ScrollSpeed or 20

    -- Scrollbar properties
    self.ScrollBarThickness = properties.ScrollBarThickness or 4
    self.ScrollBarColor = properties.ScrollBarColor or Color3.fromRGB(0, 170, 255)

    -- Create container frame
    self.Container = Library:Create('Square', {
        Color = properties.BackgroundColor or Library.MainColor,
        Size = UDim2.fromOffset(self.Size.X, self.Size.Y),
        Position = UDim2.fromOffset(self.Position.X, self.Position.Y),
        ZIndex = self.ZIndex,
        Parent = self.Parent,
        Filled = true
    })

    -- Create clipping mask (outline to hide overflow)
    self.ClipMask = Library:Create('Square', {
        Color = properties.BorderColor or Library.OutlineColor,
        Size = UDim2.fromOffset(self.Size.X, self.Size.Y),
        Position = UDim2.fromOffset(self.Position.X, self.Position.Y),
        ZIndex = self.ZIndex - 1,
        Parent = self.Parent,
        Filled = false,
        Thickness = 1
    })

    -- Create content container (this will move when scrolling)
    self.ContentFrame = Library:Create('Square', {
        Transparency = 1,
        Size = UDim2.fromOffset(self.Size.X, self.CanvasSize.Y),
        Position = UDim2.fromOffset(self.Position.X, self.Position.Y),
        ZIndex = self.ZIndex + 1,
        Parent = self.Parent
    })

    -- Create scrollbar background
    self.ScrollBarBg = Library:Create('Square', {
        Color = Color3.fromRGB(40, 40, 40),
        Size = UDim2.fromOffset(self.ScrollBarThickness, self.Size.Y),
        Position = UDim2.fromOffset(self.Position.X + self.Size.X - self.ScrollBarThickness, self.Position.Y),
        ZIndex = self.ZIndex + 2,
        Parent = self.Parent,
        Filled = true
    })

    -- Create scrollbar thumb
    local thumbHeight = math.max(20, (self.Size.Y / self.CanvasSize.Y) * self.Size.Y)
    self.ScrollBarThumb = Library:Create('Square', {
        Color = self.ScrollBarColor,
        Size = UDim2.fromOffset(self.ScrollBarThickness, thumbHeight),
        Position = UDim2.fromOffset(self.Position.X + self.Size.X - self.ScrollBarThickness, self.Position.Y),
        ZIndex = self.ZIndex + 3,
        Parent = self.Parent,
        Filled = true
    })

    -- Store children for clipping
    self.Children = {}

    -- Setup scrolling input
    self:SetupScrolling()

    -- Setup scrollbar dragging
    self:SetupScrollbarDrag()

    return self
end

function ScrollingFrame:SetupScrolling()
    -- Register mouse wheel for scrolling
    UserInputService:RegisterKey(Enum.UserInputType.MouseWheel)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            -- Check if mouse is over the scrolling frame
            if self:IsMouseOver() then
                -- Note: You'll need to detect scroll direction
                -- This is a simplified version - you may need to use
                -- a different method to detect wheel delta
                self:Scroll(-self.ScrollSpeed)
            end
        end
    end)
end

function ScrollingFrame:SetupScrollbarDrag()
    local dragging = false
    local dragStart = 0
    local scrollStart = 0

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = Vector2.new(Mouse.X, Mouse.Y)
            local thumbPos = self.ScrollBarThumb.Position
            local thumbSize = self.ScrollBarThumb.Size

            -- Check if clicking on scrollbar thumb
            if mousePos.X >= thumbPos.X.Offset and mousePos.X <= thumbPos.X.Offset + thumbSize.X.Offset and mousePos.Y >=
                thumbPos.Y.Offset and mousePos.Y <= thumbPos.Y.Offset + thumbSize.Y.Offset then
                dragging = true
                dragStart = mousePos.Y
                scrollStart = self.ScrollOffset
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Update loop for dragging
    spawn(function()
        while true do
            if dragging then
                local mouseY = Mouse.Y
                local delta = mouseY - dragStart
                local scrollPercent = delta / (self.Size.Y - self.ScrollBarThumb.Size.Y.Offset)
                local newScroll = scrollStart + (scrollPercent * self.MaxScroll)
                self:SetScroll(newScroll)
            end
            wait(0.01)
        end
    end)
end

function ScrollingFrame:IsMouseOver()
    local mouseX, mouseY = Mouse.X, Mouse.Y
    local pos = self.Container.Position
    local size = self.Container.Size

    return mouseX >= pos.X.Offset and mouseX <= pos.X.Offset + size.X.Offset and mouseY >= pos.Y.Offset and mouseY <=
               pos.Y.Offset + size.Y.Offset
end

function ScrollingFrame:Scroll(delta)
    self:SetScroll(self.ScrollOffset + delta)
end

function ScrollingFrame:SetScroll(offset)
    -- Clamp scroll offset
    self.ScrollOffset = math.clamp(offset, 0, self.MaxScroll)

    -- Update content position
    self.ContentFrame.Position = UDim2.fromOffset(self.Position.X, self.Position.Y - self.ScrollOffset)

    -- Update all children positions
    for _, child in ipairs(self.Children) do
        if child.UpdateScrollPosition then
            child:UpdateScrollPosition(self.ScrollOffset)
        end
    end

    -- Update scrollbar thumb position
    if self.MaxScroll > 0 then
        local scrollPercent = self.ScrollOffset / self.MaxScroll
        local maxThumbY = self.Size.Y - self.ScrollBarThumb.Size.Y.Offset
        local thumbY = self.Position.Y + (scrollPercent * maxThumbY)

        self.ScrollBarThumb.Position = UDim2.fromOffset(self.Position.X + self.Size.X - self.ScrollBarThickness, thumbY)
    end

    -- Update visibility of children (culling)
    self:UpdateChildVisibility()
end

function ScrollingFrame:UpdateChildVisibility()
    -- Hide children that are outside the visible area
    for _, child in ipairs(self.Children) do
        if child.Element and child.OriginalY then
            local childY = child.OriginalY - self.ScrollOffset
            local visible = childY + child.Height > 0 and childY < self.Size.Y

            child.Element.Visible = visible
        end
    end
end

function ScrollingFrame:AddChild(element, yOffset, height)
    -- Store child info for clipping/culling
    table.insert(self.Children, {
        Element = element,
        OriginalY = yOffset,
        Height = height or 20,
        UpdateScrollPosition = function(self, scroll)
            -- Update element position based on scroll
            if element.Position then
                element.Position = UDim2.fromOffset(element.Position.X.Offset, self.OriginalY - scroll)
            end
        end
    })

    element.Parent = self.ContentFrame
end

function ScrollingFrame:SetCanvasSize(newSize)
    self.CanvasSize = newSize
    self.MaxScroll = math.max(0, self.CanvasSize.Y - self.Size.Y)
    self.ContentFrame.Size = UDim2.fromOffset(self.Size.X, self.CanvasSize.Y)

    -- Update scrollbar thumb size
    local thumbHeight = math.max(20, (self.Size.Y / self.CanvasSize.Y) * self.Size.Y)
    self.ScrollBarThumb.Size = UDim2.fromOffset(self.ScrollBarThickness, thumbHeight)

    -- Hide scrollbar if not needed
    local needsScrollbar = self.CanvasSize.Y > self.Size.Y
    self.ScrollBarBg.Visible = needsScrollbar
    self.ScrollBarThumb.Visible = needsScrollbar

    self:SetScroll(self.ScrollOffset) -- Refresh
end

function ScrollingFrame:Destroy()
    self.Container:Remove()
    self.ClipMask:Remove()
    self.ContentFrame:Remove()
    self.ScrollBarBg:Remove()
    self.ScrollBarThumb:Remove()
end

function Library:ApplyTextStroke(Inst)
    Inst.Outline = true;
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('Text', {
        TextColor = Library.FontColor,
        TextSize = 16,
        Center = true
    });

    Library:ApplyTextStroke(_Instance);

    return Library:Create(_Instance, Properties);
end

function Library:MakeDraggable(Instance, Cutoff)

    UserInputService.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- > if mouse isnt overlapping the instance area then exit >
            if Instance:IsMouseOver() ~= true then
                return
            end

            -- > only continue if its overlapping and clicked

            local ObjPos = Vector2.new(Mouse.X - Instance.Position.X, Mouse.Y - Instance.Position.Y);

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end

            while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2(0, Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0, Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y));

                task.wait(.1);
            end
        end
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local tooltipSquare = Library:Create('Square', {
        Color = Library.MainColor,
        Thickness = 1,
        Filled = true,
        Visible = false,
        ZIndex = 100
    })

    local tooltipBorder = Library:Create('Square', {
        Color = Library.OutlineColor,
        Thickness = 1,
        Filled = false,
        Visible = false,
        ZIndex = 99
    })

    local tooltipText = Library:Create('Text', {
        Text = InfoStr,
        Color = Library.FontColor,
        Size = 14,
        Outline = true,
        Visible = false,
        ZIndex = 101
    })

    local width = tooltipText.TextBounds.X + 10
    local height = 20

    local stopFlag = {false}
    local updateConnection = nil

    local function UpdateTooltipPosition()
        local x, y = Mouse.X + 15, Mouse.Y + 12

        tooltipSquare.Size = Vector2.new(width, height)
        tooltipSquare.Position = Vector2.new(x, y)

        tooltipBorder.Size = Vector2.new(width, height)
        tooltipBorder.Position = Vector2.new(x, y)

        tooltipText.Position = Vector2.new(x + 5, y + 4)
    end

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        tooltipSquare.Visible = true
        tooltipBorder.Visible = true
        tooltipText.Visible = true

        UpdateTooltipPosition()

        stopFlag[1] = false
        spawn(function()
            while not stopFlag[1] do
                UpdateTooltipPosition()
                wait(0.01)
            end
        end)
    end)

    HoverInstance.MouseLeave:Connect(function()
        stopFlag[1] = true
        tooltipSquare.Visible = false
        tooltipBorder.Visible = false
        tooltipText.Visible = false
    end)
end

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        if Frame:IsMouseOver() then
            return true
        end
    end
    return false
end

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.Position, Frame.Size;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y +
        AbsSize.Y then

        return true;
    end
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
        end
    end)

    HighlightInstance.MouseLeave:Connect(function()
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
        end
    end)
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = Text.TextBounds
    return Bounds.X, Bounds.Y
end

local function color3fromHSV(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6

    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end

    return {r * 255, g * 255, b * 255}
end

local function color3toHSV(r, g, b)
    -- normalize 0–255 range to 0–1
    r = r / 255
    g = g / 255
    b = b / 255

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min

    local h, s, v

    -- hue
    if delta == 0 then
        h = 0
    elseif max == r then
        h = ((g - b) / delta) % 6
    elseif max == g then
        h = ((b - r) / delta) + 2
    elseif max == b then
        h = ((r - g) / delta) + 4
    end
    h = h / 6

    -- saturation
    if max == 0 then
        s = 0
    else
        s = delta / max
    end

    -- value (brightness)
    v = max

    return h, s, v
end


function Library:GetDarkerColor(Color)
    local H, S, V = color3toHSV(Library.AccentColor.R, Library.AccentColor.G, Library.AccentColor.G);
    return color3fromHSV(H, S, V / 1.5);
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance,
        Properties = Properties,
        Idx = Idx
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end
        end

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end
        end

        Library.RegistryMap[Instance] = nil;
    end
end

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

local BaseAddons = {};

do
    local Funcs = {}
    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...)
    end;
end

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Square', {
            Transparency = 1,
            Size = UDim2(1, 0, 0, Size),
            ZIndex = 1,
            Parent = Container
        });
    end

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local GroupBox = self;
        local Container = GroupBox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2(1, -4, 0, 15),
            TextSize = Vector2.new(14, 14),
            Text = Text,
            -- > textwrap would go here, but its nil in matcha
            Center = false,
            ZIndex = 5,
            Parent = Container
        });

        local Y = select(2, Library:GetTextBounds(TextLabel))
        TextLabel.Size = UDim2(1, -4, 0, Y);

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text;
            local Y = select(2, Library:GetTextBounds(TextLabel))
            TextLabel.Size = UDim2(1, -4, 0, Y);

            GroupBox:Resize();
        end

        setmetatable(Label, BaseAddons)

        GroupBox:AddBlank(5)
        GroupBox:Resize();

        return Label
    end

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local props = select(1, ...)
            if type(props) == 'table' then
                Obj.Text = props.Text or "ButtonTestTextHi"
                Obj.Func = props.Func or function()
                    print("No Function Set")
                end

                Obj.DoubleClick = props.DoubleClick or false
                Obj.Tooltip = props.Tooltip or nil
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local GroupBox = self;
        local Container = GroupBox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Square', {
                Color = Color3.new(0, 0, 0),
                Size = UDim2(1, -4, 0, 20),
                ZIndex = 5
            });

            local Inner = Library:Create('Square', {
                Color = GroupBox.Parent.MainColor,
                BorderColor3 = Library.OutlineColor;
                BorderMode = 'Inset';
                Size = UDim2(1, 0, 1, 0),
                ZIndex = 6,
                Parent = Outer
            });

            -- > create outline square behind the inner square
         

            local Label = Library:CreateLabel({
                Size = UDim2(1, 0, 1, 0),
                TextSize = Vector2.new(14, 14),
                Text = Button.Text,
                ZIndex = 6,
                Parent = Inner
            });

            -- > no ui gradient sadly

            Library:AddToRegistry(Outer, {
                BorderColor3 = Outline.Color,
            })

            Library:AddToRegistry(Inner, {
                Color = 'MainColor',
                BorderColor3 = 'OutlineColor',
            })

            Library:OnHighlight(Outer, Outer, {
                BorderColor3 = 'AccentColor'
            }, {
                BorderColor3 = 'Black'
            });

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Signal()
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)

                task.delay(timeout, function()
                    connection:Disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            UserInputService.InputBegan:Connect(function(input)
                -- > check if mouse is hovering over Outer
                if not Outer:IsMouseOver() then
                    return
                end

                if not ValidateClick(input) then
                    return
                end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, {
                        TextColor = 'AccentColor'
                    })

                    Button.Label.TextColor = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'

                    local clicked = WaitForEvent(UserInputService.InputBegan, 0.5, function(input)
                        return Outer:IsMouseOver() and ValidateClick(input)
                    end)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, {
                        TextColor = 'FontColor'
                    })

                    Button.Label.TextColor = Library.FontColor
                    Button.Label.Text = Button.Text
                    -- > no locked prop of gui: task.defer(rawset, Button, 'Locked', false)
                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func)
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self;
        end

        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.Size.X - 2, self.Outer.Size.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        GroupBox:AddBlank(5);
        GroupBox:Resize()

        return Button

    end

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container;

        local Divider = {
            Type = "Divider"
        }

        Groupbox:AddBlank(2)
        local DividerOuter = Library:Create('Square', {
            Color = Color3.new(0, 0, 0),
            Size = UDim2(1, -4, 0, 5),
            ZIndex = 5,
            Parent = Container
        });

        local DividerInner = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 0, 1, 0),
            ZIndex = 6,
            Parent = DividerOuter
        })

        -- > create outline for divider inner
        local DividerInnerOutline = Library:Create('Square', {
            Color = Library.OutlineColor,
            Size = UDim2(1, 2, 1, 2),
            Position = UDim2(0, -1, 0, -1),
            ZIndex = 4,
            Parent = DividerInner
        })

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black'
        });

        Library:AddToRegistry(DividerInner, {
            Color = 'MainColor',
            BorderColor3 = 'OutlineColor'
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(idx, info)
        assert(info.Text, 'AddInput: missing `Text` string.')

        local Textbox = {
            Value = info.Default or '',
            Numeric = info.Numeric or false,
            Finished = info.Finished or false,
            Type = 'Input',
            Callback = info.Callback or function(value)
            end
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:Create({
            Size = UDim2(1, 0, 0, 15),
            TextSize = Vector2.new(14, 14),
            Text = info.Text,
            Center = false,
            ZIndex = 5,
            Parent = Container
        });

        Groupbox:AddBlank(1)

        local TextboxOuter = Library:Create('Square', {
            Color = Color3.new(0, 0, 0),
            Size = UDim2(1, -4, 0, 20),
            ZIndex = 5,
            Parent = Container
        });

        local TextBoxInner = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 0, 1, 0),
            ZIndex = 6,
            Parent = TextboxOuter
        });

        -- > create.. another fucking outline. I really should of made a helper function for this :(

        local TextBoxInnerOutline = Library:Create('Square', {
            Color = Library.OutlineColor,
            Size = UDim2(1, 2, 1, 2),
            Position = UDim2(0, -1, 0, -1),
            Parent = TextBoxInner,
            ZIndex = 4
        });

        Library:AddToRegistry(TextBoxInner, {
            Color = 'MainColor',
            BorderColor3 = 'OutlineColor'
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter, {
            BorderColor3 = 'AccentColor'
        }, {
            BorderColor3 = 'Black'
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        -- > no ui gradient.. so cant do the following
        --[[
             Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });]]

        local Container = Library:Create('Frame', {
            Transparency = 1,
            Position = UDim2(0, 5, 0, 0),
            Size = UDim2(1, -5, 1, 0),
            ZIndex = 7,
            Parent = TextBoxInner
        });

        local CustomBox = CustomTextBox.new({
            Text = info.Default or '',
            PlaceholderText = info.Placeholder or '',
            TextColor = Library.FontColor,
            Position = Vector2.new(TextBoxInner.Position.X + 5, TextBoxInner.Position.Y + 3),
            Size = Vector2.new(TextBoxInner.Size.X - 10, TextBoxInner.Size.Y),
            TextSize = Vector2.new(14, 14),
            ZIndex = 7,
            Parent = TextBoxInner
        })

        Library:ApplyTextStroke(CustomBox);

        function Textbox:SetValue(text)
            if info.MaxLength and #Text > info.MaxLength then
                text = text:sub(1, info.MaxLength)
            end

            if Textbox.Numeric then
                if (not tonumber(text)) and text:len() > 0 then
                    text = Textbox.Value
                end
            end

            Textbox.Value = text
            CustomBox.Text = text
            CustomBox:UpdateDisplay()

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end

        if Textbox.Finished then
            CustomBox.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    Textbox:SetValue(CustomBox.Text)
                    Library:AttemptSave()
                end
            end)
        else
            CustomBox.Changed:Connect(function(text)
                Textbox:SetValue(text)
                Library:AttemptSave()
            end)
        end

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func
            Func(Textbox.Value)
        end

        Groupbox:AddBlank(5)
        Groupbox:Resize()

        Options[idx] = Textbox

        return Textbox
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false,
            Type = 'Toggle',

            Callback = Info.Callback or function(Value)
            end,
            Addons = {},
            Risky = Info.Risky
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Square', {
            Color = Color3.new(0, 0, 0),
            Size = UDim2(0, 13, 0, 13),
            ZIndex = 5,
            Parent = Container
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black'
        });

        local ToggleInner = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 0, 1, 0),
            ZIndex = 6,
            Parent = ToggleOuter
        });

        local ToggleInnerOutline = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 2, 1, 2),
            Position = UDim2(0, -1, 0, -1),
            ZIndex = 4,
            Parent = ToggleInner
        });

        Library:AddToRegistry(ToggleInner, {
            Color = 'MainColor',
            BorderColor3 = 'OutlineColor'
        });

        Library:AddToRegistry(ToggleInnerOutline, {
            Color = 'OutlineColor'
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2(0, 216, 1, 0),
            Position = UDim2(1, 6, 0, 0),
            TextSize = Vector2(14, 14),
            Center = false,
            Text = Info.Text,
            ZIndex = 6,
            Parent = ToggleInner
        });

        -- > cant use uiListLayout


        local listLayout = drawing_constructor.UIListLayout({
            Parent = ToggleLabel,
            FillDirection = 'Horizontal';
            HorizontalAlignment = 'Right';
            SortOrder = 'LayoutOrder';
            Padding = {Scale = 0, Offset = 4}
        })

        --[[
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });]]

        local ToggleRegion = Library:Create('Square', {
            Transparency = 1,
            Size = UDim2(0, 170, 1, 0),
            ZIndex = 8,
            Parent = ToggleOuter
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter, {
            BorderColor3 = 'AccentColor'
        }, {
            BorderColor3 = 'Black'
        });

        function Toggle:UpdateColors()
            Toggle:Display();
        end

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            ToggleInner.Color = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInnerOutline.Color = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.Color = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInnerOutline].Properties.Color =
                Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end

        --[[ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);]]

        UserInputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ToggleRegion:IsMouseOver() == true and
                not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, {
                TextColor = 'RiskColor'
            });
        end

        Toggle:Display()
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;

    end

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default,
            Min = Info.Min,
            Max = Info.Max,
            Rounding = Info.Rounding,
            MaxSize = 232,
            Type = 'Slider',
            Callback = Info.Callback or function(Value)
            end
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2(1, 0, 0, 10),
                TextSize = Vector2.new(14, 14),
                Text = Info.Text,
                Center = false,
                ZIndex = 5,
                Parent = Container
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Square', {
            Color = Color3.new(0, 0, 0),
            BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2(1, -4, 0, 13),
            ZIndex = 5,
            Parent = Container
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black'
        });

        local SliderInner = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 0, 1, 0),
            ZIndex = 6,
            Parent = SliderOuter
        });

        local SliderInnerOutline = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 2, 1, 2),
            Position = UDim2(0, -1, 0, -1),
            ZIndex = 4,
            Parent = SliderInner
        });

        Library:AddToRegistry(SliderInner, {
            Color = 'MainColor'
        });

        Library:AddToRegistry(SliderInnerOutline, {
            Color = 'OutlineColor'
        });

        local Fill = Library:Create('Square', {
            Color = Library.AccentColor,
            Size = UDim2(0, 0, 1, 0),
            ZIndex = 7,
            Parent = SliderInner
        });

        Library:AddToRegistry(Fill, {
            Color = 'AccentColor'
        });

        local HideBorderRight = Library:Create('Square', {
            Color = Library.AccentColor,
            Position = UDim2(1, 0, 0, 0),
            Size = UDim2(0, 1, 1, 0),
            ZIndex = 8,
            Parent = Fill
        });

        Library:AddToRegistry(HideBorderRight, {
            Color = 'AccentColor'
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2(1, 0, 1, 0),
            TextSize = Vector2.new(14, 14),
            Text = 'Infinite',
            ZIndex = 9,
            Parent = SliderInner
        });

         Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.Color = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2(0, X, 1, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end

            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end

        UserInputService.InputBegan:Connect(function(ip)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and SliderInner:IsMouseOver() and
                not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X
                local gPos = Fill.Size.X
                local Diff = mPos - (Fill.Position.X + gPos);

                while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end

                    task.wait(.1)
                end

                Library:AttemptSave()
            end
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default,
            'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end

        local Dropdown = {
            Values = Info.Values,
            Value = Info.Multi and {},
            Multi = Info.Multi,
            Type = 'Dropdown',
            SpecialType = Info.SpecialType, -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value)
            end
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2(1, 0, 0, 10),
                TextSize = Vector2.new(14, 14),
                Text = Info.Text,
                Center = false,
                ZIndex = 5,
                Parent = Container
            });

            Groupbox:AddBlank(3);
        end

        --[[
        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;
        ]]

        local DropdownOuter = Library:Create('Square', {
            Color = Color3.new(0, 0, 0),
            Size = UDim2(1, -4, 0, 20),
            ZIndex = 5,
            Parent = Container
        });

        Library:AddToRegistry(DropdownOuter, {
            Color = 'Black'
        });

        local DropdownInner = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 0, 1, 0),
            ZIndex = 6,
            Parent = DropdownOuter
        });

        local DropdownInnerOutline = Library:Create('Square', {
            Color = Library.OutlineColor,
            Size = UDim2(1, 2, 1, 2),
            ZIndex = 4,
            Parent = DropdownOuter
        });

        Library:AddToRegistry(DropdownInner, {
            Color = 'MainColor'
        });

        Library:AddToRegistry(DropdownInnerOutline, {
            Color = 'OutlineColor'
        });

        -- > no ui gradient again

        --[[
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });]]

        -- > no image access for dropdowns arrow

        local ItemList = Library:CreateLabel({
            Position = UDim2(0, 5, 0, 0),
            Size = UDim2(1, -5, 1, 0),

            TextSize = Vector2.new(14, 14),
            Text = '--',
            Center = false,
            ZIndex = 7,
            Parent = DropdownInner
        });

        Library:OnHighlight(DropdownInnerOutline, DropdownInnerOutline, {
            Color = 'AccentColor'
        }, {
            Color = 'Black'
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Square', {
            Color = Color3.new(0, 0, 0),
            BorderColor3 = Color3.new(0, 0, 0),
            ZIndex = 20,
            Visible = false
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.Size.X, DropdownOuter.Size.Y + 1);
        end

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.Size.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end

        RecalculateListPosition();
        RecalculateListSize();

        task.spawn(function()
            local cachedPos = DropdownOuter.Position
            while true do
                if DropdownOuter.Position ~= cachedPos then
                    RecalculateListPosition()
                    cachedPos = DropdownOuter.Position
                end
                task.wait(.1)
            end
        end)

        local ListInner = Library:Create('Square', {
            Color = Library.MainColor,
            Size = UDim2(1, 0, 1, 0),
            ZIndex = 21,
            Parent = ListOuter
        });
        Library:AddToRegistry(ListInner, {
            Color = 'MainColor'
        });

        local scrollFrame = ScrollingFrame.new({
            Transparency = 1;
            CanvasSize = UDim2(0,0,0,0);
            Size = UDim2(1,0,1,0);
            ZIndex = 21;
            Parent = ListInner;
        })

        local listLayout = drawing_constructor.UIListLayout({
            Parent = scrollFrame,
            FillDirection = 'Vertical';
            SortOrder = 'LayoutOrder';
            Padding = {Scale = 0, Offset = 0}
        })

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end
                end

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end

            ItemList.Text = (Str == '' and '--' or Str);
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local Buttons = {};

            for _,Element in next, scrollFrame:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy()
                end
            end;

            local Count = 0;

            for Idx,Value in next, Values do
                local Table = {};

                Count = Count + 1

                local Button = Library:Create('Square', {
                    Color = Library.MainColor;
                    Size = UDim2(1,-1,0,20);
                    ZIndex = 23;
                    Parent = scrollFrame;
                })

                local ButtonOutline = Library:Create('Square', {
                    Color = Library.OutlineColor;
                    Parent = Button;
                    Size = UDim2(1,2,1,2);
                    Position = UDim2(0,-1,0,-1);
                })

                Library:AddToRegistry(Button, {
                    Color = 'MainColor'
                })

                Library:AddToRegistry(ButtonOutline, {
                    Color = 'OutlineColor';
                })

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2(1, -6, 1, 0);
                    Position = UDim2(0, 6, 0, 0);
                    TextSize = Vector2.new(14,14);
                    Text = Value;
                    Center = false;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(ButtonOutline, ButtonOutline,
                    { Color = 'AccentColor', ZIndex = 24 },
                    { Color = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value
                end;

                
                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor = Selected and 'AccentColor' or 'FontColor';
                end;

                UserInputService.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and ButtonLabel:IsMouseOver() then
                        local Try = not Selected

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                             if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;
                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end
                    end
                end)

                
                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;

                Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

                local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
                RecalculateListSize(Y);
            end

            function Dropdown:SetValues(NewValues)
                if NewValues then
                    Dropdown.Values = NewValues;
                end;

                Dropdown:BuildDropdownList();
            end;

            function Dropdown:OpenDropdown()
                ListOuter.Visible = true;
                Library.OpenedFrames[ListOuter] = true;
            end;

            function Dropdown:CloseDropdown()
                ListOuter.Visible = false;
                Library.OpenedFrames[ListOuter] = nil;
             end;

            function Dropdown:OnChanged(Func)
                Dropdown.Changed = Func;
                Func(Dropdown.Value);
            end;

              function Dropdown:SetValue(Val)
                if Dropdown.Multi then
                    local nTable = {};

                    for Value, Bool in next, Val do
                        if table.find(Dropdown.Values, Value) then
                            nTable[Value] = true
                        end;
                    end;

                    Dropdown.Value = nTable;
                else
                    if (not Val) then
                        Dropdown.Value = nil;
                    elseif table.find(Dropdown.Values, Val) then
                        Dropdown.Value = Val;
                    end;
                end;

                Dropdown:BuildDropdownList();

                Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
            end;

            UserInputService.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() and DropdownOuter:IsMouseOver() then
                        if ListOuter.Visible then
                        Dropdown:CloseDropdown();
                    else
                        Dropdown:OpenDropdown();
                    end;
                end
            end)

            UserInputService.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local AbsPos, AbsSize = ListOuter.Position, ListOuter.Size;

                    if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                        or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                        Dropdown:CloseDropdown();
                    end;
                end;
            end);

            Dropdown:BuildDropdownList();
            Dropdown:Display();

            local Defaults = {}

            if type(Info.Default) == 'string' then
                local Idx = table.find(Dropdown.Values, Info.Default)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            elseif type(Info.Default) == 'table' then
                for _,Value in next, Info.Default do
                    local Idx = table.find(Dropdown.Values, Value)
                    if Idx then
                        table.insert(Defaults, Idx)
                    end
                end

            elseif type(info.Default) == 'number' and Dropdown.Values[info.Default] ~= nil then
                table.insert(Defaults, Info.Default)
            end
            if next(Defaults) then
                for i = 1, #Defaults do
                    local Index = Defaults[i]
                    if Info.Multi then
                        Dropdown.Value[Dropdown.Values[Index]] = true
                    else
                        Dropdown.Value = Dropdown.Values[Index];
                    end
                    if (not Info.Multi) then break end
                end
                Dropdown:BuildDropdownList();
                Dropdown:Display();
            end
            Groupbox:AddBlank(Info.BlankSize or 5);
            Groupbox:Resize();
            Options[Idx] = Dropdown;
            return Dropdown;
        end

        function Funcs:AddDependencyBox()
            local Depbox = {
                Dependencies = {};
            };

            local Groupbox = self;
            local Container = Groupbox.Container;

            local Holder = Library:Create('Square', {
                Transparency = 1;
                Size = UDim2(1,0,0,0);
                Visible = false;
                Parent = Container;
            });

            local Frame = Library:Create('Square', {
                Transparency = 1;
                Size = UDim2(1,0,1,0);
                Visible = true;
                Parent = Holder;
            })

            --> uilistlayout new
            local listLayout = drawing_constructor.UIListLayout({
                Parent = Frame,
                FillDirection = 'Vertical';
                SortOrder = 'LayoutOrder';
            });

            function Depbox:Resize()
                Holder.Size = UDim2(1, 0, 0, Layout.AbsoluteContentSize.Y);
                Groupbox:Resize();
            end;


            task.spawn(function()
                local CachedContentSize = Layout.AbsoluteContentSize
                local CachedVisibleSignal = Holder.Visible
                while true do
                    if Layout.AbsoluteContentSize ~= CachedContentSize then
                        Depbox:Resize()
                        CachedContentSize = Layout.AbsoluteContentSize;
                    end
                    if Holder.Visible ~= CachedVisibleSignal then
                        Depbox:Resize();
                        CachedVisibleSignal = Holder.Visible;
                    end
                    task.wait()
                end
            end)

        function Depbox:Update()
            for _,Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]
                local Value = Dependency[2]

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end
            end;

            Holder.Visible = true;
            Depbox:Resize()
        end

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;
                Depbox.Dependencies = Dependencies;
                Depbox:Update();
            end;

            Depbox.Container = Frame;

            setmetatable(Depbox, BaseGroupbox);

            table.insert(Library.DependencyBoxes, Depbox);

            return Depbox
        end

        
        BaseGroupbox.__index = Funcs;
        BaseGroupbox.__namecall = function(Table, Key, ...)
            return Funcs[Key](...);
        end;
    end
end


do
    Library.NotificationArea = Library:Create('Square', {
        Transparency = 1;
        Position = UDim2(0,0,0,40);
        Size = UDim2(0,300,0,200);
        ZIndex = 100;
    });

    local listLayout = drawing_constructor.UIListLayout({
        Parent = scrollFrame,
        FillDirection = 'Vertical';
        SortOrder = 'LayoutOrder';
        Padding = {Scale = 0, Offset = 4};
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Square', {
        Position = UDim2(0,100,0,-25);
        Size = UDim2(0,213,0,20);
        ZIndex = 200;
    })
    
    local WatermarkInner = Library:Create('Square', {
        Color = Library.MainColor;
        Size = UDim2(1,0,1,0);
        ZIndex = 201;
        Parent = WatermarkOuter
    })

    local WatermarkInnerOutline = Library:Create('Square', {
        Color = Library.AccentColor;
        Size = UDim2(1,2,1,2);
        Position = UDim2(0,-1,0,-1);
        ZIndex = 199;
        Parent = WatermarkInner;
    });

    Library:AddToRegistry(WatermarkInnerOutline, {
        Color = 'AccentColor';
    });

    local InnerFrame = Library:Create('Square', {
        Color = Color3.new(1,1,1);
        Position = UDim2(0,1,0,1);
        Size = UDim2(1,-2,1,-2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    --> no gradient

    --> end of where it would usually go

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2(0,5,0,0);
        Size = UDim2(1,-4,1,0);
        TextSize = Vector2.new(14,14);
        Center = false;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter
    Library.WatermarkLabel = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    local KeybindOuter = Library:Create('Square', {
        AnchorPoint = Vector2.new(0,0.5);
        Position = UDim2(0,10,0.5,0);
        Size = UDim2(0,210,0,20);
        Visible = false;
        ZIndex = 100;
    });

    local KeybindInner = Library:Create('Square', {
        Color = Library.MainColor;
        Size = UDim2(1,0,1,0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    local KeybindInnerOutline = Library:Create('Square', {
        Color = Library.OutlineColor;
        Size = UDim2(1,2,1,2);
        Position = UDim2(0,-1,0,-1);
        ZIndex = 99;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(KeybindInner, {
        Color = 'MainColor'
    }, true)
    Library:AddToRegistry(KeybindInnerOutline, {
        Color = 'OutlineColor'
    }, true)

    local ColorFrame = Library:Create('Square', {
        Color = Library.AccentColor;
        Size = UDim2(1,0,0,2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        Color = 'AccentColor';
    }, true)

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2(1,0,0,20);
        Position = UDim2.fromOffset(5,2);
        Center = false;
        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;

    });

    local KeybindContainer = Library:Create('Square', {
        Transparency = 1;
        Size = UDim2(1,0,1,-20);
        Position = UDim2(0,0,0,20);
        ZIndex = 1;
        Parent =  KeybindInner;
    })

    local listLayout = drawing_constructor.UIListLayout({
        Parent = KeybindContainer,
        FillDirection = 'Vertical';
        SortOrder = 'LayoutOrder';
    });

    local padding3 = drawing_constructor.UIPadding({
        Parent = KeybindContainer,
        PaddingLeft = {Scale = 0, Offset = 5};
    });

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visibile = Bool
end

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text);
    Library.Watermark.Size = UDim2(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true);
    Library.Watermark.Text = Text;
end

function Library:Notify(Text,Time)
    local XSize,YSize = Library:GetTextBounds(Text)

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Square', {
        Position = UDim2(0,100,0,10);
        Size = UDim2(0,0,0,YSize);
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Square', {
        Color = Library.MainColor;
        Size = UDim2(1,0,1,0);
        ZIndex = 101;
        Parent = NotifyOuter;
    })

    local NotifyInnerOutline = Library:Create('Square', {
        Color = Library.OutlineColor;
        Size = UDim2(1,2,1,2);
        Position = UDim2(0,-1,0,-1);
        ZIndex = 99;
        Parent = NotifyOuter;
    })

    Library:AddToRegistry(NotifyInner, {
        Color = 'MainColor';
    }, true);

    Library:AddToRegistry(NotifyInnerOutline, {
        Color = 'OutlineColor';
    }, true);


    local InnerFrame = Library:Create('Square', {
        Color = Color3.new(1,1,1);
        Position = UDim2(0,1,0,1);
        Size = UDim2(1,-2,1,-2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    --> no gradient

    --> come back if vault eva adds it 

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2(0,4,0,0);
        Size = UDim2(1,-4,1,0);
        Text = Text;
        Center = false;
        Size = Vector2.new(14,14);
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Square', {
        Color = Library.AccentColor;
        Position = UDim2(0,-1,0,-1);
        Size = UDim2(0,3,1,2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        Color = 'AccentColor'
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        task.wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        task.wait(0.4);

        NotifyOuter:Destroy();
    end)
end;


function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.new(0,0) }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'table' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'table' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5,0.5);
        Config.Position = UDim2(0.5,0,0.5,0);
    end


    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('Square', {
        AnchorPoint = Config.AnchorPoint;
        Color = Color3.new(0,0,0);
        Position = Config.Position;
        Size = Config.Size;
        Visible = false;
        ZIndex = 1;
    });

    Library:MakeDraggable(Outer, 25)

    local Inner = Library:Create('Square', {
        Color = Library.MainColor;
        Position = UDim2(0,1,0,1);
        Size = UDim2(1,-2,1,-2);
        ZIndex = 1;
        Parent = Outer;
    })

    local InnerOutline = Library:Create('Square', {
        Color = Library.AccentColor;
        Position = UDim2(0,-1,0,-1);
        Size = UDim2(1,2,1,2);
        ZIndex = 0;
        Parent = Outer;
    })

    local WindowLabel = Library:CreateLabel({
        Position = UDim2(0,7,0,0);
        Size = UDim2(0,0,0,25);
        Text = Config.Title or '';
        Center = false;
        ZIndex = 1;
        Parent = Inner;
    })

    local MainSectionOuter = Library:Create('Square', {
        Color = Library.BackgroundColor;
        Position = UDim2(0,8,0,25);
        Size = UDim2(1,-16,1,-33);
        ZIndex = 1;
        Parent = Inner;
    })

    local MainSectionOuterOutline = Library:Create('Square', {
        Color = Library.OutlineColor;
        Position = UDim2(0, -1, 0, -1);
        Size = UDim2(1, 2, 1, 2);
        ZIndex = 1;
        Parent = MainSectionOuter;
    })

    local MainSectionInner = Library:Create('Square', {
        Size = UDim2(1,0,1,0);
        Color = Library.BackgroundColor;
        Position = UDim2(0,0,0,0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });


    Library:AddToRegistry(MainSectionInner, {
        Color = 'BackgroundColor';
    })

    local TabArea = Library:Create('Square', {
        Transparency = 1;
        Position = UDim2(0,8,0,8);
        Size = UDim2(1,-16,0,21);
        Zindex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = drawing_constructor.UIListLayout({
        Padding = UDim2(0, Config.TabPadding);
        FillDirection = 'Horizontal';
        SortOrder = 'LayoutOrder';
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Square', {
        Color = Library.MainColor;
        Position = UDim2(0,8,0,30);
        Size = UDim2(1,-16,1,-38);
        ZIndex = 2;
        Parent = MainSectionInner;
    })
    local TabContainerOutline = Library:Create('Square', {
        Color = Library.OutlineColor;
        Parent = TabContainer;
        Size = UDim2(1,2,1,2);
        Position = UDim2(0,-1,0,-1);
        ZIndex = 1.1;
    });

      Library:AddToRegistry(TabContainer, {
        Color = 'MainColor';
    });


      Library:AddToRegistry(TabContainerOutline, {
        Color = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end

    function Window:AddTab(Name)
       local Tab = {
        Groupboxes = {};
        Tabboxes = {};
       };

       local TabButtonWidth = Library:GetTextBounds(Name);

       local TabButton = Library:Create('Square', {
        Color = Library.BackgroundColor;
        Size = UDim2(0, TabButtonWidth + 8 + 4, 1, 0);
        ZIndex = 1;
        Parent = TabArea;
       });


       local TabButtonOutline = Library:Create('Square', {
        Color = Library.OutlineColor;
        Size = UDim2(1,2,1,2);
        Position = UDim2(0,-1, 0, -1);
        Parent = TabButton;
        ZIndex = 0.9;
       })

       Library:AddToRegistry(TabButton, {
            Color = 'BackgroundColor';
        });

        Library:AddToRegistry(TabButtonOutline, {
            Color = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2(0,0,0,0);
            Size = UDim2(1,0,1,-1);
            Text = Name;
            ZIndex = 1;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Square', {
            Color = Library.MainColor;
            Position = UDim2(0,0,1,0);
            Size = UDim2(1,0,0,1);
            Transparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            Color = 'MainColor';
        });

        local TabFrame = Library:Create('Square', {
            Name = 'TabFrame';
            Transparency = 1;
            Position = UDim2(0,0,0,0);
            Size = UDim2(1,0,1,0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = ScrollingFrame.new({
            Transparency = 1;
            Position = UDim2(0, 8-1, 0, 8-1);
            Size = UDim2(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2(0,0,0,0);
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = ScrollingFrame.new({
            Transparency = 1;
            Position = UDim2(0.5, 4 + 1, 0, 8-1);
            Size = UDim2(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2(0,0,0,0);
            ZIndex = 2;
            Parent = TabFrame;
        });

        local lay1 = UIListLayout.new({
            Padding = UDim2(0,8);
            FillDirection = 'Vertical';
            SortOrder = 'LayoutOrder';
            HorizontalAlignment = 'Center';
            Parent = LeftSide;
        })
        local lay2 = UIListLayout.new({
            Padding = UDim2(0,8);
            FillDirection = 'Vertical';
            SortOrder = 'LayoutOrder';
            HorizontalAlignment = 'Center';
            Parent = RightSide;
        })

        task.spawn(function()
            local prev1, prev2
            prev1 = lay1.AbsoluteContentSize
            prev2 = lay2.AbsoluteContentSize
            while true do
                if lay1.AbsoluteContentSize ~= prev1 or lay2.AbsoluteContentSize ~= prev2 then
                    RightSide.CanvasSize = UDim2.fromOffset(0, lay1.AbsoluteContentSize.Y)
                    LeftSide.CanvasSize = UDim2.fromOffset(0, lay1.AbsoluteContentSize.Y)
                    prev1 = lay1.AbsoluteContentSize;
                    prev2 = lay2.AbsoluteContentSize;
                end
                task.wait(.1)
            end 

           
        end)


        function Tab:ShowTab()
            for _,Tab in next, Window.Tabs do
                Tab:HideTab()
            end

            Blocker.Transparency = 0;
            TabButton.Color = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.Color = 'MainColor';
            TabFrame.Visible = true;
        end;


        function Tab:HideTab()
            Blocker.Transparency = 1;
            TabButton.Color = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.Color = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Pos)
            TabButton.LayoutOrder = Pos
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Square', {
                Color = Library.BackgroundColor;
                Size = UDim2(1,0,0,507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide
            })

            local BoxOuterOutline = Library:Create('Square', {
                Color = Library.OutlineColor;
                Size = UDim2(1,2,1,2);
                Position = UDim2(0,-1,0,-1);
                ZIndex = 1.1;
                Parent = BoxOuter;
            })

            Library:AddToRegistry(BoxOuter, {
                Color = 'BackgroundColor';
            });

            Library:AddToRegistry(BoxOuterOutline, {
                Color = 'OutlineColor';
            });
            

            local BoxInner = Library:Create('Square', {
                Color = Library.BackgroundColor;
                Size = UDim2(1-2,1,-2);
                Position = UDim2(0,1,0,1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            local Highlight = Library:Create('Square', {
                Color = Library.AccentColor;
                Size = UDim2(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                Color = 'AccentColor'
            });


            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2(1,0,0,18);
                Position = UDim2(0,4,0,2);
                TextSize = Vector2.new(14,14);
                Center = false;
                ZIndex = 5;
                Text = Info.Name;
                Parent = BoxInner;
            });

            local Container = Library:CreateLabel({
                Size = UDim2(1,0,0,18);
                Position = UDim2(0,4,0,2);
                TextSize = Vector2.new(14,14);
                Text = Info.Name;
                Center = false;
                ZIndex = 5;
                Parent = BoxInner;
            });

            UIListLayout.new({
                FillDirectiopn = 'Vertical';
                SortOrder = 'LayoutOrder';
                Parent = Container;
            })

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(3);
            Groupbox:Resize();
            Tab.Groupboxes[Info.Name] = Groupbox;
            return Groupbox;
        end

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                Color = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                Color = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                Color = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2(1, -2, 1, -2);
                Position = UDim2(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                Color = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                Color = Library.AccentColor;
                Size = UDim2(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                Color = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2(0, 0, 0, 1);
                Size = UDim2(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    Color = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    Color = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    Color = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2(0, 0, 1, 0);
                    Size = UDim2(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    Color = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2(0, 4, 0, 20);
                    Size = UDim2(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.Color = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.Color = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.Color = Library.MainColor;
                    Library.RegistryMap[Button].Properties.Color = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y;
                        end;
                    end;

                    BoxOuter.Size = UDim2(1, 0, 0, 20 + Size + 2 + 2);
                end;

                UserInputService.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() and Button:IsMouseOver() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                -- Show first tab (number is 2 cus of the UIListLayout that also sits in that instance)
                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({Name = Name, Side = 1;});
        end

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({Name = Name, Side = 2;});
        end

        UserInputService.InputBegan:Connect(function(Input)
            if TabButton:IsMouseOver() and Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end)

        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end


    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    local function lerp(a, b, t)
        return a + (b - a) * t
    end

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        if Toggled then
            Outer.Visible = true;
            task.spawn(function()
                local Cursor = Drawing.new('Traingle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle')
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0,0,0)
                CursorOutline.Visible = true;

                while Toggled do
                    local mPos = Player:GetMouse()

                    Cursor.Color = Library.AccentColor

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    task.wait()
                end;


                Cursor:Remove()
                CursorOutline:Remove()
            end)
        end

        for _,Desc in next, Outer:GetChildren() do
            local Props = {}
            table.insert(Props, 'Transparency');

            local Cache = TransparencyCache[Desc]

            if (not Cache) then
                Cache = {}
                TransparencyCache[Desc] = Cache
            end;

            for _,Prop in next, Props do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop]
                end;

                if Cache[Prop] == 1 then
                    continue;
                end

                --> custom tween lerp for Transparency
                task.spawn(function()
                    local StartValue = Desc[Prop]
                    local EndValue = Toggled and Cache[Prop] or 1
                    local StartTime = tick()
                    
                    while true do
                        local Elapsed = tick() - StartTime
                        local Alpha = math.clamp(Elapsed / FadeTime, 0, 1)
                        
                        -- Ease out quad function for smooth fading
                        local EasedAlpha = 1 - (1 - Alpha) * (1 - Alpha)
                        
                        Desc[Prop] = lerp(StartValue, EndValue, EasedAlpha)
                        
                        if Alpha >= 1 then
                            Desc[Prop] = EndValue
                            break
                        end
                        
                        task.wait()
                    end
                end)
            end
        end
        
        task.wait(FadeTime)
        Outer.Visible = false
        Fading = false
    end

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.Keycode == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.Keycode == Enum.KeyCode.RightControl or (Input.Keycode == Enum.KeyCode.RightShift) then
            task.spawn(Library.Toggle)
        end 
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer

    return Window
end;

local function OnPlayerChange()
	local Playerlist = GetPlayersString()

	for _, Value in next, Options do
		if Value.Type == "Dropdown" and Value.SpecialType == "Player" then
			Value:SetValues(Playerlist)
		end
	end
end


local previousPlayers = {}

task.spawn(function()
	while true do
		local currentPlayers = {}
		for _, player in ipairs(Players:GetChildren()) do
			currentPlayers[player.Name] = true
		end


		local changed = false

		for name in pairs(currentPlayers) do
			if not previousPlayers[name] then
				changed = true
				break
			end
		end
		for name in pairs(previousPlayers) do
			if not currentPlayers[name] then
				changed = true
				break
			end
		end

		if changed then
			OnPlayerChange()
			previousPlayers = currentPlayers
		end

		task.wait(1)
	end
end)

_G.Library = Library
