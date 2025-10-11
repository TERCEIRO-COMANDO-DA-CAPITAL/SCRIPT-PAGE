-- Carregar a biblioteca
local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/SrDark222/Mafia-hub-v1/refs/heads/main/mafia%20hub.lua"))()

-- Janela principal
local Window = redzlib:MakeWindow({
    Title = "MAFIA HUB - Trocar Tiro ☯️ ",
    SubTitle = "by menor DK",
    SaveFolder = "tcc_hub.lua"
})

-- Botão de minimizar
Window:AddMinimizeButton({
    Button = { Image = "rbxassetid://100971981026789", BackgroundTransparency = 0 },
    Corner = { CornerRadius = UDim.new(0.4, 1) }
})

-- Serviços do Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Tabela global para listas de jogadores e times
local GlobalLists = {
    PlayerList = {"Nenhum"},
    TeamList = {"Nenhum"}
}

-- Variáveis globais para configurações
local AimbotSettings = {
    Enabled = false,
    AimLockEnabled = false,
    TargetAny = true,
    Target = nil,
    Smoothness = 5.0,
    Predict = false,
    PredictFactor = 100,
    MaxDistance = 500,
    IgnoreTeam = false,
    IgnoreDead = true,
    VisibleOnly = true,
    LockPart = "Head",
    FOV = 200,
    CurrentTarget = nil,
    WhitelistPlayers = {},
    WhitelistTeams = {}
}

local ESPSettings = {
    Enabled = false,
    Names = false,
    Studs = false,
    Health = false,
    Boxes = true, -- Highlight ativado por padrão
    TeamColor = true,
    IgnoreTeam = false,
    EnemyColor = Color3.fromRGB(255, 0, 0),
    AllyColor = Color3.fromRGB(0, 255, 0),
    WhitelistPlayers = {},
    WhitelistTeams = {}
}

-- Tabela de cores fixas para dropdown
local Colors = {
    ["Vermelho"] = Color3.fromRGB(255, 0, 0),
    ["Azul"] = Color3.fromRGB(0, 0, 255),
    ["Verde"] = Color3.fromRGB(0, 255, 0),
    ["Amarelo"] = Color3.fromRGB(255, 255, 0),
    ["Branco"] = Color3.fromRGB(255, 255, 255),
    ["Roxo"] = Color3.fromRGB(128, 0, 128)
}

-- Função para atualizar listas globais
local function UpdateGlobalLists()
    GlobalLists.PlayerList = {"Nenhum"}
    GlobalLists.TeamList = {"Nenhum"}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(GlobalLists.PlayerList, player.Name)
        end
    end
    
    for _, team in ipairs(game:GetService("Teams"):GetChildren()) do
        table.insert(GlobalLists.TeamList, team.Name)
    end
end

-- Funções auxiliares
local function IsAlive(character)
    local humanoid = character and character:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function IsTeamMate(player)
    return player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
end

local function IsInWhitelist(player, whitelistPlayers, whitelistTeams)
    if table.find(whitelistPlayers, player.Name) then return true end
    if player.Team and table.find(whitelistTeams, player.Team.Name) then return true end
    return false
end

local function IsVisible(targetPart)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.IgnoreWater = true
    local rayResult = Workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * AimbotSettings.MaxDistance, params)
    return rayResult and rayResult.Instance:IsDescendantOf(targetPart.Parent)
end

