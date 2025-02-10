script_name("Fire Alert & AutoUpdate") 
script_author("FORMYS") 
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
local script_vers_text = "1.10" 

local update_ini_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/update.ini" 
local update_ini_path = getWorkingDirectory() .. "/update.ini" 

local script_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/Fire_helper.lua" 
local script_path = thisScript().path 

local update_available = false 

-- Telegram-бот
local chat_id = '-4622362493'  
local token = '7799196233:AAGGLSxdMPc3kFg4Ryn4kGsDizyI79TvRss'  

local lastNotificationTime = 0 
local notificationCooldown = 30  
local notificationSent = {}  

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("update", cmd_update) 

    checkForUpdates() -- Проверка обновлений при запуске

    while true do
        checkFireAlert()  
        wait(1000) 
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
        
        local response, status = http.request(script_url)
        if status == 200 and response then
            local scriptFile = io.open(script_path, "w")
            if scriptFile then
                scriptFile:write(response)
                scriptFile:close()
                sampAddChatMessage("Обновление завершено! Перезапуск...", -1)
                wait(1000)
                script_reload() -- Перезапуск скрипта
            end
        else
            sampAddChatMessage("Ошибка загрузки обновления!", -1)
        end
    else
        sampAddChatMessage("У вас уже последняя версия.", -1)
    end
end

-- Функция перезапуска скрипта с обратным отсчётом
function script_reload()
    lua_thread.create(function()
        sampAddChatMessage(" Перезапуск скрипта через 3 секунды!", -1)
        wait(1000)
        sampAddChatMessage("3...", -1)
        wait(1000)
        sampAddChatMessage("2...", -1)
        wait(1000)
        sampAddChatMessage("1...", -1)
        wait(500)
        sampAddChatMessage(" Перезапуск...", -1)
        thisScript():reload() -- Перезапуск скрипта
    end)
end

function sendTelegramNotification(msg)
    msg = msg:gsub('{......}', '') 
    msg = u8:encode(msg, 'CP1251')  

    local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
                              token, chat_id, msg)
    
    lua_thread.create(function() -- Запускаем в отдельном потоке
        local response, status = http.request(url)
        if status ~= 200 then
            sampAddChatMessage("Ошибка отправки уведомления в Telegram!", -1)
        end
    end)
end
function sampev.onServerMessage(color, text)
    local currentTime = os.time()

    local level = text:match("(%d)%-й степени")  -- Ищем число перед "-й степени"
    if level and tonumber(level) and tonumber(level) >= 1 and tonumber(level) <= 3 then
        if currentTime - lastNotificationTime >= notificationCooldown then  
            sendTelegramNotification(string.format("Пожар %d-й степени! Заходи в игру!", tonumber(level)))  
            lastNotificationTime = currentTime  
        end  
    end
end
function checkFireAlert()
    local currentTime = os.date("*t")
    local fireTimes = {5, 25, 45} 

    for _, fireMinute in ipairs(fireTimes) do  
        if currentTime.min == (fireMinute - 5) and not notificationSent[currentTime.hour .. ":" .. fireMinute] then  
            sendTelegramNotification(string.format("Через 5 минут пожар в %02d:%02d! Заходи в игру!", currentTime.hour, fireMinute))  
            notificationSent[currentTime.hour .. ":" .. fireMinute] = true  
        end  
    end
end