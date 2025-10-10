-- Carregar a biblioteca
local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/SrDark222/Mafia-hub-v1/refs/heads/main/mafia%20hub.lua"))()

-- Janela principal
local Window = redzlib:MakeWindow({
    Title = "MAFIA HUB - Brookhaven",
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
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Variáveis globais para configurações
local AimbotSettings = {
    Enabled = false,
    AimLockEnabled = false,
    TargetAny = true, -- Toggle para "Qualquer um"
    Target = nil, -- Jogador específico selecionado
    Smoothness = 5.0,
    Predict = false,
    PredictFactor = 100, -- Fator de previsão (0 a 200)
    MaxDistance = 500,
    IgnoreTeam = false,
    IgnoreDead = true,
    VisibleOnly = true,
    LockPart = "Head",
    FOV = 200, -- Campo de visão para aimbot (em pixels)
    CurrentTarget = nil -- Armazena o alvo atual
}

local ESPSettings = {
    Enabled = false,
    Names = false,
    Studs = false,
    Tracers = false,
    Boxes = false,
    TeamColor = true,
    IgnoreTeam = false,
    EnemyColor = Color3.fromRGB(255, 0, 0), -- Vermelho
    AllyColor = Color3.fromRGB(0, 255, 0) -- Verde
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

-- Função para obter lista de jogadores
local function getPlayerList()
    local lista = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(lista, player.Name)
        end
    end
    return lista
end

-- Funções auxiliares
local function IsAlive(character)
    local humanoid = character and character:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function IsTeamMate(player)
    return player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
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
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and (not AimbotSettings.IgnoreTeam or not IsTeamMate(player)) then
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
    return closest
end

-- Função para verificar se o alvo atual ainda é válido
local function IsValidTarget(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local character = targetPart.Parent
    local player = Players:GetPlayerFromCharacter(character)
    if not player or player == LocalPlayer then return false end
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

-- Tabela para ESP drawings
local ESPDrawings = {}

local function CreateESP(player)
    if not player then return end
    
    local drawings = {}
    
    drawings.Box = Drawing.new("Square")
    drawings.Box.Thickness = 1
    drawings.Box.Filled = false
    drawings.Box.Transparency = 1
    drawings.Box.Visible = false
    
    drawings.Name = Drawing.new("Text")
    drawings.Name.Size = 16
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.Font = Drawing.Fonts.UI
    drawings.Name.Visible = false
    
    drawings.Studs = Drawing.new("Text")
    drawings.Studs.Size = 14
    drawings.Studs.Center = true
    drawings.Studs.Outline = true
    drawings.Studs.Font = Drawing.Fonts.UI
    drawings.Studs.Visible = false
    
    drawings.Tracer = Drawing.new("Line")
    drawings.Tracer.Thickness = 1
    drawings.Tracer.Transparency = 1
    drawings.Tracer.Visible = false
    
    ESPDrawings[player] = drawings
end

local function UpdateESP()
    for player, drawings in pairs(ESPDrawings) do
        local character = player.Character
        if ESPSettings.Enabled and character and (not ESPSettings.IgnoreTeam or not IsTeamMate(player)) then
            local alive = IsAlive(character)
            if alive or not ESPSettings.IgnoreDead then
                local root = character:FindFirstChild("HumanoidRootPart")
                local head = character:FindFirstChild("Head")
                if root and head then
                    local dist = (root.Position - Camera.CFrame.Position).Magnitude
                    local color = ESPSettings.TeamColor and (IsTeamMate(player) and (player.TeamColor and player.TeamColor.Color or ESPSettings.AllyColor) or Color3.fromRGB(255, 0, 0)) or (IsTeamMate(player) and ESPSettings.AllyColor or ESPSettings.EnemyColor)
                    
                    local torsoPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        if ESPSettings.Boxes then
                            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                            local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                            local visibility = 1 - (dist / 500)
                            drawings.Box.Transparency = visibility
                            drawings.Box.Size = Vector2.new(math.clamp(1200 / torsoPos.Z, 10, 100), math.clamp(headPos.Y - legPos.Y, 20, 200))
                            drawings.Box.Position = Vector2.new(torsoPos.X - drawings.Box.Size.X / 2, legPos.Y)
                            drawings.Box.Color = color
                            drawings.Box.Visible = true
                        else
                            drawings.Box.Visible = false
                        end
                        
                        if ESPSettings.Names then
                            local vector = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
                            drawings.Name.Text = player.Name
                            drawings.Name.Position = Vector2.new(vector.X, vector.Y - drawings.Name.Size)
                            drawings.Name.Color = color
                            drawings.Name.Visible = true
                        else
                            drawings.Name.Visible = false
                        end
                        
                        if ESPSettings.Studs then
                            local vector = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 4, 0))
                            drawings.Studs.Text = math.floor(dist) .. " studs"
                            drawings.Studs.Position = Vector2.new(vector.X, vector.Y)
                            drawings.Studs.Color = color
                            drawings.Studs.Visible = true
                        else
                            drawings.Studs.Visible = false
                        end
                        
                        if ESPSettings.Tracers then
                            local vector = Camera:WorldToViewportPoint(root.Position)
                            drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                            drawings.Tracer.To = Vector2.new(vector.X, vector.Y)
                            drawings.Tracer.Color = color
                            drawings.Tracer.Visible = true
                        else
                            drawings.Tracer.Visible = false
                        end
                    else
                        for _, drawing in pairs(drawings) do
                            drawing.Visible = false
                        end
                    end
                end
            else
                for _, drawing in pairs(drawings) do
                    drawing.Visible = false
                end
            end
        else
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
    end
end

-- Conexão para ESP
local ESPConnection
local function ToggleESP(enabled)
    ESPSettings.Enabled = enabled
    if enabled then
        for _, player in pairs(Players:GetPlayers()) do
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
        for _, drawings in pairs(ESPDrawings) do
            for _, drawing in pairs(drawings) do
                drawing:Remove()
            end
        end
        ESPDrawings = {}
    end
end

-- Aba 1: Aimbot
local Tab1 = Window:MakeTab({"Aimbot", "crosshair"})
Window:SelectTab(Tab1)

-- Seção Geral do Aimbot
local SectionAimbotGeneral = Tab1:AddSection({"Geral"})

-- Toggle para "Qualquer um"
Tab1:AddToggle({
    Name = "Mirar em Qualquer Um",
    Description = "Mirar em qualquer jogador (desative para selecionar um jogador específico)",
    Default = true,
    Icon = "rbxassetid://10734920149",
    Callback = function(Value)
        AimbotSettings.TargetAny = Value
        AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar seleção
        print("Mirar em Qualquer Um " .. (Value and "ativado" or "desativado"))
    end
})

-- Dropdown para selecionar o jogador alvo
local PlayersList = getPlayerList()
local AimbotDropdown = Tab1:AddDropdown({
    Name = "Jogador Alvo Específico",
    Description = "Selecione um jogador específico para mirar",
    Options = PlayersList,
    Default = PlayersList[1] or "Nenhum",
    Icon = "rbxassetid://10734920149",
    Flag = "aimbot_target",
    Callback = function(Value)
        if not AimbotSettings.TargetAny then
            AimbotSettings.Target = Value
            AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar seleção
            print("Jogador alvo selecionado: " .. Value)
        end
    end
})

-- Botão para atualizar jogadores
Tab1:AddButton({
    Name = "Atualizar Jogadores",
    Icon = "rbxassetid://10734933056",
    Callback = function()
        local listaNova = getPlayerList()
        print("Lista atualizada: " .. table.concat(listaNova, ", "))
        
        local methods = {
            function() if AimbotDropdown.Clear and AimbotDropdown.Add then AimbotDropdown:Clear() for _, v in ipairs(listaNova) do AimbotDropdown:Add(v) end end end,
            function() if AimbotDropdown.SetOptions then AimbotDropdown:SetOptions(listaNova) end end,
            function() if AimbotDropdown.Update then AimbotDropdown:Update(listaNova) end end,
            function() if AimbotDropdown.Set then AimbotDropdown:Set(listaNova) end end,
            function() AimbotDropdown.Options = listaNova if AimbotDropdown.Refresh then AimbotDropdown:Refresh() end end
        }
        
        for _, func in ipairs(methods) do
            pcall(func)
        end
    end
})

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
        AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar parte do corpo
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
        AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar FOV
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
        AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar filtro
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
        AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar filtro
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
        AimbotSettings.CurrentTarget = nil -- Resetar alvo ao mudar filtro
        print("Apenas Visíveis " .. (Value and "ativado" or "desativado"))
    end
})

