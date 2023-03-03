local Debug           = false
local masterMute      = false
local isError         = false
local InitializeState = false

local controlPort      = 17300
local discoverPort     = 1900
local channelNameCount = 0
local initializeCount  = 0
local errorCounter     = 0
local ipCounter        = 0
local Discovery        = "M-SEARCH * HTTP/1.1\r\nHost: 239.255.255.250:1900\r\nST: urn:schemas-upnp-org:device:ATCUDevice:1\r\nMan: \"ssdp:discover\"\r\nMX: 3\r\n\r\n"
local muteState        = NamedControl.GetPosition("Mute")
local powerSaveState   = NamedControl.GetPosition("powerSave")
local IP               = NamedControl.GetText("IP")
local muteColor        = NamedControl.GetValue("muteColorList")
local unmuteColor      = NamedControl.GetValue("unMuteColorList")

local muteColorState   = nil
local unmuteColorState = nil

local channelNames    = {}
local outChannelNames = {}

local inMuteState = {
    [0] = NamedControl.GetPosition('Mute0'),
    [1] = NamedControl.GetPosition('Mute1'),
    [2] = NamedControl.GetPosition('Mute2'),
    [3] = NamedControl.GetPosition('Mute3'),
    [4] = NamedControl.GetPosition('Mute4'),
    [5] = NamedControl.GetPosition('Mute5')
}

local inFaderState = {
    Fader0 = NamedControl.GetValue("Fader0"),
    Fader1 = NamedControl.GetValue("Fader1"),
    Fader2 = NamedControl.GetValue("Fader2"),
    Fader3 = NamedControl.GetValue("Fader3"),
    Fader4 = NamedControl.GetValue("Fader4"),
    Fader5 = NamedControl.GetValue("Fader5")
}

local knobState = {
    Knob0 = NamedControl.GetValue("Knob0"),
    Knob1 = NamedControl.GetValue("Knob1"),
    Knob2 = NamedControl.GetValue("Knob2"),
    Knob3 = NamedControl.GetValue("Knob3"),
    Knob4 = NamedControl.GetValue("Knob4"),
    Knob5 = NamedControl.GetValue("Knob5")
}

local outMuteState = {
    Mute0 = NamedControl.GetPosition("getOutMute0"),
    Mute1 = NamedControl.GetPosition("getOutMute1")
}

local outFaderState = {
    Fader0 = NamedControl.GetValue("outFader0"),
    Fader1 = NamedControl.GetValue("outFader1")
}


function HandleData(socket, packet)

    if packet.Data:match("devdesc.xml") then
        ip = packet.Data:match("%d+%.%d+%.%d+%.%d+")
        NamedControl.SetText("IP", ip)
    end
end

function SetChannels(Chan, Name, response)

    Chan = tonumber(Chan)

    if response == "inChannel" then
        channelNames[Chan + 1] = Name
        for k, v in pairs(channelNames) do
            NamedControl.SetText("Channel" .. k, v)
        end
    elseif response == "outChannel" then
        outChannelNames[Chan + 1] = Name
        for k, v in pairs(outChannelNames) do
            NamedControl.SetText("outChannel" .. k, v)
        end
    end
end

function Split(s, delimiter, response)

    --if Debug then print(s, delimiter, response) end

    local result = {}

    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end

    if response == "inGain" then
        for i = 0, 6 do
            if tonumber(result[1]) == i then
                NamedControl.SetValue("Fader" .. i, result[4])
                NamedControl.SetValue("Knob" .. i, result[2])
                NamedControl.SetPosition("Mute" .. i, result[7])
            end
        end
    end

    if response == "outGain" then
        for i = 0, 1 do
            if tonumber(result[1]) == i then
                NamedControl.SetValue("outFader" .. i, result[2])
            end
        end
    end

    if response == "outMute" then
        for i = 0, 1 do
            if tonumber(result[1]) == i then
                NamedControl.SetValue("outMute" .. i, result[2])
            end
        end
    end
    return result
end

