while true do
  local arrayIndex = {
    serverMemory = {
      ['0x000011b'] = true;
      ['kernel32.dll'] = [[C:\Windows\System32\kernel32.dll]]
    }
  }
  local serverMemory = arrayIndex.serverMemory
  coroutine.wrap(function()
    while true do
      table.insert(serverMemory, #serverMemory+1,math.sin(os.clock())*3.14)
    end
  end)();
  printl(serverMemory)
end