-- Aba 2: ESP
local Tab2 = Window:MakeTab({"ESP", "eye"})

-- Seção Geral do ESP
local SectionESPGeneral = Tab2:AddSection({"Geral"})

-- Toggle ESP
Tab2:AddToggle({
    Name = "Ativar ESP",
    Description = "Ativa ESP global",
    Default = false,
    Icon = "rbxassetid://10747375132",
    Callback = function(Value)
        ToggleESP(Value)
        print("ESP " .. (Value and "ativado" or "desativado"))
    end
})

-- Seção Features do ESP
local SectionESPFeatures = Tab2:AddSection({"Features Individuais"})

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

-- Toggle Tracers
Tab2:AddToggle({
    Name = "Tracers",
    Description = "Linhas para jogadores",
    Default = false,
    Icon = "rbxassetid://10734929723",
    Callback = function(Value)
        ESPSettings.Tracers = Value
        print("Tracers " .. (Value and "ativados" or "desativados"))
    end
})

-- Toggle Boxes
Tab2:AddToggle({
    Name = "Boxes",
    Description = "Caixas ao redor dos jogadores",
    Default = false,
    Icon = "rbxassetid://10734965702",
    Callback = function(Value)
        ESPSettings.Boxes = Value
        print("Boxes " .. (Value and "ativadas" or "desativadas"))
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

-- Aba 3: Atualizações
local Tab3 = Window:MakeTab({"Atualizações", "info"})

-- Seção de Informações de Atualização
local SectionUpdates = Tab3:AddSection({"Informações da Atualização"})

-- Parágrafo com infos de atualização
Tab3:AddParagraph({
    Title = "Versão Atual",
    Content = "Versão 1.3 - Data: 10 de Outubro de 2025\n\nMudanças:\n- Corrigido bug de criação de apenas uma aba e toggle.\n- Garantida a criação de todas as abas (Aimbot, ESP, Atualizações).\n- Mantido toggle 'Mirar em Qualquer Um' e dropdown para jogador específico.\n- Seção separada para Previsão de Movimento com toggle e slider (0 a 200).\n- Aimbot otimizado para trocas de alvos fluidas e suporte robusto para mobile e PC.\n\nPróximas atualizações: Suporte para mais jogos, novas funcionalidades de ESP e otimizações."
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
    Title = "T.C.C ALERTA",
    Text = "Bem-vindo ao Mafia Hub! Escolha uma opção para continuar.",
    Options = {
        {"Confirmar", function()
            print("Usuário confirmou o uso do Mafia Hub!")
        end},
        {"Talvez", function()
            print("Usuário está considerando...")
        end},
        {"Cancelar", function()
            print("Usuário cancelou.")
        end}
    }
})

-- Atualizar lista de jogadores dinamicamente
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        table.insert(PlayersList, player.Name)
        local methods = {
            function() if AimbotDropdown.Clear and AimbotDropdown.Add then AimbotDropdown:Clear() for _, v in ipairs(PlayersList) do AimbotDropdown:Add(v) end end end,
            function() if AimbotDropdown.SetOptions then AimbotDropdown:SetOptions(PlayersList) end end,
            function() if AimbotDropdown.Update then AimbotDropdown:Update(PlayersList) end end,
            function() if AimbotDropdown.Set then AimbotDropdown:Set(PlayersList) end end,
            function() AimbotDropdown.Options = PlayersList if AimbotDropdown.Refresh then AimbotDropdown:Refresh() end end
        }
        for _, func in ipairs(methods) do pcall(func) end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    for i, name in ipairs(PlayersList) do
        if name == player.Name then
            table.remove(PlayersList, i)
            AimbotSettings.CurrentTarget = nil -- Resetar alvo se o jogador sair
            break
        end
    end
    local methods = {
        function() if AimbotDropdown.Clear and AimbotDropdown.Add then AimbotDropdown:Clear() for _, v in ipairs(PlayersList) do AimbotDropdown:Add(v) end end end,
        function() if AimbotDropdown.SetOptions then AimbotDropdown:SetOptions(PlayersList) end end,
        function() if AimbotDropdown.Update then AimbotDropdown:Update(PlayersList) end end,
        function() if AimbotDropdown.Set then AimbotDropdown:Set(PlayersList) end end,
        function() AimbotDropdown.Options = PlayersList if AimbotDropdown.Refresh then AimbotDropdown:Refresh() end end
    }
    for _, func in ipairs(methods) do pcall(func) end
end)
