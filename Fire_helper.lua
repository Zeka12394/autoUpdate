script_name("Autoupdate + FD helper")
script_author("tr: @zeka955")
script_description("�������� ��� + ��������������")

require "lib.moonloader"
local inicfg = require("inicfg")
local encoding = require("encoding")
local sampev = require("samp.events")
local http = require("socket.http")

encoding.default = "CP1251"
local u8 = encoding.UTF8

-- ��������������
local script_vers = 3
local script_vers_text = "1.89"

local update_ini_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/update.ini"
local update_ini_path = getWorkingDirectory() .. "/update.ini"

local script_url = "https://raw.githubusercontent.com/Zeka12394/autoUpdate/refs/heads/main/Fire_helper.lua"
local script_path = thisScript().path

local update_available = false
local stats_folder = getWorkingDirectory() .. "/FireHelper"
local stats_path = stats_folder .. "/stats.ini"

-- ������� ��� �������� � �������� �����
function ensureDirectoryExists(path)
    if not doesDirectoryExist(path) then
        createDirectory(path)
    end
end


-- ������� ��� �������� � �������� stats.ini
function loadStats()
    ensureDirectoryExists(stats_folder) -- ������� �����, ���� �� ���

    local stats = inicfg.load(nil, stats_path)
    if not stats then
        stats = {Stats = {firesToday = 0, lastResetDay = os.date("%d")}}
        inicfg.save(stats, stats_path)
    end
    return stats
end

-- Telegram-���
local chat_id = '-4622362493'
local token = '7203823667:AAHBNeCxjQUEsZTWfB-e0eJ87D5imUu4ccE'

local lastNotificationTime = 0
local notificationCooldown = 30
local notificationSent = {}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("update", cmd_update)

    checkForUpdates() -- �������� ���������� ��� �������

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
        "���������� ������� �� �������:\n\n" ..
        "����� �������: {FFFFFF}%d\n\n" ..
        "1-� �������: {33CC33}%d{FFFFFF}\n" ..  -- ������, ����� ������� �����
        "2-� �������: {FFFF00}%d{FFFFFF}\n" ..  -- Ƹ����, ����� ������� �����
        "3-� �������: {FF3333}%d{FFFFFF}",      -- �������, ����� ������� �����
        total, lvl1, lvl2, lvl3
    )

    sampShowDialog(1, "���������� �������", message, "�������", "", 0)
end

sampRegisterChatCommand("fdstats", cmd_fdstats)
        while true do
    local currentTime = os.time()
    local currentHour = tonumber(os.date("%H", currentTime))
    local currentDate = tonumber(os.date("%d", currentTime)) -- �������� ������� ����

    -- �������� �� ����� ���
    if lastNotificationTime ~= 0 then
        local lastDate = tonumber(os.date("%d", lastNotificationTime))
        if lastDate ~= currentDate then
            notificationSent = {} -- ���������� ������ ������������ �����������
        end
    end

    -- ���������, ��� ������ �� ������� 22:00
    if currentHour >= 10 and currentHour < 22 then
        checkFireAlert() -- �������� � �������� ��������������
    elseif currentHour == 22 and not notificationSent["end_of_day"] then
        sendTelegramNotification("�� ������� ������ ���������. ���� ������� �� �������!")
        notificationSent["end_of_day"] = true
    end

    wait(1000)
end
    end
end

-- �������� ���������� ����� HTTP-������
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
            sampAddChatMessage("�������� ����������! ������: " .. ini.info.vers, -1)
            update_available = true
        end
        os.remove(update_ini_path)
    else
        sampAddChatMessage("������ �������� ����������!", -1)
    end
end

-- ������� ����������
function cmd_update()
    if update_available then
        sampAddChatMessage("���������� ����� ������...", -1)

        lua_thread.create(function() -- ��������� �����, ����� �������� ������ � `wait()`
            local response, status = http.request(script_url)
            if status == 200 and response then
                local scriptFile = io.open(script_path, "w")
                if scriptFile then
                    scriptFile:write(response)
                    scriptFile:close()
                    sampAddChatMessage("���������� ���������! ����������...", -1)
                    script_reload() -- ���������� �������
                end
            else
                sampAddChatMessage("������ �������� ����������!", -1)
            end
        end)
    else
        sampAddChatMessage("� ��� ��� ��������� ������.", -1)
    end
end

-- ������� ����������� ������� � �������� ��������
function script_reload()
    lua_thread.create(function()
        sampAddChatMessage("���������� ������� ����� 3 �������!", -1)
        wait(1000)
        sampAddChatMessage("3...", -1)
        wait(1000)
        sampAddChatMessage("2...", -1)
        wait(1000)
        sampAddChatMessage("1...", -1)
        wait(500)
        sampAddChatMessage("����������...", -1)
        thisScript():reload() -- ���������� �������
    end)