ButtonTable = {

    -- [0] = "s_mute S 0000 00 NC 1 \r",
    -- [1] = "s_mute S 0000 00 NC 0 \r",
    [2] = "g_mute O 0000 00 NC \r",
    [3] = "identify S 0000 00 NC \r",
    -- [4] = "s_powersave S 0000 00 NC 1 \r",
    -- [5] = "s_powersave S 0000 00 NC 0 \r",
    -- [6] = "CALLP S 0000 00 NC " .. string.format("%.0f", NamedControl.GetValue("presetList") + 1) .. " \r",
    [7] = "g_deviceid O 0000 00 NC \r",
    [8] = "g_network O 0000 00 NC \r",
    [9] = "reboot S 0000 00 NC \r"
}
local Buttons = {

    -- [0] = 'Mute',
    -- [1] = 'Unmute',
    [2] = 'getMute',
    [3] = 'Identify',
    -- [4] = 'powerSaveOn',
    -- [5] = 'powerSaveOff',
    [6] = 'Preset',
    [7] = 'getID',
    [8] = 'Network',
    [9] = 'Reboot',

    [20] = 'getGain',
    [21] = 'getChannel',
    [22] = 'getOutGain',
    [23] = 'getOutChannel',
    [24] = 'getOutMute',
    [25] = 'getLevel',

    [30] = 'Connect',
    [31] = 'Disconnect',
    [32] = 'Discover',
    [33] = 'sMute',
    [34] = 'setPreset'
}


function OnPress(Button)

    for k, v in pairs(ButtonTable) do
        if Button == k then
            sock:Write(v)
        end
    end

    for i = 0, 6 do
        if Button == 20 then
            sock:Write("g_input_gain_level O 0000 00 NC " .. i .. " \r")
        elseif Button == 21 then
            sock:Write("g_input_channel_settings O 0000 00 NC " .. i .. " \r")
        end
    end

    for i = 0, 1 do
        if Button == 22 then
            sock:Write("g_output_level O 0000 00 NC " .. i .. " \r")
        elseif Button == 23 then
            sock:Write("g_output_channel_settings O 0000 00 NC " .. i .. " \r")
        elseif Button == 24 then
            sock:Write("g_output_mute O 0000 00 NC " .. i .. " \r")
        end
    end

    if Button == 6 then
        sock:Write("CALLP S 0000 00 NC " .. string.format("%.0f", NamedControl.GetValue("presetList") + 1) .. " \r")
    elseif Button == 30 then
        sock:Connect(IP, controlPort)
    elseif Button == 31 then
        sock:Disconnect()
        Zero()
    elseif Button == 32 then
        MyUdp:Send("239.255.255.250", discoverPort, Discovery)
    elseif Button == 33 then
        sock:Write("g_mute O 0000 00 NC \r")
    elseif Button == 34 then
        sock:Write("save_preset S 0000 00 NC " .. string.format("%.0f", NamedControl.GetValue("presetList") + 1) .. " \r")
    end
end

function Initialize()

    if initializeCount == 0 then
        OnPress(20)
        initializeCount = initializeCount + 1
    elseif initializeCount == 1 then
        OnPress(21)
        initializeCount = initializeCount + 1

    elseif initializeCount == 2 then
        OnPress(22)
        initializeCount = initializeCount + 1

    elseif initializeCount == 3 then
        OnPress(23)
        initializeCount = initializeCount + 1

    elseif initializeCount == 4 then
        OnPress(24)
        initializeCount = initializeCount + 1

    elseif initializeCount == 5 then
        OnPress(7)
        initializeCount = initializeCount + 1
    elseif initializeCount == 6 then
        OnPress(33)
        InitializeState = true
    end

    for i = 1, 6 do
        NamedControl.SetText("Channel" .. i, "")
    end
end

function Mute()

    masterMute = true
    sock:Write("s_mute S 0000 00 NC 1 \r")
    for i = 0, 5 do
        NamedControl.SetPosition("Mute" .. i, 1)
        NamedControl.SetPosition("outMute" .. i, 1)
    end
end

function UnMute()
    sock:Write("s_mute S 0000 00 NC 0 \r")
    for i = 0, 5 do
        NamedControl.SetPosition("Mute" .. i, inMuteState[i])
        NamedControl.SetPosition("outMute" .. i, outMuteState[i])
    end
    masterMute = false
end

