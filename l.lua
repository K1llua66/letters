--[[
    Last Letter Helper - Xeno AutoPlay Edition
    Словарь + Поисковик + Авто-игра
]]

local Players = game:GetService("Players")

-- НАСТРОЙКИ
local SETTINGS = {
    WORDS_PER_PAGE = 50,        -- Слов на странице
    MAX_WORD_LENGTH = 20,
    MIN_WORD_LENGTH = 2,
    KEY_DELAY = 0.05,
    CHECK_INTERVAL = 0.3,
}

-- ССЫЛКА НА СЛОВАРЬ
local WORDLIST_URL = "https://raw.githubusercontent.com/dwyl/english-words/master/words.txt"

-- Глобальные переменные
local wordsByPrefix = {}
local autoPlayEnabled = false
local currentPrefix = ""
local currentPage = 1
local totalPages = 1
local currentSearchResults = {}

-- Проверка: настоящее ли слово
local function isValidEnglishWord(word)
    if not string.match(word, "^[a-z]+$") then return false end
    if #word < SETTINGS.MIN_WORD_LENGTH then return false end
    if #word > SETTINGS.MAX_WORD_LENGTH then return false end
    return true
end

-- ЗАГРУЗКА СЛОВАРЯ
local function loadDictionary()
    print("[LastLetter] Загрузка словаря...")
    
    local success, response = pcall(function()
        return game:HttpGet(WORDLIST_URL, true)
    end)
    
    if not success then
        warn("[LastLetter] Ошибка загрузки словаря!")
        return false
    end
    
    local totalWords = 0
    for line in string.gmatch(response, "[^\r\n]+") do
        local word = string.lower(string.match(line, "^[a-zA-Z]+$") or "")
        
        if isValidEnglishWord(word) then
            local prefix = string.sub(word, 1, 1)
            if not wordsByPrefix[prefix] then
                wordsByPrefix[prefix] = {}
            end
            table.insert(wordsByPrefix[prefix], word)
            totalWords = totalWords + 1
        end
    end
    
    -- Сортировка по длине
    for prefix, words in pairs(wordsByPrefix) do
        table.sort(words, function(a, b) 
            if #a ~= #b then return #a < #b end
            return a < b
        end)
    end
    
    print(string.format("[LastLetter] Словарь загружен! %d слов", totalWords))
    return true
end

