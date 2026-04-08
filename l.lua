--[[
    Last Letter Helper - Xeno AutoPlay Edition (с game:HttpGet)
    Версия: 3.0
]]

local Players = game:GetService("Players")

-- НАСТРОЙКИ
local SETTINGS = {
    WORDS_PER_PAGE = 50,
    MAX_WORD_LENGTH = 20,
    MIN_WORD_LENGTH = 2,
    KEY_DELAY = 0.05,
    CHECK_INTERVAL = 0.3,
}

-- ССЫЛКА НА СЛОВАРЬ (рабочая, из открытого репозитория)
local WORDLIST_URL = "https://raw.githubusercontent.com/dwyl/english-words/master/words.txt"

-- Глобальные переменные
local wordsByPrefix = {}
local autoPlayEnabled = false
local currentPrefix = ""

-- Проверка: настоящее ли слово
local function isValidEnglishWord(word)
    if not string.match(word, "^[a-z]+$") then return false end
    if #word < SETTINGS.MIN_WORD_LENGTH then return false end
    if #word > SETTINGS.MAX_WORD_LENGTH then return false end
    return true
end

-- ЗАГРУЗКА СЛОВАРЯ через game:HttpGet (вместо HttpService)
local function loadDictionary()
    print("[LastLetter] Загрузка словаря через game:HttpGet...")
    
    local success, response = pcall(function()
        return game:HttpGet(WORDLIST_URL, true)
    end)
    
    if not success then
        warn("[LastLetter] Ошибка загрузки словаря! Ответ:", response)
        return false
    end
    
    if not response or response == "" then
        warn("[LastLetter] Словарь пустой!")
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
    
    -- Сортировка по длине
    for prefix, words in pairs(wordsByPrefix) do
        table.sort(words, function(a, b) return #a < #b end)
    end
    
    print(string.format("[LastLetter] Словарь загружен! %d слов (отфильтровано %d)", totalWords, filteredCount))
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

-- Автовыбор слова (самое короткое)
local function autoSelectWord(prefix)
    local matches = findWordsByPrefix(prefix)
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
        -- Xeno keypress
        keypress(letter)
        task.wait(SETTINGS.KEY_DELAY)
    end
    
    -- Нажимаем Enter
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

-- GUI управления
local function createGUI()
    -- Ждём, пока игрок загрузится
    local player = Players.LocalPlayer
    if not player then
        Players.PlayerAdded:Wait()
        player = Players.LocalPlayer
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LastLetterHelper"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 100)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Text = "Last Letter AutoPlay"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.BackgroundTransparency = 1
    title.Parent = frame
    
    local autoPlayBtn = Instance.new("TextButton")
    autoPlayBtn.Size = UDim2.new(1, -20, 0, 40)
    autoPlayBtn.Position = UDim2.new(0, 10, 0, 40)
    autoPlayBtn.Text = "▶ СТАРТ"
    autoPlayBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    autoPlayBtn.BorderSizePixel = 0
    autoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPlayBtn.Parent = frame
    
    autoPlayBtn.MouseButton1Click:Connect(function()
        if not autoPlayEnabled then
            autoPlayEnabled = true
            autoPlayBtn.Text = "⏸ СТОП"
            autoPlayBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            task.spawn(startAutoPlayLoop)
        else
            autoPlayEnabled = false
            autoPlayBtn.Text = "▶ СТАРТ"
            autoPlayBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        end
    end)
    
    return screenGui
end

-- Инициализация
local function init()
    print("[LastLetter] Инициализация...")
    
    local loaded = loadDictionary()
    if not loaded then
        warn("[LastLetter] Словарь не загружен! Проверь интернет или ссылку.")
        return
    end
    
    createGUI()
    print("[LastLetter] Готов! Нажми СТАРТ для авто-игры.")
end

-- Запуск
pcall(init)
