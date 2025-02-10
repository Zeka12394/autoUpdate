script_name("Fire Alert & AutoUpdate") 
script_author("FORMYS") 
script_description("�������� ��� + ��������������") 

require "lib.moonloader" 

local inicfg = require("inicfg") 
local encoding = require("encoding") 
local sampev = require("samp.events")
local http = require("socket.http")  -- �������� HTTP-����������

encoding.default = "CP1251"
local u8 = encoding.UTF8 

--  ��������������
local script_vers = 3 
local script_vers_text = "1.10" 

local update_ini_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/update.ini" 
local update_ini_path = getWorkingDirectory() .. "/update.ini" 

local script_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/Fire_helper.lua" 
local script_path = thisScript().path 

local update_available = false 

--  Telegram-���
local chat_id = '-4622362493'  
local token = '7799196233:AAGGLSxdMPc3kFg4Ryn4kGsDizyI79TvRss'  

local lastNotificationTime = 0 
local notificationCooldown = 30  
local notificationSent = {}  

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("update", cmd_update) 

    checkForUpdates() -- �������� ���������� ��� �������

    while true do
        checkFireAlert()  
        wait(1000) -- �������� ������ ������� (��� ����������� � ������)
    end
end

--  �������� ���������� ����� HTTP-������
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
            sampAddChatMessage(" �������� ����������! ������: " .. ini.info.vers, -1)
            update_available = true
        end
        os.remove(update_ini_path)
    else
        sampAddChatMessage(" ������ �������� ����������!", -1)
    end
end

--  ������� ����������
function cmd_update()
    if update_available then
        sampAddChatMessage(" ���������� ����� ������...", -1)
        
        local response, status = http.request(script_url)
        if status == 200 and response then
            local scriptFile = io.open(script_path, "w")
            if scriptFile then
                scriptFile:write(response)
                scriptFile:close()
                sampAddChatMessage(" ���������� ���������! ������������� ������.", -1)
            end
        else
            sampAddChatMessage(" ������ �������� ����������!", -1)
        end
    else
        sampAddChatMessage("� ��� ��� ��������� ������. V3", -1)
    end
end

--  Telegram-�����������
function sendTelegramNotification(msg)
    msg = msg:gsub('{......}', '') 
    msg = u8:encode(msg, 'CP1251') 
    async_http_request('https://api.telegram.org/bot' .. token .. '/sendMessage?chat_id=' .. chat_id .. '&text=' .. msg, '', function(_) end)
end

function sampev.onServerMessage(color, text)
    local currentTime = os.time()

    if color == 0x00FF00 and text:lower():find("�������") then  
        if currentTime - lastNotificationTime >= notificationCooldown then  
            sendTelegramNotification(' ������ � ����! ����� �������!')  
            lastNotificationTime = currentTime  
        end  
    end
end

function checkFireAlert()
    local currentTime = os.date("*t")
    local fireTimes = {5, 25, 45} 

    for _, fireMinute in ipairs(fireTimes) do  
        if currentTime.min == (fireMinute - 5) and not notificationSent[currentTime.hour .. ":" .. fireMinute] then  
            sendTelegramNotification(string.format(" ����� 5 ����� ����� � %02d:%02d! ������ � ����!", currentTime.hour, fireMinute))  
            notificationSent[currentTime.hour .. ":" .. fireMinute] = true  
        end  
    end
end