function Zero()

    sock:Disconnect()
    initializeCount = 0
    InitializeState = false
    for i = 0, 6 do
        NamedControl.SetValue("Fader" .. i, 0)
        NamedControl.SetValue("Knob" .. i, 0)
        NamedControl.SetPosition("Mute" .. i, 0)
        NamedControl.SetPosition("Mute" .. i, 0)
    end

    NamedControl.SetText("Channel1", "")
    NamedControl.SetText("Channel2", "")
    NamedControl.SetText("Channel3", "")
    NamedControl.SetText("Channel4", "")
    NamedControl.SetText("Channel5", "")
    NamedControl.SetText("Channel6", "")
    NamedControl.SetText("Channel7", "")
    NamedControl.SetText("outChannel1", "")
    NamedControl.SetText("outChannel2", "")
    NamedControl.SetText("ID", "")
    NamedControl.SetValue("outFader0", 0)
    NamedControl.SetValue("outFader1", 0)
    NamedControl.SetPosition("outMute0", 0)
    NamedControl.SetPosition("outMute1", 0)
    NamedControl.SetPosition("Mute", 0)
    -- NamedControl.SetText("IP", "")
    NamedControl.SetText("Error", "")

end

function TimerClick()
    if NamedControl.GetPosition("Send") == 1 then
        sock:Write("g_camera_control_interval O 0000 00 NC \r")
        NamedControl.SetPosition("Send", 0)
    end


    local muteColor   = NamedControl.GetValue("muteColorList")
    local unmuteColor = NamedControl.GetValue("unMuteColorList")

    channelNameCount = channelNameCount + 1
    ipCounter = ipCounter + 1

    IP = NamedControl.GetText("IP")

    if isError then
        errorCounter = errorCounter + 1
        if errorCounter == 8 then
            isError = false
            errorCounter = 0
            NamedControl.SetText("Error", "")
        end
    end
    if sock.IsConnected and InitializeState then
        NamedControl.SetValue("Connected", 1)
    else
        NamedControl.SetValue("Connected", 0)
    end

    for k, v in pairs(Buttons) do
        if NamedControl.GetPosition(v) == 1 then
            OnPress(k)
            NamedControl.SetPosition(v, 0)
        end
    end

    if NamedControl.GetPosition("Mute") ~= muteState then
        muteState = NamedControl.GetPosition("Mute")
        if muteState == 1 then
            Mute()
        elseif muteState == 0 then
            UnMute()
        end
    end

    if NamedControl.GetPosition("powerSave") ~= powerSaveState then
        powerSaveState = NamedControl.GetPosition("powerSave")
        if powerSaveState == 1 then
            sock:Write("s_powersave S 0000 00 NC 1 \r")
        elseif powerSaveState == 0 then
            sock:Write("s_powersave S 0000 00 NC 0 \r")
        end
    end

    for i = 0, 6 do
        if NamedControl.GetPosition("Mute" .. i) ~= inMuteState[i] and masterMute == false then
            inMuteState[i] = NamedControl.GetPosition("Mute" .. i)
            if inMuteState[i] == 1 then
                sock:Write("SICM S 0000 00 NC " .. i .. ",1" .. " \r")
            elseif inMuteState[i] == 0 then
                sock:Write("SICM S 0000 00 NC " .. i .. ",0" .. " \r")
            end
        end

        if NamedControl.GetValue("Fader" .. i) ~= inFaderState[i] then
            inFaderState[i] = NamedControl.GetValue("Fader" .. i)
            sock:Write("SICL S 0000 00 NC " .. i .. "," .. string.format("%.0f", inFaderState[i]) .. " \r")
        end

        if NamedControl.GetValue("Knob" .. i) ~= knobState[i] then
            knobState[i] = NamedControl.GetValue("Knob" .. i)
            sock:Write("s_input_gain_level S 0000 00 NC " .. i .. "," .. string.format("%.0f", knobState[i]) .. " \r")
        end
    end

    for i = 0, 1 do
        if NamedControl.GetValue("outFader" .. i) ~= outFaderState[i] then
            outFaderState[i] = NamedControl.GetValue("outFader" .. i)
            sock:Write("SOCL S 0000 00 NC " .. i .. "," .. string.format("%.0f", outFaderState[i]) .. " \r")
        elseif NamedControl.GetPosition("outMute" .. i) ~= outMuteState[i] and masterMute == false then
            outMuteState[i] = NamedControl.GetPosition("outMute" .. i)
            if outMuteState[i] == 1 then
                sock:Write("s_output_mute S 0000 00 NC " .. i .. ",1" .. " \r")
            elseif outMuteState[i] == 0 then
                sock:Write("s_output_mute S 0000 00 NC " .. i .. ",0" .. " \r")
            end
        end
    end

    if muteColorState ~= muteColor or unmuteColorState ~= unmuteColor then
        sock:Write("s_led S 0000 00 NC ,,," ..
            tostring(string.format("%.0f", NamedControl.GetValue("muteColorList"))) ..
            "," .. tostring(string.format("%.0f", NamedControl.GetValue("unMuteColorList")) .. " \r"))
        muteColorState = muteColor
        unmuteColorState = unmuteColor
    end

    if channelNameCount > 41 then
        channelNameCount = 0
    end

    if ipCounter > 41 then
        if sock.IsConnected == false then
            if NamedControl.GetText("IP") ~= "" then
                sock:Connect(IP, controlPort)
            end
        end
        ipCounter = 0
    end