local function GetClosestPlayer()
    local closest, minDist = nil, math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not IsInWhitelist(player, AimbotSettings.WhitelistPlayers, AimbotSettings.WhitelistTeams) then
            if not AimbotSettings.IgnoreTeam or not IsTeamMate(player) then
                local character = player.Character
                if character then
                    local alive = IsAlive(character)
                    if not AimbotSettings.IgnoreDead or alive then
                        local part = character:FindFirstChild(AimbotSettings.LockPart)
                        if part then
                            local dist = (part.Position - Camera.CFrame.Position).Magnitude
                            if dist <= AimbotSettings.MaxDistance then
                                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                                if onScreen then
                                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                                    if screenDist < AimbotSettings.FOV and screenDist < minDist and (not AimbotSettings.VisibleOnly or IsVisible(part)) then
                                        if AimbotSettings.TargetAny or (not AimbotSettings.TargetAny and player.Name == AimbotSettings.Target) then
                                            closest = part
                                            minDist = screenDist
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function IsValidTarget(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local character = targetPart.Parent
    local player = Players:GetPlayerFromCharacter(character)
    if not player or player == LocalPlayer then return false end
    if IsInWhitelist(player, AimbotSettings.WhitelistPlayers, AimbotSettings.WhitelistTeams) then return false end
    if AimbotSettings.IgnoreTeam and IsTeamMate(player) then return false end
    if AimbotSettings.IgnoreDead and not IsAlive(character) then return false end
    if AimbotSettings.VisibleOnly and not IsVisible(targetPart) then return false end
    local dist = (targetPart.Position - Camera.CFrame.Position).Magnitude
    if dist > AimbotSettings.MaxDistance then return false end
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
    return screenDist < AimbotSettings.FOV
end

-- Conexão para Aimbot Suave
local AimbotConnection
local function ToggleAimbot(enabled)
    if enabled then
        if AimbotSettings.AimLockEnabled then
            AimbotSettings.AimLockEnabled = false
        end
        AimbotConnection = RunService.RenderStepped:Connect(function(delta)
            if AimbotSettings.CurrentTarget and not IsValidTarget(AimbotSettings.CurrentTarget) then
                AimbotSettings.CurrentTarget = nil
            end
            
            if not AimbotSettings.CurrentTarget then
                AimbotSettings.CurrentTarget = GetClosestPlayer()
            end
            
            if AimbotSettings.CurrentTarget then
                local targetPos = AimbotSettings.CurrentTarget.Position
                if AimbotSettings.Predict then
                    local root = AimbotSettings.CurrentTarget.Parent:FindFirstChild("HumanoidRootPart")
                    if root and root.Velocity.Magnitude > 0 then
                        local dist = (AimbotSettings.CurrentTarget.Position - Camera.CFrame.Position).Magnitude
                        targetPos = targetPos + root.Velocity * (dist / root.Velocity.Magnitude) * (AimbotSettings.PredictFactor / 1000)
                    end
                end
                local newCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                Camera.CFrame = Camera.CFrame:Lerp(newCFrame, 0.2)
            end
        end)
    else
        if AimbotConnection then
            AimbotConnection:Disconnect()
            AimbotConnection = nil
        end
        AimbotSettings.CurrentTarget = nil
    end
end

-- Conexão para Aim Lock Fixo
local AimLockConnection
local function ToggleAimLock(enabled)
    if enabled then
        if AimbotSettings.Enabled then
            AimbotSettings.Enabled = false
        end
        AimLockConnection = RunService.RenderStepped:Connect(function(delta)
            if AimbotSettings.CurrentTarget and not IsValidTarget(AimbotSettings.CurrentTarget) then
                AimbotSettings.CurrentTarget = nil
            end
            
            if not AimbotSettings.CurrentTarget then
                AimbotSettings.CurrentTarget = GetClosestPlayer()
            end
            
            if AimbotSettings.CurrentTarget then
                local targetPos = AimbotSettings.CurrentTarget.Position
                if AimbotSettings.Predict then
                    local root = AimbotSettings.CurrentTarget.Parent:FindFirstChild("HumanoidRootPart")
                    if root and root.Velocity.Magnitude > 0 then
                        local dist = (AimbotSettings.CurrentTarget.Position - Camera.CFrame.Position).Magnitude
                        targetPos = targetPos + root.Velocity * (dist / root.Velocity.Magnitude) * (AimbotSettings.PredictFactor / 1000)
                    end
                end
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
            end
        end)
    else
        if AimLockConnection then
            AimLockConnection:Disconnect()
            AimLockConnection = nil
        end
        AimbotSettings.CurrentTarget = nil
    end
end

-- Tabela para ESP Highlights
local ESPHighlights = {}

local function CreateESP(player)
    if not player then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    highlight.Enabled = false
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = player.Character or player.CharacterAdded:Wait()
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPBillboard"
    billboard.Adornee = player.Character and player.Character:FindFirstChild("Head")
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextScaled = true
    nameLabel.Parent = billboard
    
    local studsLabel = Instance.new("TextLabel")
    studsLabel.Size = UDim2.new(1, 0, 0.5, 0)
    studsLabel.Position = UDim2.new(0, 0, 0.5, 0)
    studsLabel.BackgroundTransparency = 1
    studsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    studsLabel.TextStrokeTransparency = 0
    studsLabel.TextScaled = true
    studsLabel.Parent = billboard
    
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(1, 0, 0.2, 0)
    healthBar.Position = UDim2.new(0, 0, 0.8, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Visible = false
    healthBar.Parent = billboard
    
    billboard.Parent = player.Character or player.CharacterAdded:Wait()
    
    ESPHighlights[player] = { Highlight = highlight, Billboard = billboard, NameLabel = nameLabel, StudsLabel = studsLabel, HealthBar = healthBar }
end

local function UpdateESP()
    for player, esp in pairs(ESPHighlights) do
        local character = player.Character
        if ESPSettings.Enabled and character and not IsInWhitelist(player, ESPSettings.WhitelistPlayers, ESPSettings.WhitelistTeams) then
            if not ESPSettings.IgnoreTeam or not IsTeamMate(player) then
                local alive = IsAlive(character)
                if alive or not ESPSettings.IgnoreDead then
                    local root = character:FindFirstChild("HumanoidRootPart")
                    local head = character:FindFirstChild("Head")
                    local humanoid = character:FindFirstChild("Humanoid")
                    if root and head then
                        local dist = (root.Position - Camera.CFrame.Position).Magnitude
                        local color = ESPSettings.TeamColor and (IsTeamMate(player) and (player.TeamColor and player.TeamColor.Color or ESPSettings.AllyColor) or ESPSettings.EnemyColor) or (IsTeamMate(player) and ESPSettings.AllyColor or ESPSettings.EnemyColor)
                        
                        esp.Highlight.Adornee = character
                        esp.Highlight.FillColor = color
                        esp.Highlight.OutlineColor = color
                        esp.Highlight.Enabled = ESPSettings.Boxes
                        
                        esp.Billboard.Adornee = head
                        if ESPSettings.Names then
                            esp.NameLabel.Text = player.Name
                            esp.NameLabel.TextColor3 = color
                            esp.NameLabel.Visible = true
                        else
                            esp.NameLabel.Visible = false
                        end
                        
                        if ESPSettings.Studs then
                            esp.StudsLabel.Text = math.floor(dist) .. " studs"
                            esp.StudsLabel.TextColor3 = color
                            esp.StudsLabel.Visible = true
                        else
                            esp.StudsLabel.Visible = false
                        end
                        
                        if ESPSettings.Health and humanoid then
                            local healthPercent = humanoid.Health / humanoid.MaxHealth
                            esp.HealthBar.Size = UDim2.new(healthPercent, 0, 0.2, 0)
                            esp.HealthBar.BackgroundColor3 = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                            esp.HealthBar.Visible = true
                        else
                            esp.HealthBar.Visible = false
                        end
                        
                        esp.Billboard.Enabled = ESPSettings.Names or ESPSettings.Studs or ESPSettings.Health
                    else
                        esp.Highlight.Enabled = false
                        esp.Billboard.Enabled = false
                    end
                else
                    esp.Highlight.Enabled = false
                    esp.Billboard.Enabled = false
                end
            else
                esp.Highlight.Enabled = false
                esp.Billboard.Enabled = false
            end
        else
            esp.Highlight.Enabled = false
            esp.Billboard.Enabled = false
        end
    end
end

-- Conexão para ESP
local ESPConnection
local function ToggleESP(enabled)
    ESPSettings.Enabled = enabled
    if enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
        Players.PlayerAdded:Connect(function(player)
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end)
        ESPConnection = RunService.RenderStepped:Connect(UpdateESP)
    else
        if ESPConnection then
            ESPConnection:Disconnect()
            ESPConnection = nil
        end
        for _, esp in pairs(ESPHighlights) do
            esp.Highlight:Destroy()
            esp.Billboard:Destroy()
        end
        ESPHighlights = {}
    end
end

-- Aba 1: Aimbot
local Tab1 = Window:MakeTab({"Aimbot", "crosshair"})
Window:SelectTab(Tab1)

-- Seção Seleção de Alvo
local SectionAimbotTarget = Tab1:AddSection({"Seleção de Alvo"})

-- Toggle para "Qualquer um"
Tab1:AddToggle({
    Name = "Mirar em Qualquer Um",
    Description = "Mirar em qualquer jogador (desative para selecionar um jogador específico)",
    Default = true,
    Icon = "rbxassetid://10734920149",
    Callback = function(Value)
        AimbotSettings.TargetAny = Value
        AimbotSettings.CurrentTarget = nil
        print("Mirar em Qualquer Um " .. (Value and "ativado" or "desativado"))
    end
})

-- Dropdown para selecionar o jogador alvo
local AimbotDropdown = Tab1:AddDropdown({
    Name = "Jogador Alvo Específico",
    Description = "Selecione um jogador específico para mirar",
    Options = GlobalLists.PlayerList,
    Default = "Nenhum",
    Icon = "rbxassetid://10734920149",
    Flag = "aimbot_target",
    Callback = function(Value)
        if not AimbotSettings.TargetAny then
            AimbotSettings.Target = Value
            AimbotSettings.CurrentTarget = nil
            print("Jogador alvo selecionado: " .. Value)
        end
    end
})

-- Botão para atualizar jogadores
Tab1:AddButton({
    Name = "Atualizar Jogadores",
    Icon = "rbxassetid://10734933056",
    Callback = function()
        UpdateGlobalLists()
        local methods = {
            function() if AimbotDropdown.Clear and AimbotDropdown.Add then AimbotDropdown:Clear() for _, v in ipairs(GlobalLists.PlayerList) do AimbotDropdown:Add(v) end end end,
            function() if AimbotDropdown.SetOptions then AimbotDropdown:SetOptions(GlobalLists.PlayerList) end end,
            function() if AimbotDropdown.Update then AimbotDropdown:Update(GlobalLists.PlayerList) end end,
            function() if AimbotDropdown.Set then AimbotDropdown:Set(GlobalLists.PlayerList) end end,
            function() AimbotDropdown.Options = GlobalLists.PlayerList if AimbotDropdown.Refresh then AimbotDropdown:Refresh() end end
        }
        for _, func in ipairs(methods) do pcall(func) end
        print("Lista de jogadores atualizada: " .. table.concat(GlobalLists.PlayerList, ", "))
    end
})

-- Seção Modos de Aimbot
local SectionAimbotModes = Tab1:AddSection({"Modos de Aimbot"})

-- Toggle para Aimbot Suave
Tab1:AddToggle({
    Name = "Aimbot Suave",
    Description = "Ativa aimbot com suavidade ajustável",
    Default = false,
    Icon = "rbxassetid://10734977012",
    Callback = function(Value)
        AimbotSettings.Enabled = Value
        ToggleAimbot(Value)
        if Value then
            AimbotSettings.AimLockEnabled = false
        end
        print("Aimbot Suave " .. (Value and "ativado" or "desativado"))
    end
})

-- Toggle para Aim Lock Fixo
Tab1:AddToggle({
    Name = "Aim Lock Fixo",
    Description = "Mira fixo instantaneamente",
    Default = false,
    Icon = "rbxassetid://10734977012",
    Callback = function(Value)
        AimbotSettings.AimLockEnabled = Value
        ToggleAimLock(Value)
        if Value then
            AimbotSettings.Enabled = false
        end
        print("Aim Lock Fixo " .. (Value and "ativado" or "desativado"))
    end
})

-- Seção Ajustes do Aimbot
local SectionAimbotAdjust = Tab1:AddSection({"Ajustes"})

-- Dropdown para parte do corpo
Tab1:AddDropdown({
    Name = "Parte do Corpo",
    Description = "Parte para mirar",
    Options = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"},
    Default = "Head",
    Icon = "rbxassetid://10734920149",
    Callback = function(Value)
        AimbotSettings.LockPart = Value
        AimbotSettings.CurrentTarget = nil
        print("Parte do corpo: " .. Value)
    end
})

-- Slider para suavidade
Tab1:AddSlider({
    Name = "Suavidade",
    Description = "Quanto maior, mais suave (para Aimbot Suave)",
    Min = 1,
    Max = 10,
    Increase = 0.5,
    Default = 5.0,
    Icon = "rbxassetid://10734963400",
    Callback = function(Value)
        AimbotSettings.Smoothness = Value
        print("Suavidade ajustada para: " .. Value)
    end
})

-- Slider para distância máxima
Tab1:AddSlider({
    Name = "Distância Máxima",
    Description = "Distância em studs",
    Min = 10,
    Max = 2000,
    Increase = 50,
    Default = 500,
    Icon = "rbxassetid://10734941018",
    Callback = function(Value)
        AimbotSettings.MaxDistance = Value
        print("Distância ajustada para: " .. Value)
    end
})

-- Slider para FOV
Tab1:AddSlider({
    Name = "Campo de Detecção (FOV)",
    Description = "Raio de detecção em pixels (não altera FOV da câmera)",
    Min = 50,
    Max = 500,
    Increase = 10,
    Default = 200,
    Icon = "rbxassetid://10723377537",
    Callback = function(Value)
        AimbotSettings.FOV = Value
        AimbotSettings.CurrentTarget = nil
        print("FOV de detecção ajustado para: " .. Value)
    end
})

-- Seção Previsão de Movimento
local SectionAimbotPrediction = Tab1:AddSection({"Previsão de Movimento"})

-- Toggle para previsão
Tab1:AddToggle({
    Name = "Previsão de Movimento",
    Description = "Prever movimento do alvo",
    Default = false,
    Icon = "rbxassetid://10734934585",
    Callback = function(Value)
        AimbotSettings.Predict = Value
        print("Previsão " .. (Value and "ativada" or "desativada"))
    end
})

-- Slider para fator de previsão
Tab1:AddSlider({
    Name = "Fator de Previsão",
    Description = "Ajusta a intensidade da previsão (0 a 200)",
    Min = 0,
    Max = 200,
    Increase = 10,
    Default = 100,
    Icon = "rbxassetid://10734934585",
    Callback = function(Value)
        AimbotSettings.PredictFactor = Value
        print("Fator de previsão ajustado para: " .. Value)
    end
})

-- Seção Filtros do Aimbot
local SectionAimbotFilters = Tab1:AddSection({"Filtros"})

-- Toggle ignorar time
Tab1:AddToggle({
    Name = "Ignorar Time",
    Description = "Não mirar em aliados",
    Default = false,
    Icon = "rbxassetid://10747373426",
    Callback = function(Value)
        AimbotSettings.IgnoreTeam = Value
        AimbotSettings.CurrentTarget = nil
        print("Ignorar Time " .. (Value and "ativado" or "desativado"))
    end
})

-- Toggle ignorar mortos
Tab1:AddToggle({
    Name = "Ignorar Mortos",
    Description = "Não mirar em mortos",
    Default = true,
    Icon = "rbxassetid://10734962068",
    Callback = function(Value)
        AimbotSettings.IgnoreDead = Value
        AimbotSettings.CurrentTarget = nil
        print("Ignorar Mortos " .. (Value and "ativado" or "desativado"))
    end
})

-- Toggle alvos visíveis
Tab1:AddToggle({
    Name = "Apenas Visíveis",
    Description = "Mirar apenas se visível (sem paredes)",
    Default = true,
    Icon = "rbxassetid://10747375132",
    Callback = function(Value)
        AimbotSettings.VisibleOnly = Value
        AimbotSettings.CurrentTarget = nil
        print("Apenas Visíveis " .. (Value and "ativado" or "desativado"))
    end
})

-- Seção Whitelist de Jogadores (Aimbot)
local SectionAimbotWhitelistPlayers = Tab1:AddSection({"Whitelist - Jogadores"})

-- Dropdown para selecionar jogador para adicionar à whitelist
local WhitelistAimbotPlayerDropdown = Tab1:AddDropdown({
    Name = "Selecionar Jogador",
    Description = "Selecione um jogador para adicionar à whitelist",
    Options = GlobalLists.PlayerList,
    Default = "Nenhum",
    Icon = "rbxassetid://10734920149",
    Flag = "aimbot_whitelist_player_select",
    Callback = function(Value) end
})

-- Botão para adicionar jogador à whitelist
Tab1:AddButton({
    Name = "Adicionar Jogador à Whitelist",
    Icon = "rbxassetid://10734920149",
    Callback = function()
        local playerValue = WhitelistAimbotPlayerDropdown:Get()
        if playerValue ~= "Nenhum" and not table.find(AimbotSettings.WhitelistPlayers, playerValue) then
            table.insert(AimbotSettings.WhitelistPlayers, playerValue)
            AimbotSettings.CurrentTarget = nil
            print("Jogador adicionado à whitelist do aimbot: " .. playerValue)
            UpdateDropdowns() -- Atualizar dropdowns após adição
        end
    end
})

-- Dropdown para remover jogador da whitelist
local WhitelistAimbotPlayerRemoveDropdown = Tab1:AddDropdown({
    Name = "Remover Jogador da Whitelist",
    Description = "Selecione um jogador para remover da whitelist",
    Options = AimbotSettings.WhitelistPlayers,
    Default = "Nenhum",
    Icon = "rbxassetid://10734920149",
    Flag = "aimbot_whitelist_player_remove",
    Callback = function(Value)
        if Value ~= "Nenhum" then
            for i, name in ipairs(AimbotSettings.WhitelistPlayers) do
                if name == Value then
                    table.remove(AimbotSettings.WhitelistPlayers, i)
                    AimbotSettings.CurrentTarget = nil
                    print("Jogador removido da whitelist do aimbot: " .. Value)
                    UpdateDropdowns() -- Atualizar dropdowns após remoção
                    break
                end
            end
        end
    end
})

-- Seção Whitelist de Times (Aimbot)
local SectionAimbotWhitelistTeams = Tab1:AddSection({"Whitelist - Times"})

-- Dropdown para selecionar time para adicionar à whitelist
local WhitelistAimbotTeamDropdown = Tab1:AddDropdown({
    Name = "Selecionar Time",
    Description = "Selecione um time para adicionar à whitelist",
    Options = GlobalLists.TeamList,
    Default = "Nenhum",
    Icon = "rbxassetid://10747373426",
    Flag = "aimbot_whitelist_team_select",
    Callback = function(Value) end
})

-- Botão para adicionar time à whitelist
Tab1:AddButton({
    Name = "Adicionar Time à Whitelist",
    Icon = "rbxassetid://10747373426",
    Callback = function()
        local teamValue = WhitelistAimbotTeamDropdown:Get()
        if teamValue ~= "Nenhum" and not table.find(AimbotSettings.WhitelistTeams, teamValue) then
            table.insert(AimbotSettings.WhitelistTeams, teamValue)
            AimbotSettings.CurrentTarget = nil
            print("Time adicionado à whitelist do aimbot: " .. teamValue)
            UpdateDropdowns() -- Atualizar dropdowns após adição
        end
    end
})

-- Dropdown para remover time da whitelist
local WhitelistAimbotTeamRemoveDropdown = Tab1:AddDropdown({
    Name = "Remover Time da Whitelist",
    Description = "Selecione um time para remover da whitelist",
    Options = AimbotSettings.WhitelistTeams,
    Default = "Nenhum",
    Icon = "rbxassetid://10747373426",
    Flag = "aimbot_whitelist_team_remove",
    Callback = function(Value)
        if Value ~= "Nenhum" then
            for i, name in ipairs(AimbotSettings.WhitelistTeams) do
                if name == Value then
                    table.remove(AimbotSettings.WhitelistTeams, i)
                    AimbotSettings.CurrentTarget = nil
                    print("Time removido da whitelist do aimbot: " .. Value)
                    UpdateDropdowns() -- Atualizar dropdowns após remoção
                    break
                end
            end
        end
    end
})

-- Aba 2: ESP
local Tab2 = Window:MakeTab({"ESP", "eye"})

-- Seção Geral do ESP
local SectionESPGeneral = Tab2:AddSection({"Geral"})

-- Toggle ESP
Tab2:AddToggle({
    Name = "Ativar ESP",
    Description = "Ativa ESP global (usando Highlight)",
    Default = false,
    Icon = "rbxassetid://10747375132",
    Callback = function(Value)
        ToggleESP(Value)
        print("ESP " .. (Value and "ativado" or "desativado"))
    end
})

-- Seção Visual do ESP
local SectionESPVisual = Tab2:AddSection({"Visual"})

-- Toggle Nome
Tab2:AddToggle({
    Name = "Nomes",
    Description = "Mostrar nomes",
    Default = false,
    Icon = "rbxassetid://10734976528",
    Callback = function(Value)
        ESPSettings.Names = Value
        print("Nomes " .. (Value and "ativados" or "desativados"))
    end
})

-- Toggle Studs
Tab2:AddToggle({
    Name = "Distância (Studs)",
    Description = "Mostrar distância",
    Default = false,
    Icon = "rbxassetid://10734941018",
    Callback = function(Value)
        ESPSettings.Studs = Value
        print("Studs " .. (Value and "ativados" or "desativados"))
    end
})

-- Toggle Health
Tab2:AddToggle({
    Name = "Barra de Vida",
    Description = "Mostrar barra de vida dos jogadores",
    Default = false,
    Icon = "rbxassetid://10734962068",
    Callback = function(Value)
        ESPSettings.Health = Value
        print("Barra de Vida " .. (Value and "ativada" or "desativada"))
    end
})

-- Toggle Boxes (Highlight)
Tab2:AddToggle({
    Name = "Highlight (Boxes)",
    Description = "Ativa Highlight ao redor dos jogadores",
    Default = true,
    Icon = "rbxassetid://10734965702",
    Callback = function(Value)
        ESPSettings.Boxes = Value
        print("Highlight " .. (Value and "ativado" or "desativado"))
    end
})

-- Seção Filtros do ESP
local SectionESPFilters = Tab2:AddSection({"Filtros"})

-- Toggle Team Color
Tab2:AddToggle({
    Name = "Cores de Time",
    Description = "Usar cores do time",
    Default = true,
    Icon = "rbxassetid://10734910430",
    Callback = function(Value)
        ESPSettings.TeamColor = Value
        print("Cores de Time " .. (Value and "ativadas" or "desativadas"))
    end
})

-- Toggle Ignorar Time
Tab2:AddToggle({
    Name = "Ignorar Time",
    Description = "Não mostrar aliados",
    Default = false,
    Icon = "rbxassetid://10747373426",
    Callback = function(Value)
        ESPSettings.IgnoreTeam = Value
        print("Ignorar Time " .. (Value and "ativado" or "desativado"))
    end
})

-- Seção Cores do ESP
local SectionESPCores = Tab2:AddSection({"Cores Personalizadas"})

-- Dropdown Cor Inimigos
Tab2:AddDropdown({
    Name = "Cor Inimigos",
    Description = "Cor para inimigos (se não usar team color)",
    Options = {"Vermelho", "Azul", "Verde", "Amarelo", "Branco"},
    Default = "Vermelho",
    Icon = "rbxassetid://10734910430",
    Flag = "enemy_color",
    Callback = function(Value)
        ESPSettings.EnemyColor = Colors[Value]
        print("Cor Inimigos: " .. Value)
    end
})

-- Dropdown Cor Aliados
Tab2:AddDropdown({
    Name = "Cor Aliados",
    Description = "Cor para aliados (se não usar team color)",
    Options = {"Verde", "Azul", "Amarelo", "Branco", "Roxo"},
    Default = "Verde",
    Icon = "rbxassetid://10734910430",
    Flag = "ally_color",
    Callback = function(Value)
        ESPSettings.AllyColor = Colors[Value]
        print("Cor Aliados: " .. Value)
    end
})

-- Seção Whitelist de Jogadores (ESP)
local SectionESPWhitelistPlayers = Tab2:AddSection({"Whitelist - Jogadores"})

-- Dropdown para selecionar jogador para adicionar à whitelist
local WhitelistESPPlayerDropdown = Tab2:AddDropdown({
    Name = "Selecionar Jogador",
    Description = "Selecione um jogador para adicionar à whitelist",
    Options = GlobalLists.PlayerList,
    Default = "Nenhum",
    Icon = "rbxassetid://10734920149",
    Flag = "esp_whitelist_player_select",
    Callback = function(Value) end
})

-- Botão para adicionar jogador à whitelist
Tab2:AddButton({
    Name = "Adicionar Jogador à Whitelist",
    Icon = "rbxassetid://10734920149",
    Callback = function()
        local playerValue = WhitelistESPPlayerDropdown:Get()
        if playerValue ~= "Nenhum" and not table.find(ESPSettings.WhitelistPlayers, playerValue) then
            table.insert(ESPSettings.WhitelistPlayers, playerValue)
            print("Jogador adicionado à whitelist do ESP: " .. playerValue)
            UpdateDropdowns() -- Atualizar dropdowns após adição
        end
    end
})

-- Dropdown para remover jogador da whitelist
local WhitelistESPPlayerRemoveDropdown = Tab2:AddDropdown({
    Name = "Remover Jogador da Whitelist",
    Description = "Selecione um jogador para remover da whitelist",
    Options = ESPSettings.WhitelistPlayers,
    Default = "Nenhum",
    Icon = "rbxassetid://10734920149",
    Flag = "esp_whitelist_player_remove",
    Callback = function(Value)
        if Value ~= "Nenhum" then
            for i, name in ipairs(ESPSettings.WhitelistPlayers) do
                if name == Value then
                    table.remove(ESPSettings.WhitelistPlayers, i)
                    print("Jogador removido da whitelist do ESP: " .. Value)
                    UpdateDropdowns() -- Atualizar dropdowns após remoção
                    break
                end
            end
        end
    end
})

-- Seção Whitelist de Times (ESP)
local SectionESPWhitelistTeams = Tab2:AddSection({"Whitelist - Times"})

-- Dropdown para selecionar time para adicionar à whitelist
local WhitelistESPTeamDropdown = Tab2:AddDropdown({
    Name = "Selecionar Time",
    Description = "Selecione um time para adicionar à whitelist",
    Options = GlobalLists.TeamList,
    Default = "Nenhum",
    Icon = "rbxassetid://10747373426",
    Flag = "esp_whitelist_team_select",
    Callback = function(Value) end
})

-- Botão para adicionar time à whitelist
Tab2:AddButton({
    Name = "Adicionar Time à Whitelist",
    Icon = "rbxassetid://10747373426",
    Callback = function()
        local teamValue = WhitelistESPTeamDropdown:Get()
        if teamValue ~= "Nenhum" and not table.find(ESPSettings.WhitelistTeams, teamValue) then
            table.insert(ESPSettings.WhitelistTeams, teamValue)
            print("Time adicionado à whitelist do ESP: " .. teamValue)
            UpdateDropdowns() -- Atualizar dropdowns após adição
        end
    end
})

-- Dropdown para remover time da whitelist
local WhitelistESPTeamRemoveDropdown = Tab2:AddDropdown({
    Name = "Remover Time da Whitelist",
    Description = "Selecione um time para remover da whitelist",
    Options = ESPSettings.WhitelistTeams,
    Default = "Nenhum",
    Icon = "rbxassetid://10747373426",
    Flag = "esp_whitelist_team_remove",
    Callback = function(Value)
        if Value ~= "Nenhum" then
            for i, name in ipairs(ESPSettings.WhitelistTeams) do
                if name == Value then
                    table.remove(ESPSettings.WhitelistTeams, i)
                    print("Time removido da whitelist do ESP: " .. Value)
                    UpdateDropdowns() -- Atualizar dropdowns após remoção
                    break
                end
            end
        end
    end
})

-- Aba 3: Atualizações
local Tab3 = Window:MakeTab({"Atualizações", "info"})

-- Seção de Informações de Atualização
local SectionUpdates = Tab3:AddSection({"Informações da Atualização"})

-- Parágrafo com infos de atualização
Tab3:AddParagraph({
    Title = "Versão Atual",
    Content = "Versão 1.7 - Data: 10 de Outubro de 2025\n\nMudanças:\n- Adicionada tabela global 'GlobalLists' para gerenciar listas de jogadores e times com table.insert.\n- Corrigido bug dos dropdowns de whitelist não atualizando corretamente.\n- Dropdowns agora usam ipairs para exibir valores dinamicamente.\n- Mantidos botões individuais para adicionar jogadores e times à whitelist.\n- Interface reorganizada com seções claras para whitelist de jogadores e times.\n- Mantido ESP com Highlight como padrão e barra de vida funcional.\n- Mantido toggle 'Mirar em Qualquer Um' e dropdown para jogador específico.\n- Seção separada para Previsão de Movimento com toggle e slider (0 a 200).\n- Aimbot otimizado para trocas de alvos fluidas e suporte robusto para mobile e PC.\n\nPróximas atualizações: Suporte para mais jogos, novas funcionalidades de ESP e otimizações."
})

-- Botão para verificar atualizações (simulado)
Tab3:AddButton({
    Name = "Verificar Atualizações",
    Callback = function()
        print("Verificando atualizações... Nenhuma atualização disponível no momento.")
    end
})

-- Diálogo de boas-vindas
local Dialog = Window:Dialog({
    Title = "AVISO : BETA",
    Text = "O hub ainda esta em beta, entãopode ter bugs ou funções inutil. Sugestõesno discord.",
    Options = {
        {"ok", function()
            print("Usuário confirmou o uso do Mafia Hub!")
        end},
    }
})

-- Função para atualizar dropdowns dinamicamente
local function UpdateDropdowns()
    UpdateGlobalLists()
    
    -- Atualizar dropdown de jogadores alvo (Aimbot)
    local aimbotTargetMethods = {
        function() if AimbotDropdown.Clear and AimbotDropdown.Add then AimbotDropdown:Clear() for _, v in ipairs(GlobalLists.PlayerList) do AimbotDropdown:Add(v) end end end,
        function() if AimbotDropdown.SetOptions then AimbotDropdown:SetOptions(GlobalLists.PlayerList) end end,
        function() if AimbotDropdown.Update then AimbotDropdown:Update(GlobalLists.PlayerList) end end,
        function() if AimbotDropdown.Set then AimbotDropdown:Set(GlobalLists.PlayerList) end end,
        function() AimbotDropdown.Options = GlobalLists.PlayerList if AimbotDropdown.Refresh then AimbotDropdown:Refresh() end end
    }
    for _, func in ipairs(aimbotTargetMethods) do pcall(func) end
    
    -- Atualizar dropdown de whitelist de jogadores (Aimbot)
    local aimbotPlayerWhitelistMethods = {
        function() if WhitelistAimbotPlayerDropdown.Clear and WhitelistAimbotPlayerDropdown.Add then WhitelistAimbotPlayerDropdown:Clear() for _, v in ipairs(GlobalLists.PlayerList) do WhitelistAimbotPlayerDropdown:Add(v) end end end,
        function() if WhitelistAimbotPlayerDropdown.SetOptions then WhitelistAimbotPlayerDropdown:SetOptions(GlobalLists.PlayerList) end end,
        function() if WhitelistAimbotPlayerDropdown.Update then WhitelistAimbotPlayerDropdown:Update(GlobalLists.PlayerList) end end,
        function() if WhitelistAimbotPlayerDropdown.Set then WhitelistAimbotPlayerDropdown:Set(GlobalLists.PlayerList) end end,
        function() WhitelistAimbotPlayerDropdown.Options = GlobalLists.PlayerList if WhitelistAimbotPlayerDropdown.Refresh then WhitelistAimbotPlayerDropdown:Refresh() end end
    }
    for _, func in ipairs(aimbotPlayerWhitelistMethods) do pcall(func) end
    
    -- Atualizar dropdown de remoção de jogadores (Aimbot)
    local aimbotPlayerRemoveMethods = {
        function() 
            if WhitelistAimbotPlayerRemoveDropdown.Clear and WhitelistAimbotPlayerRemoveDropdown.Add then 
                WhitelistAimbotPlayerRemoveDropdown:Clear() 
                for _, v in ipairs(AimbotSettings.WhitelistPlayers) do 
                    WhitelistAimbotPlayerRemoveDropdown:Add(v) 
                end 
                if #AimbotSettings.WhitelistPlayers == 0 then
                    WhitelistAimbotPlayerRemoveDropdown:Add("Nenhum")
                end
            end 
        end,
        function() if WhitelistAimbotPlayerRemoveDropdown.SetOptions then WhitelistAimbotPlayerRemoveDropdown:SetOptions(#AimbotSettings.WhitelistPlayers > 0 and AimbotSettings.WhitelistPlayers or {"Nenhum"}) end end,
        function() if WhitelistAimbotPlayerRemoveDropdown.Update then WhitelistAimbotPlayerRemoveDropdown:Update(#AimbotSettings.WhitelistPlayers > 0 and AimbotSettings.WhitelistPlayers or {"Nenhum"}) end end,
        function() if WhitelistAimbotPlayerRemoveDropdown.Set then WhitelistAimbotPlayerRemoveDropdown:Set(#AimbotSettings.WhitelistPlayers > 0 and AimbotSettings.WhitelistPlayers or {"Nenhum"}) end end,
        function() 
            WhitelistAimbotPlayerRemoveDropdown.Options = #AimbotSettings.WhitelistPlayers > 0 and AimbotSettings.WhitelistPlayers or {"Nenhum"} 
            if WhitelistAimbotPlayerRemoveDropdown.Refresh then WhitelistAimbotPlayerRemoveDropdown:Refresh() end 
        end
    }
    for _, func in ipairs(aimbotPlayerRemoveMethods) do pcall(func) end
    
    -- Atualizar dropdown de whitelist de times (Aimbot)
    local aimbotTeamWhitelistMethods = {
        function() if WhitelistAimbotTeamDropdown.Clear and WhitelistAimbotTeamDropdown.Add then WhitelistAimbotTeamDropdown:Clear() for _, v in ipairs(GlobalLists.TeamList) do WhitelistAimbotTeamDropdown:Add(v) end end end,
        function() if WhitelistAimbotTeamDropdown.SetOptions then WhitelistAimbotTeamDropdown:SetOptions(GlobalLists.TeamList) end end,
        function() if WhitelistAimbotTeamDropdown.Update then WhitelistAimbotTeamDropdown:Update(GlobalLists.TeamList) end end,
        function() if WhitelistAimbotTeamDropdown.Set then WhitelistAimbotTeamDropdown:Set(GlobalLists.TeamList) end end,
        function() WhitelistAimbotTeamDropdown.Options = GlobalLists.TeamList if WhitelistAimbotTeamDropdown.Refresh then WhitelistAimbotTeamDropdown:Refresh() end end
    }
    for _, func in ipairs(aimbotTeamWhitelistMethods) do pcall(func) end
    
    -- Atualizar dropdown de remoção de times (Aimbot)
    local aimbotTeamRemoveMethods = {
        function() 
            if WhitelistAimbotTeamRemoveDropdown.Clear and WhitelistAimbotTeamRemoveDropdown.Add then 
                WhitelistAimbotTeamRemoveDropdown:Clear() 
                for _, v in ipairs(AimbotSettings.WhitelistTeams) do 
                    WhitelistAimbotTeamRemoveDropdown:Add(v) 
                end 
                if #AimbotSettings.WhitelistTeams == 0 then
                    WhitelistAimbotTeamRemoveDropdown:Add("Nenhum")
                end
            end 
        end,
        function() if WhitelistAimbotTeamRemoveDropdown.SetOptions then WhitelistAimbotTeamRemoveDropdown:SetOptions(#AimbotSettings.WhitelistTeams > 0 and AimbotSettings.WhitelistTeams or {"Nenhum"}) end end,
        function() if WhitelistAimbotTeamRemoveDropdown.Update then WhitelistAimbotTeamRemoveDropdown:Update(#AimbotSettings.WhitelistTeams > 0 and AimbotSettings.WhitelistTeams or {"Nenhum"}) end end,
        function() if WhitelistAimbotTeamRemoveDropdown.Set then WhitelistAimbotTeamRemoveDropdown:Set(#AimbotSettings.WhitelistTeams > 0 and AimbotSettings.WhitelistTeams or {"Nenhum"}) end end,
        function() 
            WhitelistAimbotTeamRemoveDropdown.Options = #AimbotSettings.WhitelistTeams > 0 and AimbotSettings.WhitelistTeams or {"Nenhum"} 
            if WhitelistAimbotTeamRemoveDropdown.Refresh then WhitelistAimbotTeamRemoveDropdown:Refresh() end 
        end
    }
    for _, func in ipairs(aimbotTeamRemoveMethods) do pcall(func) end
    
    -- Atualizar dropdown de whitelist de jogadores (ESP)
    local espPlayerWhitelistMethods = {
        function() if WhitelistESPPlayerDropdown.Clear and WhitelistESPPlayerDropdown.Add then WhitelistESPPlayerDropdown:Clear() for _, v in ipairs(GlobalLists.PlayerList) do WhitelistESPPlayerDropdown:Add(v) end end end,
        function() if WhitelistESPPlayerDropdown.SetOptions then WhitelistESPPlayerDropdown:SetOptions(GlobalLists.PlayerList) end end,
        function() if WhitelistESPPlayerDropdown.Update then WhitelistESPPlayerDropdown:Update(GlobalLists.PlayerList) end end,
        function() if WhitelistESPPlayerDropdown.Set then WhitelistESPPlayerDropdown:Set(GlobalLists.PlayerList) end end,
        function() WhitelistESPPlayerDropdown.Options = GlobalLists.PlayerList if WhitelistESPPlayerDropdown.Refresh then WhitelistESPPlayerDropdown:Refresh() end end
    }
    for _, func in ipairs(espPlayerWhitelistMethods) do pcall(func) end
    
    -- Atualizar dropdown de remoção de jogadores (ESP)
    local espPlayerRemoveMethods = {
        function() 
            if WhitelistESPPlayerRemoveDropdown.Clear and WhitelistESPPlayerRemoveDropdown.Add then 
                WhitelistESPPlayerRemoveDropdown:Clear() 
                for _, v in ipairs(ESPSettings.WhitelistPlayers) do 
                    WhitelistESPPlayerRemoveDropdown:Add(v) 
                end 
                if #ESPSettings.WhitelistPlayers == 0 then
                    WhitelistESPPlayerRemoveDropdown:Add("Nenhum")
                end
            end 
        end,
        function() if WhitelistESPPlayerRemoveDropdown.SetOptions then WhitelistESPPlayerRemoveDropdown:SetOptions(#ESPSettings.WhitelistPlayers > 0 and ESPSettings.WhitelistPlayers or {"Nenhum"}) end end,
        function() if WhitelistESPPlayerRemoveDropdown.Update then WhitelistESPPlayerRemoveDropdown:Update(#ESPSettings.WhitelistPlayers > 0 and ESPSettings.WhitelistPlayers or {"Nenhum"}) end end,
        function() if WhitelistESPPlayerRemoveDropdown.Set then WhitelistESPPlayerRemoveDropdown:Set(#ESPSettings.WhitelistPlayers > 0 and ESPSettings.WhitelistPlayers or {"Nenhum"}) end end,
        function() 
            WhitelistESPPlayerRemoveDropdown.Options = #ESPSettings.WhitelistPlayers > 0 and ESPSettings.WhitelistPlayers or {"Nenhum"} 
            if WhitelistESPPlayerRemoveDropdown.Refresh then WhitelistESPPlayerRemoveDropdown:Refresh() end 
        end
    }
    for _, func in ipairs(espPlayerRemoveMethods) do pcall(func) end
    
    -- Atualizar dropdown de whitelist de times (ESP)
    local espTeamWhitelistMethods = {
        function() if WhitelistESPTeamDropdown.Clear and WhitelistESPTeamDropdown.Add then WhitelistESPTeamDropdown:Clear() for _, v in ipairs(GlobalLists.TeamList) do WhitelistESPTeamDropdown:Add(v) end end end,
        function() if WhitelistESPTeamDropdown.SetOptions then WhitelistESPTeamDropdown:SetOptions(GlobalLists.TeamList) end end,
        function() if WhitelistESPTeamDropdown.Update then WhitelistESPTeamDropdown:Update(GlobalLists.TeamList) end end,
        function() if WhitelistESPTeamDropdown.Set then WhitelistESPTeamDropdown:Set(GlobalLists.TeamList) end end,
        function() WhitelistESPTeamDropdown.Options = GlobalLists.TeamList if WhitelistESPTeamDropdown.Refresh then WhitelistESPTeamDropdown:Refresh() end end
    }
    for _, func in ipairs(espTeamWhitelistMethods) do pcall(func) end
    
    -- Atualizar dropdown de remoção de times (ESP)
    local espTeamRemoveMethods = {
        function() 
            if WhitelistESPTeamRemoveDropdown.Clear and WhitelistESPTeamRemoveDropdown.Add then 
                WhitelistESPTeamRemoveDropdown:Clear() 
                for _, v in ipairs(ESPSettings.WhitelistTeams) do 
                    WhitelistESPTeamRemoveDropdown:Add(v) 
                end 
                if #ESPSettings.WhitelistTeams == 0 then
                    WhitelistESPTeamRemoveDropdown:Add("Nenhum")
                end
            end 
        end,
        function() if WhitelistESPTeamRemoveDropdown.SetOptions then WhitelistESPTeamRemoveDropdown:SetOptions(#ESPSettings.WhitelistTeams > 0 and ESPSettings.WhitelistTeams or {"Nenhum"}) end end,
        function() if WhitelistESPTeamRemoveDropdown.Update then WhitelistESPTeamRemoveDropdown:Update(#ESPSettings.WhitelistTeams > 0 and ESPSettings.WhitelistTeams or {"Nenhum"}) end end,
        function() if WhitelistESPTeamRemoveDropdown.Set then WhitelistESPTeamRemoveDropdown:Set(#ESPSettings.WhitelistTeams > 0 and ESPSettings.WhitelistTeams or {"Nenhum"}) end end,
        function() 
            WhitelistESPTeamRemoveDropdown.Options = #ESPSettings.WhitelistTeams > 0 and ESPSettings.WhitelistTeams or {"Nenhum"} 
            if WhitelistESPTeamRemoveDropdown.Refresh then WhitelistESPTeamRemoveDropdown:Refresh() end 
        end
    }
    for _, func in ipairs(espTeamRemoveMethods) do pcall(func) end
end

-- Atualizar dropdowns na inicialização
UpdateDropdowns()

-- Atualizar dropdowns quando jogadores entram ou saem
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        table.insert(GlobalLists.PlayerList, player.Name)
        UpdateDropdowns()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    for i, name in ipairs(GlobalLists.PlayerList) do
        if name == player.Name then
            table.remove(GlobalLists.PlayerList, i)
            AimbotSettings.CurrentTarget = nil
            break
        end
    end
    for i, name in ipairs(AimbotSettings.WhitelistPlayers) do
        if name == player.Name then
            table.remove(AimbotSettings.WhitelistPlayers, i)
            break
        end
    end
    for i, name in ipairs(ESPSettings.WhitelistPlayers) do
        if name == player.Name then
            table.remove(ESPSettings.WhitelistPlayers, i)
            break
        end
    end
    UpdateDropdowns()
end)

-- Atualizar dropdowns quando times mudam
game:GetService("Teams").ChildAdded:Connect(UpdateDropdowns)
game:GetService("Teams").ChildRemoved:Connect(UpdateDropdowns)
