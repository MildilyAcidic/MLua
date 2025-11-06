--> constants
_G.IsDrawing = false

local Grid


local function parse_grid()
    local cells = {}
    local circles = {}
    local gridSize = 6
    
    for row = 1, gridSize do
        cells[row] = {}
        for col = 1, gridSize do
            local cellName = row .. "-" .. col
            local cell = Grid:FindFirstChild(cellName)
            if cell then
                cells[row][col] = {
                    frame = cell,
                    position = cell.AbsolutePosition,
                    value = 0
                }
                
                local circle = cell:FindFirstChild("Circle")
                if circle then
                    local numberLabel = circle:FindFirstChild("Number")
                    if numberLabel then
                        local pairNum = tonumber(numberLabel.Text)
                        cells[row][col].value = pairNum
                        
                        if not circles[pairNum] then
                            circles[pairNum] = {}
                        end
                        table.insert(circles[pairNum], {row = row, col = col})
                    end
                end
            end
        end
    end
    
    return cells, circles, gridSize
end


local function get_neighbors(r, c, rows, cols)
    local neighbors = {}
    local dirs = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
    for _, dir in ipairs(dirs) do
        local nr, nc = r + dir[1], c + dir[2]
        if nr >= 1 and nr <= rows and nc >= 1 and nc <= cols then
            table.insert(neighbors, {nr, nc})
        end
    end
    return neighbors
end


local function is_walkable(r, c, targetColor, grid, rows, cols)
    if r < 1 or r > rows or c < 1 or c > cols then
        return false
    end
    local cellValue = grid[r][c].value
    return cellValue == 0 or cellValue == targetColor
end


local function manhattan_distance(a, b)
    
    local ar, ac, br, bc
    if type(a) == "table" then
        ar = a.row or a[1]
        ac = a.col or a[2]
    end
    if type(b) == "table" then
        br = b.row or b[1]
        bc = b.col or b[2]
    end
    return math.abs(ar - br) + math.abs(ac - bc)
end