end

local fireCooldown = 2700 -- 45 ����� � ��������
local lastFireTime = 0
local fireMessageCount = 0

-- �������� ����������� � ������ �����������
function sendTelegramNotification(msg)
    msg = msg:gsub('{......}', '') -- ������� �� ������ ��������
    msg = u8:encode(msg, 'CP1251')

    local currentTime = os.time()

    -- ���� ������ ������ 45 ����� � ���������� ������, ���������� ������� ���������
    if currentTime - lastFireTime >= fireCooldown then
        fireMessageCount = 0
        lastFireTime = currentTime
    end

    -- �����������: �������� 2 ��������� �� �����
    if fireMessageCount < 2 then
        fireMessageCount = fireMessageCount + 1

        local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
                                  token, chat_id, msg)

        lua_thread.create(function()
            local response, status = http.request(url)
            if status ~= 200 then
                sampAddChatMessage("������ �������� ����������� � Telegram!", -1)
            else
                lastNotificationTime = os.time()
            end
        end)
    else
        sampAddChatMessage("��������� ����� ��������� ��� ����� ������.", -1)
    end
end

 function updateFireStats(level)
    local stats = loadStats()
    local currentDay = os.date("%d")

    -- ���������� ����������, ���� ���� ��������
    if tonumber(stats.Stats.lastResetDay) ~= tonumber(currentDay) then
        stats.Stats.firesToday = 0
        stats.Stats.fires_lvl_1 = 0
        stats.Stats.fires_lvl_2 = 0
        stats.Stats.fires_lvl_3 = 0
        stats.Stats.lastResetDay = currentDay
    end

    -- ����������� ����� �������
    stats.Stats.firesToday = stats.Stats.firesToday + 1

    -- ����������� ������� ��� ����������� ������
    if level == 1 then
        stats.Stats.fires_lvl_1 = stats.Stats.fires_lvl_1 + 1
    elseif level == 2 then
        stats.Stats.fires_lvl_2 = stats.Stats.fires_lvl_2 + 1
    elseif level == 3 then
        stats.Stats.fires_lvl_3 = stats.Stats.fires_lvl_3 + 1
    end

    inicfg.save(stats, stats_path)
end
-- ���������� ��������� ������� ����� 22:00
function sampev.onServerMessage(color, text)
    local currentTime = os.time()
    local currentHour = tonumber(os.date("%H", currentTime))

    if currentHour < 22 then
        local level = text:match("(%d)%-� �������") -- ���� "1-� �������", "2-� �������", "3-� �������"
        if level and tonumber(level) and tonumber(level) >= 1 and tonumber(level) <= 3 then
            if os.time() - lastNotificationTime >= notificationCooldown and not notificationSent["degree_" .. level] then
                sendTelegramNotification(string.format(" ����� %d-� �������! ������ � ����!", tonumber(level)))
                updateFireStats(tonumber(level)) -- ��������� ����������
                lastNotificationTime = os.time()
                notificationSent["degree_" .. level] = true
            end
        end
    end
end

function getMoscowTime()
    local utcTime = os.time(os.date("!*t")) -- �������� UTC
    return os.date("*t", utcTime + 3 * 3600) -- ��������� 3 ���� (���)
end

-- �������� ������� ��� �������� �������������� � ������
function checkFireAlert()
    local currentTime = getMoscowTime()
    local fireTimes = {5, 25, 45} -- �������, ����� ���������� ������

    for _, fireMinute in ipairs(fireTimes) do
        if currentTime.min == (fireMinute - 5) and not notificationSent[currentTime.hour .. ":" .. fireMinute] then
            sendTelegramNotification(string.format("����� 5 ����� ����� � %02d:%02d �� ���! ������ � ����!", currentTime.hour, fireMinute))
            notificationSent[currentTime.hour .. ":" .. fireMinute] = true
        end
    end
end

-- ���������� ��������� ������� ����� 22:00 (�� ���)
function sampev.onServerMessage(color, text)
    local currentTime = getMoscowTime()
    local currentHour = currentTime.hour

    if currentHour < 22 then
        local level = text:match("(%d)%-� �������")
        if level and tonumber(level) and tonumber(level) >= 1 and tonumber(level) <= 3 then
            if os.time() - lastNotificationTime >= notificationCooldown and not notificationSent["degree_" .. level] then
                sendTelegramNotification(string.format("����� %d-� �������! ������ � ����!", tonumber(level)))
                lastNotificationTime = os.time()
                notificationSent["degree_" .. level] = true
            end
        end
    end
end