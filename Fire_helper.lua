script_name("Autoupdate + FD helper")
script_author("tr: @zeka955")
script_description("Пожарный бот + автообновление")

require "lib.moonloader"
local inicfg = require("inicfg")
local encoding = require("encoding")
local sampev = require("samp.events")
local http = require("socket.http")

encoding.default = "CP1251"
local u8 = encoding.UTF8

-- Автообновление
local script_vers = 3
local script_vers_text = "1.89"

local update_ini_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/update.ini"
local update_ini_path = getWorkingDirectory() .. "/update.ini"

local script_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/Fire_helper.lua"
local script_path = thisScript().path

local update_available = false
local stats_folder = getWorkingDirectory() .. "/FireHelper"
local stats_path = stats_folder .. "/stats.ini"

-- Функция для проверки и создания папки
function ensureDirectoryExists(path)
    if not doesDirectoryExist(path) then
        createDirectory(path)
    end
end


-- Функция для загрузки и создания stats.ini
function loadStats()
    ensureDirectoryExists(stats_folder) -- Создаем папку, если ее нет

    local stats = inicfg.load(nil, stats_path)
    if not stats then
        stats = {Stats = {firesToday = 0, lastResetDay = os.date("%d")}}
        inicfg.save(stats, stats_path)
    end
    return stats
end

-- Telegram-бот
local chat_id = '-4622362493'
local token = '7203823667:AAHBNeCxjQUEsZTWfB-e0eJ87D5imUu4ccE'

local lastNotificationTime = 0
local notificationCooldown = 30
local notificationSent = {}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("update", cmd_update)

    checkForUpdates() -- Проверка обновлений при запуске

    while true do
        local currentTime = os.time()
        local currentHour = tonumber(os.date("%H", currentTime))
function cmd_fdstats()
    local stats = loadStats()
    local total = stats.Stats.firesToday or 0
    local lvl1 = stats.Stats.fires_lvl_1 or 0
    local lvl2 = stats.Stats.fires_lvl_2 or 0
    local lvl3 = stats.Stats.fires_lvl_3 or 0

    local message = string.format(
        "Статистика пожаров за сегодня:\n\n" ..
        "Всего пожаров: {FFFFFF}%d\n\n" ..
        "1-й степени: {33CC33}%d{FFFFFF}\n" ..  -- Зелёный, затем вернуть белый
        "2-й степени: {FFFF00}%d{FFFFFF}\n" ..  -- Жёлтый, затем вернуть белый
        "3-й степени: {FF3333}%d{FFFFFF}",      -- Красный, затем вернуть белый
        total, lvl1, lvl2, lvl3
    )

    sampShowDialog(1, "Статистика Пожаров", message, "Закрыть", "", 0)
end

sampRegisterChatCommand("fdstats", cmd_fdstats)
        while true do
    local currentTime = os.time()
    local currentHour = tonumber(os.date("%H", currentTime))
    local currentDate = tonumber(os.date("%d", currentTime)) -- Получаем текущий день

    -- Проверка на смену дня
    if lastNotificationTime ~= 0 then
        local lastDate = tonumber(os.date("%d", lastNotificationTime))
        if lastDate ~= currentDate then
            notificationSent = {} -- Сбрасываем список отправленных уведомлений
        end
    end

    -- Проверяем, что сейчас не позднее 22:00
    if currentHour >= 10 and currentHour < 22 then
        checkFireAlert() -- Проверка и отправка предупреждений
    elseif currentHour == 22 and not notificationSent["end_of_day"] then
        sendTelegramNotification("На сегодня пожары завершены. Всем спасибо за участие!")
        notificationSent["end_of_day"] = true
    end

    wait(1000)
end
    end
end

-- Проверка обновлений через HTTP-запрос
function checkForUpdates()
    local response, status = http.request(update_ini_url)

    if status == 200 and response then
        local iniFile = io.open(update_ini_path, "w")
        if iniFile then
            iniFile:write(response)
            iniFile:close()
        end

        local ini = inicfg.load(nil, update_ini_path)
        if ini and ini.info and tonumber(ini.info.vers) > script_vers then
            sampAddChatMessage("Доступно обновление! Версия: " .. ini.info.vers, -1)
            update_available = true
        end
        os.remove(update_ini_path)
    else
        sampAddChatMessage("Ошибка проверки обновлений!", -1)
    end
end

-- Команда обновления
function cmd_update()
    if update_available then
        sampAddChatMessage("Скачивание новой версии...", -1)

        lua_thread.create(function() -- Запускаем поток, чтобы избежать ошибки с `wait()`
            local response, status = http.request(script_url)
            if status == 200 and response then
                local scriptFile = io.open(script_path, "w")
                if scriptFile then
                    scriptFile:write(response)
                    scriptFile:close()
                    sampAddChatMessage("Обновление завершено! Перезапуск...", -1)
                    script_reload() -- Перезапуск скрипта
                end
            else
                sampAddChatMessage("Ошибка загрузки обновления!", -1)
            end
        end)
    else
        sampAddChatMessage("У вас уже последняя версия.", -1)
    end
end