-- Поиск слов по префиксу (любой длины)
local function searchWordsByPrefix(prefix)
    if not prefix or prefix == "" then return {} end
    
    local firstLetter = string.sub(prefix, 1, 1)
    local allWords = wordsByPrefix[firstLetter] or {}
    local matches = {}
    
    for _, word in ipairs(allWords) do
        if string.sub(word, 1, #prefix) == prefix then
            table.insert(matches, word)
        end
    end
    
    return matches
end

-- Получение страницы из результатов поиска
local function getSearchPage(page)
    local startIdx = (page - 1) * SETTINGS.WORDS_PER_PAGE + 1
    local endIdx = math.min(startIdx + SETTINGS.WORDS_PER_PAGE - 1, #currentSearchResults)
    
    local pageWords = {}
    for i = startIdx, endIdx do
        table.insert(pageWords, currentSearchResults[i])
    end
    
    totalPages = math.max(1, math.ceil(#currentSearchResults / SETTINGS.WORDS_PER_PAGE))
    return pageWords
end

-- Автовыбор слова (самое короткое)
local function autoSelectWord(prefix)
    local matches = searchWordsByPrefix(prefix)
    if #matches > 0 then
        return matches[1]
    end
    return nil
end

-- Автоматическое получение префикса из игры
local function getPrefixFromGame()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local searchAreas = {
        player.PlayerGui,
        game:GetService("CoreGui")
    }
    
    for _, gui in ipairs(searchAreas) do
        if gui then
            local descendants = gui:GetDescendants()
            for _, v in ipairs(descendants) do
                if v:IsA("TextLabel") or v:IsA("TextBox") or v:IsA("TextButton") then
                    local text = v.Text or ""
                    if string.find(string.lower(text), "type an english word starting with:") then
                        local prefix = string.match(text, "starting with:%s*(%w+)")
                        if prefix and prefix ~= "" then
                            return string.lower(prefix)
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Эмуляция печати через Xeno
local function typeSuffix(suffix)
    if not suffix or suffix == "" then return end
    
    for i = 1, #suffix do
        local letter = string.sub(suffix, i, i)
        keypress(letter)
        task.wait(SETTINGS.KEY_DELAY)
    end
    
    task.wait(0.1)
    keypress(Enum.KeyCode.Return)
end

-- Основной цикл авто-игры
local function startAutoPlayLoop()
    print("[LastLetter] Авто-игра запущена!")
    
    while autoPlayEnabled do
        local prefix = getPrefixFromGame()
        
        if prefix and prefix ~= "" and prefix ~= currentPrefix then
            currentPrefix = prefix
            print("[LastLetter] Найден префикс: " .. prefix)
            
            local word = autoSelectWord(prefix)
            if word then
                local suffix = string.sub(word, #prefix + 1)
                if suffix == "" then suffix = " " end
                print("[LastLetter] Слово: " .. word .. " | Печатаю: " .. suffix)
                typeSuffix(suffix)
            else
                print("[LastLetter] Нет слов для префикса: " .. prefix)
            end
        end
        
        task.wait(SETTINGS.CHECK_INTERVAL)
    end
end

-- GUI с поисковиком
local function createGUI()
    local player = Players.LocalPlayer
    if not player then
        Players.PlayerAdded:Wait()
        player = Players.LocalPlayer
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LastLetterHelper"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Основной фрейм (увеличенный)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 500)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.Text = "Last Letter Helper"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame
    
    -- Поле для поиска
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -10, 0, 35)
    searchBox.Position = UDim2.new(0, 5, 0, 40)
    searchBox.PlaceholderText = "🔍 Введи буквы для поиска (например: re, car, a...)"
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    searchBox.BorderSizePixel = 0
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = frame
    
    -- Панель управления страницами
    local pagePanel = Instance.new("Frame")
    pagePanel.Size = UDim2.new(1, -10, 0, 35)
    pagePanel.Position = UDim2.new(0, 5, 0, 80)
    pagePanel.BackgroundTransparency = 1
    pagePanel.Parent = frame
    
    local prevBtn = Instance.new("TextButton")
    prevBtn.Size = UDim2.new(0, 60, 1, -5)
    prevBtn.Position = UDim2.new(0, 0, 0, 2)
    prevBtn.Text = "◀ Назад"
    prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    prevBtn.BorderSizePixel = 0
    prevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    prevBtn.Parent = pagePanel
    
    local pageInfo = Instance.new("TextLabel")
    pageInfo.Size = UDim2.new(1, -130, 1, -5)
    pageInfo.Position = UDim2.new(0, 65, 0, 2)
    pageInfo.Text = "Страница 1 / 1 (0 слов)"
    pageInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    pageInfo.BackgroundTransparency = 1
    pageInfo.TextSize = 12
    pageInfo.Parent = pagePanel
    
    local nextBtn = Instance.new("TextButton")
    nextBtn.Size = UDim2.new(0, 60, 1, -5)
    nextBtn.Position = UDim2.new(1, -65, 0, 2)
    nextBtn.Text = "Вперед ▶"
    nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    nextBtn.BorderSizePixel = 0
    nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    nextBtn.Parent = pagePanel
    
    -- Список слов (ScrollingFrame)
    local wordsList = Instance.new("ScrollingFrame")
    wordsList.Size = UDim2.new(1, -10, 1, -170)
    wordsList.Position = UDim2.new(0, 5, 0, 120)
    wordsList.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    wordsList.BorderSizePixel = 0
    wordsList.CanvasSize = UDim2.new(0, 0, 0, 0)
    wordsList.ScrollBarThickness = 8
    wordsList.Parent = frame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = wordsList
    
    -- Кнопка авто-игры
    local autoPlayBtn = Instance.new("TextButton")
    autoPlayBtn.Size = UDim2.new(1, -10, 0, 40)
    autoPlayBtn.Position = UDim2.new(0, 5, 0, 455)
    autoPlayBtn.Text = "▶ АВТО-ИГРА (ВЫКЛ)"
    autoPlayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    autoPlayBtn.BorderSizePixel = 0
    autoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPlayBtn.Font = Enum.Font.GothamBold
    autoPlayBtn.Parent = frame
    
    -- Кнопка перетаскивания
    local dragHandle = Instance.new("TextButton")
    dragHandle.Size = UDim2.new(1, 0, 0, 25)
    dragHandle.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    dragHandle.Text = "⋮⋮  Перетащи меня  ⋮⋮"
    dragHandle.TextSize = 12
    dragHandle.BorderSizePixel = 0
    dragHandle.Parent = frame
    
    -- Перетаскивание
    local dragging = false
    local dragStart = nil
    dragHandle.MouseButton1Down:Connect(function(x, y)
        dragging = true
        dragStart = Vector2.new(x, y)
    end)
    
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
            frame.Position = UDim2.new(0, frame.Position.X.Offset + delta.X, 0, frame.Position.Y.Offset + delta.Y)
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)
    
    -- Функция обновления списка слов
    local function updateWordList()
        for _, child in ipairs(wordsList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local pageWords = getSearchPage(currentPage)
        
        for _, word in ipairs(pageWords) do
            local wordBtn = Instance.new("TextButton")
            wordBtn.Size = UDim2.new(1, 0, 0, 32)
            wordBtn.Text = word .. "  (" .. #word .. " букв)"
            wordBtn.TextXAlignment = Enum.TextXAlignment.Left
            wordBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            wordBtn.BorderSizePixel = 0
            wordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            wordBtn.Parent = wordsList
            
            wordBtn.MouseButton1Click:Connect(function()
                -- Отправляем слово в игру
                local suffix = string.sub(word, #currentPrefix + 1)
                if suffix == "" then suffix = " " end
                typeSuffix(suffix)
                print("[LastLetter] Отправлено слово: " .. word)
            end)
        end
        
        wordsList.CanvasSize = UDim2.new(0, 0, 0, #pageWords * 34 + 10)
        pageInfo.Text = string.format("Страница %d / %d (%d слов)", currentPage, totalPages, #currentSearchResults)
    end
    
    -- Поиск при вводе текста
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(searchBox.Text)
        currentSearchResults = searchWordsByPrefix(query)
        currentPage = 1
        updateWordList()
    end)
    
    -- Кнопки навигации
    prevBtn.MouseButton1Click:Connect(function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            updateWordList()
        end
    end)
    
    nextBtn.MouseButton1Click:Connect(function()
        if currentPage < totalPages then
            currentPage = currentPage + 1
            updateWordList()
        end
    end)
    
    -- Авто-игра
    autoPlayBtn.MouseButton1Click:Connect(function()
        autoPlayEnabled = not autoPlayEnabled
        if autoPlayEnabled then
            autoPlayBtn.Text = "⏸ АВТО-ИГРА (ВКЛ)"
            autoPlayBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            task.spawn(startAutoPlayLoop)
        else
            autoPlayBtn.Text = "▶ АВТО-ИГРА (ВЫКЛ)"
            autoPlayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
        end
    end)
    
    return screenGui
end

-- Инициализация
local function init()
    print("[LastLetter] Инициализация...")
    
    local loaded = loadDictionary()
    if not loaded then
        warn("[LastLetter] Словарь не загружен!")
        return
    end
    
    createGUI()
    print("[LastLetter] Готов! Используй поисковик или включи авто-игру.")
end

-- Запуск
pcall(init)
