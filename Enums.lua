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
    A = 0x41, B = 0x42, C = 0x43, D = 0x44, E = 0x45, F = 0x46,
    G = 0x47, H = 0x48, I = 0x49, J = 0x4A, K = 0x4B, L = 0x4C,
    M = 0x4D, N = 0x4E, O = 0x4F, P = 0x50, Q = 0x51, R = 0x52,
    S = 0x53, T = 0x54, U = 0x55, V = 0x56, W = 0x57, X = 0x58,
    Y = 0x59, Z = 0x5A,
    Zero = 0x30, One = 0x31, Two = 0x32, Three = 0x33, Four = 0x34,
    Five = 0x35, Six = 0x36, Seven = 0x37, Eight = 0x38, Nine = 0x39,
    F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73, F5 = 0x74,
    F6 = 0x75, F7 = 0x76, F8 = 0x77, F9 = 0x78, F10 = 0x79,
    F11 = 0x7A, F12 = 0x7B,
    Up = 0x26, Down = 0x28, Left = 0x25, Right = 0x27,
    Shift = 0x10, Control = 0x11, Alt = 0x12, Space = 0x20,
    Enter = 0x0D, Escape = 0x1B, Tab = 0x09, Backspace = 0x08,
})
CreateEnumCategory("UserInputType", {
    MouseButton1 = 0x01, -- Left Button
    MouseButton2 = 0x02, -- Right Button
    MouseButton3 = 0x04, -- Middle Button
    MouseWheel = 0xFF01, -- Arbitrary value for scroll delta
    MouseMove = 0xFF02,  -- For InputChanged mouse movement
    Keyboard = 0xFF03,   -- For all keyboard events
})
return Enum