-- Функция перезапуска скрипта с обратным отсчётом
function script_reload()
    lua_thread.create(function()
        sampAddChatMessage("Перезапуск скрипта через 3 секунды!", -1)
        wait(1000)
        sampAddChatMessage("3...", -1)
        wait(1000)
        sampAddChatMessage("2...", -1)
        wait(1000)
        sampAddChatMessage("1...", -1)
        wait(500)
        sampAddChatMessage("Перезапуск...", -1)
        thisScript():reload() -- Перезапуск скрипта
    end)
end

local fireCooldown = 2700 -- 45 минут в секундах
local lastFireTime = 0
local fireMessageCount = 0

-- Отправка уведомления с учетом ограничений
function sendTelegramNotification(msg)
    msg = msg:gsub('{......}', '') -- Очистка от лишних символов
    msg = u8:encode(msg, 'CP1251')

    local currentTime = os.time()

    -- Если прошло больше 45 минут с последнего пожара, сбрасываем счетчик сообщений
    if currentTime - lastFireTime >= fireCooldown then
        fireMessageCount = 0
        lastFireTime = currentTime
    end

    -- Ограничение: максимум 2 сообщения за пожар
    if fireMessageCount < 2 then
        fireMessageCount = fireMessageCount + 1

        local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
                                  token, chat_id, msg)

        lua_thread.create(function()
            local response, status = http.request(url)
            if status ~= 200 then
                sampAddChatMessage("Ошибка отправки уведомления в Telegram!", -1)
            else
                lastNotificationTime = os.time()
            end
        end)
    else
        sampAddChatMessage("Достигнут лимит сообщений для этого пожара.", -1)
    end
end

 function updateFireStats(level)
    local stats = loadStats()
    local currentDay = os.date("%d")

    -- Сбрасываем статистику, если день сменился
    if tonumber(stats.Stats.lastResetDay) ~= tonumber(currentDay) then
        stats.Stats.firesToday = 0
        stats.Stats.fires_lvl_1 = 0
        stats.Stats.fires_lvl_2 = 0
        stats.Stats.fires_lvl_3 = 0
        stats.Stats.lastResetDay = currentDay
    end

    -- Увеличиваем общий счетчик
    stats.Stats.firesToday = stats.Stats.firesToday + 1

    -- Увеличиваем счетчик для конкретного уровня
    if level == 1 then
        stats.Stats.fires_lvl_1 = stats.Stats.fires_lvl_1 + 1
    elseif level == 2 then
        stats.Stats.fires_lvl_2 = stats.Stats.fires_lvl_2 + 1
    elseif level == 3 then
        stats.Stats.fires_lvl_3 = stats.Stats.fires_lvl_3 + 1
    end

    inicfg.save(stats, stats_path)
end
-- Фильтрация сообщений сервера после 22:00
function sampev.onServerMessage(color, text)
    local currentTime = os.time()
    local currentHour = tonumber(os.date("%H", currentTime))

    if currentHour < 22 then
        local level = text:match("(%d)%-й степени") -- Ищем "1-й степени", "2-й степени", "3-й степени"
        if level and tonumber(level) and tonumber(level) >= 1 and tonumber(level) <= 3 then
            if os.time() - lastNotificationTime >= notificationCooldown and not notificationSent["degree_" .. level] then
                sendTelegramNotification(string.format(" Пожар %d-й степени! Заходи в игру!", tonumber(level)))
                updateFireStats(tonumber(level)) -- Обновляем статистику
                lastNotificationTime = os.time()
                notificationSent["degree_" .. level] = true
            end
        end
    end
end

function getMoscowTime()
    local utcTime = os.time(os.date("!*t")) -- Получаем UTC
    return os.date("*t", utcTime + 3 * 3600) -- Добавляем 3 часа (МСК)
end

-- Проверка времени для отправки предупреждений о пожаре
function checkFireAlert()
    local currentTime = getMoscowTime()
    local fireTimes = {5, 25, 45} -- Моменты, когда начинаются пожары

    for _, fireMinute in ipairs(fireTimes) do
        if currentTime.min == (fireMinute - 5) and not notificationSent[currentTime.hour .. ":" .. fireMinute] then
            sendTelegramNotification(string.format("Через 5 минут пожар в %02d:%02d по МСК! Заходи в игру!", currentTime.hour, fireMinute))
            notificationSent[currentTime.hour .. ":" .. fireMinute] = true
        end
    end
end

-- Фильтрация сообщений сервера после 22:00 (по МСК)
function sampev.onServerMessage(color, text)
    local currentTime = getMoscowTime()
    local currentHour = currentTime.hour

    if currentHour < 22 then
        local level = text:match("(%d)%-й степени")
        if level and tonumber(level) and tonumber(level) >= 1 and tonumber(level) <= 3 then
            if os.time() - lastNotificationTime >= notificationCooldown and not notificationSent["degree_" .. level] then
                sendTelegramNotification(string.format("Пожар %d-й степени! Заходи в игру!", tonumber(level)))
                lastNotificationTime = os.time()
                notificationSent["degree_" .. level] = true
            end
        end
    end
end