end

MyTimer = Timer.New()
MyTimer.EventHandler = TimerClick
MyTimer:Start(.25)

MyUdp = UdpSocket.New()
MyUdp:Open(Device.LocalUnit.ControlIP, 0)
MyUdp.Data = HandleData



sock = TcpSocket.New()
sock.ReadTimeout = 7
sock.WriteTimeout = 0
sock.ReconnectTimeout = 1

sock.Connected = function(TcpSocket)

    --handle the new Connection
    print("socket connected\r")
    Initialize()
    isError = false
    NamedControl.SetText("Error", "")
end

sock.Reconnect = function(TcpSocket)

    --handle the Reconnection attempt
    print("socket reconnecting...\r")
end

sock.Data = function(TcpSocket, data)

    if InitializeState == false then
        Initialize()
    end
    rxLine = sock:ReadLine(1)
    if (nil ~= rxLine) then
        print(rxLine)
        --if Debug then print("Got:\r" .. rxLine) end
        if (rxLine:match('^g_input_channel_settings ')) then
            local Chan = rxLine:match(' (%d),')
            local Name = rxLine:match(',"([^"]+)",')
            SetChannels(Chan, Name, "inChannel")
            --if Debug then print(rxLine) end
        elseif rxLine:match("g_output_channel_settings 0000 00") then
            local outChannel = rxLine:match(' (%d),')
            local outName    = rxLine:match("%b\"\"")
            outName          = string.gsub(outName, "\"", "")
            print(outName)
            SetChannels(outChannel, outName, "outChannel")
            --if Debug then print(rxLine) end
        elseif rxLine:match("g_deviceid 0000 00 NC") then
            local Length = #rxLine
            local ID = string.sub(rxLine, Length - 2, Length)
            NamedControl.SetText("ID", "ID " .. tonumber("0x" .. ID))
            --if Debug then print(rxLine) end
        elseif rxLine:match("g_input_gain_level 0000 00 NC") then
            local inGain = rxLine:match(("%d+%,%d+%,%d+%,%d+%,,,%d"))
            Split(inGain, ",", "inGain")
            --if Debug then print(rxLine) end
        elseif rxLine:match("g_output_level 0000 00 NC") then
            local outGain = rxLine:match("%d%,%d+")
            Split(outGain, ",", "outGain")
            --if Debug then print(rxLine) end
        elseif rxLine:match("g_output_mute 0000 00 NC") then
            local outMute = rxLine:match("%d,%d")
            Split(outMute, ",", "outMute")
            --if Debug then print(rxLine) end
        elseif rxLine:match("g_mute 0000 00 NC 1") then
            NamedControl.SetPosition("Mute", 1)
        elseif rxLine:match("g_mute 0000 00 NC 0") then
            NamedControl.SetPosition("Mute", 0)
        end
    end
end

sock.Closed = function(TcpSocket)

    --handle the socket closing
    print("socket closed by remote\r")
end

sock.Error = function(TcpSocket, error)

    --handle the error
    print(string.format("Error: '%s'\r", error))
    if error ~= nil then
        NamedControl.SetText("Error", error)
        isError = true
    end
end

sock.Timeout = function(TcpSocket, error)

    --handle the Timeout
    print("socket closed due to timeout\r")
end
Zero()
