--[[
    Last Letter Game Helper Script
    Версия: 2.0.0
    Описание: Авто-помощник для игры "Last Letter" с поиском слов и автовводом
    Словарь: dwyl/english-words (466k слов, отфильтрованных)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- НАСТРОЙКИ
local SETTINGS = {
    WORDS_PER_PAGE = 50,
    MAX_WORD_LENGTH = 20,
    MIN_WORD_LENGTH = 2,
    AUTO_PLAY_DELAY = 0.05,
}

-- ССЫЛКА НА СЛОВАРЬ (твой файл на GitHub)
local WORDLIST_URL = "https://raw.githubusercontent.com/K1llua66/letters/main/words.txt"

-- Глобальные переменные
local wordsByPrefix = {}
local remoteEvent = nil
local autoPlayEnabled = false
local currentPrefix = ""
local currentPage = 1
local totalPages = 1
local currentWordList = {}
local player = nil

-- Функция проверки: настоящее ли английское слово
local function isValidEnglishWord(word)
    if not string.match(word, "^[a-z]+$") then return false end
    if #word < SETTINGS.MIN_WORD_LENGTH then return false end
    if #word > SETTINGS.MAX_WORD_LENGTH then return false end
    if string.find(word, "[%d%.%-%'%_]") then return false end
    return true
end

-- Создаём RemoteEvent
local function setupRemoteEvent()
    remoteEvent = Instance.new("RemoteEvent")
    remoteEvent.Name = "LastLetterHelper"
    remoteEvent.Parent = ReplicatedStorage
    return remoteEvent
end

-- Загрузка и фильтрация словаря
local function loadDictionary()
    print("[LastLetter] Загрузка словаря...")
    
    local success, response = pcall(function()
        return HttpService:GetAsync(WORDLIST_URL)
    end)
    
    if not success then
        warn("[LastLetter] Ошибка загрузки! Проверь ссылку и интернет.")
        return false
    end
    
    local totalWords = 0
    local filteredCount = 0
    
    for line in string.gmatch(response, "[^\r\n]+") do
        local word = string.lower(string.match(line, "^[a-zA-Z]+$") or "")
        
        if isValidEnglishWord(word) then
            local prefix = string.sub(word, 1, 1)
            if not wordsByPrefix[prefix] then
                wordsByPrefix[prefix] = {}
            end
            table.insert(wordsByPrefix[prefix], word)
            totalWords = totalWords + 1
        else
            filteredCount = filteredCount + 1
        end
    end
    
    -- Сортируем слова по длине (от коротких к длинным)
    for prefix, words in pairs(wordsByPrefix) do
        table.sort(words, function(a, b)
            if #a ~= #b then return #a < #b end
            return a < b
        end)
    end
    
    print(string.format("[LastLetter] Словарь загружен! %d слов (отфильтровано %d)", 
        totalWords, filteredCount))
    return true
end

-- Поиск слов по префиксу
local function findWordsByPrefix(prefix)
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

-- Получение страницы слов
local function getWordsPage(prefix, page)
    local allMatches = findWordsByPrefix(prefix)
    local startIdx = (page - 1) * SETTINGS.WORDS_PER_PAGE + 1
    local endIdx = math.min(startIdx + SETTINGS.WORDS_PER_PAGE - 1, #allMatches)
    
    local pageWords = {}
    for i = startIdx, endIdx do
        table.insert(pageWords, allMatches[i])
    end
    
    totalPages = math.max(1, math.ceil(#allMatches / SETTINGS.WORDS_PER_PAGE))
    currentWordList = pageWords
    
    return pageWords, totalPages, #allMatches
end

-- Автовыбор слова (самое короткое подходящее)
local function autoSelectWord(prefix)
    local matches = findWordsByPrefix(prefix)
    if #matches > 0 then
        return matches[1]
    end
    return nil
end

-- Создание GUI
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LastLetterHelper"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Основной фрейм
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 420)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Text = "Last Letter Helper v2"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.BackgroundTransparency = 1
    title.Parent = frame
    
    -- Поле для ввода
    local prefixBox = Instance.new("TextBox")
    prefixBox.Size = UDim2.new(1, -10, 0, 30)
    prefixBox.Position = UDim2.new(0, 5, 0, 35)
    prefixBox.PlaceholderText = "Введи буквы (например: re, car, a...)"
    prefixBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    prefixBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    prefixBox.BorderSizePixel = 0
    prefixBox.Parent = frame
    
    -- Кнопка поиска
    local searchBtn = Instance.new("TextButton")
    searchBtn.Size = UDim2.new(0, 80, 0, 30)
    searchBtn.Position = UDim2.new(0, 5, 0, 70)
    searchBtn.Text = "Найти"
    searchBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    searchBtn.BorderSizePixel = 0
    searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBtn.Parent = frame
    
    -- Информация о страницах
    local pageInfo = Instance.new("TextLabel")
    pageInfo.Size = UDim2.new(0, 150, 0, 30)
    pageInfo.Position = UDim2.new(0, 90, 0, 70)
    pageInfo.Text = "Страница 1 / 1"
    pageInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    pageInfo.BackgroundTransparency = 1
    pageInfo.Parent = frame
    
    -- Кнопка "Назад"
    local prevBtn = Instance.new("TextButton")
    prevBtn.Size = UDim2.new(0, 40, 0, 30)
    prevBtn.Position = UDim2.new(0, 245, 0, 70)
    prevBtn.Text = "<"
    prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    prevBtn.BorderSizePixel = 0
    prevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    prevBtn.Parent = frame
    
    -- Кнопка "Вперёд"
    local nextBtn = Instance.new("TextButton")
    nextBtn.Size = UDim2.new(0, 40, 0, 30)
    nextBtn.Position = UDim2.new(0, 255, 0, 70)
    nextBtn.Text = ">"
    nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    nextBtn.BorderSizePixel = 0
    nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    nextBtn.Parent = frame
    
    -- Список слов
    local wordsList = Instance.new("ScrollingFrame")
    wordsList.Size = UDim2.new(1, -10, 1, -130)
    wordsList.Position = UDim2.new(0, 5, 0, 105)
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
    autoPlayBtn.Size = UDim2.new(1, -10, 0, 35)
    autoPlayBtn.Position = UDim2.new(0, 5, 0, 380)
    autoPlayBtn.Text = "🔘 Авто-игра: ВЫКЛ"
    autoPlayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    autoPlayBtn.BorderSizePixel = 0
    autoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPlayBtn.Parent = frame
    
    -- Кнопка перетаскивания
    local dragHandle = Instance.new("TextButton")
    dragHandle.Size = UDim2.new(1, 0, 0, 20)
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
    
    -- Обновление списка слов
    local function updateWordList()
        for _, child in ipairs(wordsList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for i, word in ipairs(currentWordList) do
            local wordBtn = Instance.new("TextButton")
            wordBtn.Size = UDim2.new(1, 0, 0, 30)
            wordBtn.Text = word .. " (" .. #word .. " букв)"
            wordBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            wordBtn.BorderSizePixel = 0
            wordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            wordBtn.Parent = wordsList
            
            wordBtn.MouseButton1Click:Connect(function()
                remoteEvent:FireServer("submitWord", word)
                print("[LastLetter] Отправлено слово: " .. word)
            end)
        end
        
        wordsList.CanvasSize = UDim2.new(0, 0, 0, #currentWordList * 32 + 10)
    end
    
    -- Поиск
    searchBtn.MouseButton1Click:Connect(function()
        currentPrefix = string.lower(prefixBox.Text)
        currentPage = 1
        
        local words, total, totalCount = getWordsPage(currentPrefix, currentPage)
        pageInfo.Text = string.format("Страница %d / %d (%d слов)", currentPage, totalPages, totalCount)
        updateWordList()
    end)
    
    -- Назад
    prevBtn.MouseButton1Click:Connect(function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            local words, total, totalCount = getWordsPage(currentPrefix, currentPage)
            pageInfo.Text = string.format("Страница %d / %d (%d слов)", currentPage, totalPages, totalCount)
            updateWordList()
        end
    end)
    
    -- Вперёд
    nextBtn.MouseButton1Click:Connect(function()
        if currentPage < totalPages then
            currentPage = currentPage + 1
            local words, total, totalCount = getWordsPage(currentPrefix, currentPage)
            pageInfo.Text = string.format("Страница %d / %d (%d слов)", currentPage, totalPages, totalCount)
            updateWordList()
        end
    end)
    
    -- Авто-игра
    autoPlayBtn.MouseButton1Click:Connect(function()
        autoPlayEnabled = not autoPlayEnabled
        if autoPlayEnabled then
            autoPlayBtn.Text = "⏵ Авто-игра: ВКЛ"
            autoPlayBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            remoteEvent:FireServer("enableAutoPlay")
        else
            autoPlayBtn.Text = "🔘 Авто-игра: ВЫКЛ"
            autoPlayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            remoteEvent:FireServer("disableAutoPlay")
        end
    end)
    
    return screenGui
end

-- Обработчики от сервера
local function setupRemoteHandlers()
    remoteEvent.OnClientEvent:Connect(function(action, data)
        if action == "autoWord" then
            print("[LastLetter] Авто-ввод: " .. data)
        elseif action == "updatePrefix" then
            currentPrefix = data
            if prefixBox then
                prefixBox.Text = currentPrefix
                searchBtn:Click()
            end
            
            if autoPlayEnabled then
                local word = autoSelectWord(currentPrefix)
                if word then
                    task.wait(SETTINGS.AUTO_PLAY_DELAY)
                    remoteEvent:FireServer("submitWord", word)
                end
            end
        end
    end)
end

-- Главная функция
local function init()
    print("[LastLetter] Инициализация...")
    
    setupRemoteEvent()
    
    local loaded = loadDictionary()
    if not loaded then
        warn("[LastLetter] Не удалось загрузить словарь. GUI не будет создан.")
        return
    end
    
    player = Players.LocalPlayer
    if not player then
        Players.PlayerAdded:Wait()
        player = Players.LocalPlayer
    end
    
    createGUI()
    setupRemoteHandlers()
    
    print("[LastLetter] Готов к работе! Словарь загружен.")
end

-- Запуск
pcall(init)