local function pqs(path, startPos, goalPos)
    if #path == 0 then
        return math.huge
    end
    
    local sr = startPos.row or startPos[1]
    local sc = startPos.col or startPos[2]
    
    if path[1][1] ~= sr or path[1][2] ~= sc then
        return math.huge
    end
    
    local score = #path
    local straightDist = manhattan_distance(startPos, goalPos)
    local deviationPenalty = math.max(0, #path - straightDist - 1) * 2
    score = score + deviationPenalty
    
    local directionChanges = 0
    for i = 3, #path do
        local prevDir = {path[i-1][1] - path[i-2][1], path[i-1][2] - path[i-2][2]}
        local currDir = {path[i][1] - path[i-1][1], path[i][2] - path[i-1][2]}
        if prevDir[1] ~= currDir[1] or prevDir[2] ~= currDir[2] then
            directionChanges = directionChanges + 1
        end
    end
    score = score + directionChanges * 0.5
    
    return score
end


local function fbp(startPos, goalPos, color, grid, rows, cols, maxPaths)
    maxPaths = maxPaths or 20
    
    local function heuristic(pos)
        return manhattan_distance(pos, goalPos)
    end
    
    local paths = {}
    local frontier = {}
    local visitedCosts = {}
    
    local startKey = startPos.row .. "," .. startPos.col
    table.insert(frontier, {
        priority = heuristic({startPos.row, startPos.col}),
        cost = 0,
        path = {{startPos.row, startPos.col}},
        visited = {[startKey] = true}
    })
    
    while #frontier > 0 and #paths < maxPaths do
        table.sort(frontier, function(a, b) return a.priority < b.priority end)
        local current = table.remove(frontier, 1)
        
        local currentPos = current.path[#current.path]
        local posKey = currentPos[1] .. "," .. currentPos[2]
        
        if visitedCosts[posKey] and visitedCosts[posKey] < current.cost then
            continue
        end
        visitedCosts[posKey] = current.cost
        
        if currentPos[1] == goalPos.row and currentPos[2] == goalPos.col then
            table.insert(paths, current.path)
            continue
        end
        
        if current.cost > manhattan_distance({startPos.row, startPos.col}, {goalPos.row, goalPos.col}) + 15 then
            continue
        end
        
        for _, neighbor in ipairs(get_neighbors(currentPos[1], currentPos[2], rows, cols)) do
            local nr, nc = neighbor[1], neighbor[2]
            local nKey = nr .. "," .. nc
            
            if not current.visited[nKey] and is_walkable(nr, nc, color, grid, rows, cols) then
                local newVisited = {}
                for k, v in pairs(current.visited) do
                    newVisited[k] = v
                end
                newVisited[nKey] = true
                
                local newPath = {}
                for _, p in ipairs(current.path) do
                    table.insert(newPath, p)
                end
                table.insert(newPath, {nr, nc})
                
                local newCost = current.cost + 1
                local priority = newCost + heuristic({nr, nc})
                
                table.insert(frontier, {
                    priority = priority,
                    cost = newCost,
                    path = newPath,
                    visited = newVisited
                })
            end
        end
    end
    
    table.sort(paths, function(a, b)
        return pqs(a, {startPos.row, startPos.col}, {goalPos.row, goalPos.col}) < pqs(b, {startPos.row, startPos.col}, {goalPos.row, goalPos.col})
    end)
    
    return paths
end


local function qcc(grid, remainingPairs, rows, cols)
    for color, endpoints in pairs(remainingPairs) do
        local startPos, goalPos = endpoints[1], endpoints[2]
        local queue = {{startPos.row, startPos.col}}
        local visited = {[startPos.row .. "," .. startPos.col] = true}
        local found = false
        
        while #queue > 0 and not found do
            local pos = table.remove(queue, 1)
            local r, c = pos[1], pos[2]
            
            if r == goalPos.row and c == goalPos.col then
                found = true
                break
            end
            
            for _, neighbor in ipairs(get_neighbors(r, c, rows, cols)) do
                local nr, nc = neighbor[1], neighbor[2]
                local nKey = nr .. "," .. nc
                
                if not visited[nKey] then
                    local cell = grid[nr][nc].value
                    if cell == 0 or cell == color or (nr == goalPos.row and nc == goalPos.col) then
                        visited[nKey] = true
                        table.insert(queue, {nr, nc})
                    end
                end
            end
        end
        
        if not found then
            return false
        end
    end
    return true
end


local function cfc(pos, grid, rows, cols)
    local count = 0
    local r = pos.row or pos[1]
    local c = pos.col or pos[2]
    for _, neighbor in ipairs(get_neighbors(r, c, rows, cols)) do
        if grid[neighbor[1]][neighbor[2]].value == 0 then
            count = count + 1
        end
    end
    return count
end


local function e_mrv_hr(remainingPairs, grid, rows, cols)
    local colorScores = {}
    
    for color, endpoints in pairs(remainingPairs) do
        local startPos, goalPos = endpoints[1], endpoints[2]
        local paths = fbp(startPos, goalPos, color, grid, rows, cols, 5)
        
        if #paths == 0 then
            return {color}
        end
        
        local pathScore = 10.0 / #paths
        local startFree = cfc(startPos, grid, rows, cols)
        local goalFree = cfc(goalPos, grid, rows, cols)
        local bottleneckScore = 5.0 / (startFree + goalFree + 1)
        local distanceScore = manhattan_distance(startPos, goalPos) * 0.1
        
        colorScores[color] = pathScore + bottleneckScore + distanceScore
    end
    
    local sortedColors = {}
    for color, _ in pairs(remainingPairs) do
        table.insert(sortedColors, color)
    end
    table.sort(sortedColors, function(a, b)
        return colorScores[a] > colorScores[b]
    end)
    
    return sortedColors
end


local function backtrack_solve(colorsToSolve, endpointsMap, grid, solution, rows, cols, depth, maxDepth)
    if #colorsToSolve == 0 then
        return solution
    end
    
    if depth > maxDepth then
        return nil
    end
    
    local remainingPairs = {}
    for _, color in ipairs(colorsToSolve) do
        remainingPairs[color] = endpointsMap[color]
    end
    
    local colorsSorted = e_mrv_hr(remainingPairs, grid, rows, cols)
    
    for _, color in ipairs(colorsSorted) do
        local endpoints = endpointsMap[color]
        local startPos, goalPos = endpoints[1], endpoints[2]
        
        local remaining = {}
        for _, c in ipairs(colorsToSolve) do
            if c ~= color then
                table.insert(remaining, c)
            end
        end
        
        
        
        local paths = fbp(startPos, goalPos, color, grid, rows, cols, 15)
        
        if #paths == 0 then
            continue
        end
        
        for i, path in ipairs(paths) do
            local originalStates = {}
            for _, pos in ipairs(path) do
                local r, c = pos[1], pos[2]
                originalStates[r .. "," .. c] = grid[r][c].value
                grid[r][c].value = color
            end
            
            solution[color] = path
            
            local remainingMap = {}
            for _, col in ipairs(remaining) do
                remainingMap[col] = endpointsMap[col]
            end
            
            if qcc(grid, remainingMap, rows, cols) then
                local result = backtrack_solve(remaining, endpointsMap, grid, solution, rows, cols, depth + 1, maxDepth)
                if result then
                    return result
                end
            end
            
            solution[color] = nil
            for key, val in pairs(originalStates) do
                local r, c = key:match("(%d+),(%d+)")
                grid[tonumber(r)][tonumber(c)].value = val
            end
        end
    end
    
    return nil
end


local function solve(endpointsMap, rows, cols)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = {value = 0}
        end
    end
    
    for color, endpoints in pairs(endpointsMap) do
        local r1, c1 = endpoints[1].row, endpoints[1].col
        local r2, c2 = endpoints[2].row, endpoints[2].col
        grid[r1][c1].value = color
        grid[r2][c2].value = color
    end
    
    local colorsToSolve = {}
    for color, _ in pairs(endpointsMap) do
        table.insert(colorsToSolve, color)
    end
    
    local maxDepths = {15, 20, 25}
    for _, maxDepth in ipairs(maxDepths) do
        
        for r = 1, rows do
            for c = 1, cols do
                grid[r][c].value = 0
            end
        end
        
        for color, endpoints in pairs(endpointsMap) do
            local r1, c1 = endpoints[1].row, endpoints[1].col
            local r2, c2 = endpoints[2].row, endpoints[2].col
            grid[r1][c1].value = color
            grid[r2][c2].value = color
        end
        
        local solution = {}
        local result = backtrack_solve(colorsToSolve, endpointsMap, grid, solution, rows, cols, 0, maxDepth)
        
        if result then
            return result
        end
    end
    

    return nil
end


local function lerp(a, b, t)
    return a + (b - a) * t
end

local function smooth_move(x1, y1, x2, y2, steps, delay)
    for i = 1, steps do
        local t = i / steps
        local x = lerp(x1, x2, t)
        local y = lerp(y1, y2, t)
        mousemoveabs(x, y)
        task.wait(delay)
    end
end

local function pixel_bump(x, y)
    -- Moves the mouse by 1 pixel and back to trigger UI hover detection
    mousemoveabs(x + 1, y)
    task.wait(0.001)
    mousemoveabs(x, y)
end

local function draw(cells, solutions)
    for color, path in pairs(solutions) do
        local firstPos = cells[path[1][1]][path[1][2]].position
        local x = firstPos.X + 25
        local y = firstPos.Y + 25
        
        -- Move to the first position
        mousemoveabs(x, y)
        task.wait(0.003)
        pixel_bump(x, y) -- tiny movement to make UI register hover
        mouse1press()
        task.wait(0.003)
        
        for i = 2, #path do
            local pos = cells[path[i][1]][path[i][2]].position
            local targetX = pos.X + 45
            local targetY = pos.Y + 45
            
            -- Smoothly move between cells (10 small lerp steps)
            smooth_move(x, y, targetX, targetY, 1, 0.001)
            
            x, y = targetX, targetY
        end
        
        mouse1release()
        task.wait(0.001)
    end
end

local function main()
    if _G.IsDrawing then
        return
    end

    _G.IsDrawing = true
    local cells, circles, gridSize = parse_grid()
    
    local endpointsMap = {}
    for pairNum, endpoints in pairs(circles) do
        if #endpoints == 2 then
            endpointsMap[pairNum] = endpoints
        end
    end
    
   
    local solution = solve(endpointsMap, gridSize, gridSize)
    
    if solution then
        draw(cells, solution)
    end

    task.wait(.67)
    _G.IsDrawing = false
end

spawn(function()
    while true do
        if iskeypressed(0x20) then
            if game.Players.LocalPlayer.PlayerGui:FindFirstChild('PuzzleUI') then
                Grid = game.Players.LocalPlayer.PlayerGui.PuzzleUI.Container.GridHolder.Grid
                main()
            end
        end
        task.wait(.2)
    end
end)
