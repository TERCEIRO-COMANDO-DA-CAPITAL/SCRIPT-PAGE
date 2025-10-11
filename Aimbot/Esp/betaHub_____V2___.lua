-- Carregar a biblioteca
local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/SrDark222/Mafia-hub-v1/refs/heads/main/mafia%20hub.lua"))()

-- Janela principal
local Window = redzlib:MakeWindow({
    Title = "MAFIA HUB - Trocar Tiro",
    SubTitle = "by menor DK",
    SaveFolder = "tcc_hub.lua"
})

-- Botão de minimizar AMOLED
Window:AddMinimizeButton({
    Button = { Image = "rbxassetid://100971981026789", BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(20, 20, 30) },
    Corner = { CornerRadius = UDim.new(0.5, 0) }
})

-- Serviços do Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Configurações
local ConfiguracoesAimbotDiscreto = {
    Ativado = false,
    Suavidade = 8.0,
    PreverMovimento = true,
    FatorPrevisao = 120,
    DistanciaMaxima = 500,
    CampoDeVisao = 150,
    IgnorarTime = false,
    IgnorarMortos = true,
    IgnorarVivos = false,
    IgnorarParedes = true,
    IgnorarAmigos = false,
    IgnorarForceField = false, -- Nova opção
    ParteDoCorpo = "Head",
    AlvoAtual = nil,
    ModoPrioridade = "Automático",
    LimiteVidaBaixa = 40,
    LimiteDistanciaProxima = 100,
    LimitarFPS = false,
    SuavizacaoExtra = 0.7,
    PrioridadeAmeaca = false
}

local ConfiguracoesAimbotAgressivo = {
    Ativado = false,
    PreverMovimento = true,
    FatorPrevisao = 120,
    DistanciaMaxima = 500,
    CampoDeVisao = 500,
    IgnorarTime = false,
    IgnorarMortos = true,
    IgnorarVivos = false,
    IgnorarParedes = false,
    IgnorarAmigos = false,
    IgnorarForceField = false, -- Nova opção
    ParteDoCorpo = "Head",
    AlvoAtual = nil,
    ModoPrioridade = "Automático",
    LimiteVidaBaixa = 40,
    LimiteDistanciaProxima = 100,
    LimitarFPS = false,
    SuavizacaoExtra = 0.9,
    PrioridadeAmeaca = false
}

local ConfiguracoesESP = {
    Ativado = false,
    MostrarNomes = true,
    MostrarDistancia = false,
    MostrarVida = true,
    MostrarCaixas = true,
    MostrarLinhas = false,
    MostrarArma = true,
    MostrarInventario = false,
    IgnorarTime = false,
    CorTime = true,
    CorInimigo = Color3.fromRGB(255, 50, 50),
    CorAliado = Color3.fromRGB(0, 255, 0),
    PosicaoNome = "Acima",
    PosicaoDistancia = "Abaixo",
    PosicaoVida = "Esquerda",
    PosicaoArma = "Direita",
    TransparenciaCaixa = 0.5,
    EspessuraLinha = 1.2,
    TamanhoTexto = 1.0,
    SombraTexto = true,
    ContornoNeon = true,
    OpacidadeContorno = 0.7,
    DestacarAlvoAimbot = true,
    AnimacaoPulsante = true,
    IconeArma = true
}

-- Tabelas para ESP
local ESPHighlights = {}
local ESPLinhas = {}
local ArmaIcones = {} -- Placeholder para rbxassetid de armas

-- Funções auxiliares
local function EstaVivo(personagem)
    local humanoide = personagem and personagem:FindFirstChild("Humanoid")
    return humanoide and humanoide.Health > 0
end

local function TemForceField(personagem)
    return personagem and personagem:FindFirstChildOfClass("ForceField") ~= nil
end

local function ObterPorcentagemVida(personagem)
    local humanoide = personagem and personagem:FindFirstChild("Humanoid")
    return humanoide and (humanoide.Health / humanoide.MaxHealth * 100) or 100
end

local function EhDoMesmoTime(jogador)
    return jogador.Team and LocalPlayer.Team and jogador.Team == LocalPlayer.Team
end

local function EhAmigo(jogador)
    return LocalPlayer:IsFriendsWith(jogador.UserId)
end

local function EhVisivel(parteAlvo)
    local personagem = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {personagem}
    params.IgnoreWater = true
    local resultadoRaio = Workspace:Raycast(Camera.CFrame.Position, (parteAlvo.Position - Camera.CFrame.Position).Unit * 1000, params)
    return resultadoRaio and resultadoRaio.Instance:IsDescendantOf(parteAlvo.Parent)
end

local function ObterCorESP(personagem)
    if ConfiguracoesESP.CorTime and EhDoMesmoTime(Players:GetPlayerFromCharacter(personagem)) then
        return ConfiguracoesESP.CorAliado
    end
    return ConfiguracoesESP.CorInimigo
end

local function ObterCorVida(personagem)
    local porcentagemVida = ObterPorcentagemVida(personagem)
    if porcentagemVida >= 99 then
        return Color3.fromRGB(0, 255, 0) -- Verde neon
    elseif porcentagemVida >= ConfiguracoesAimbotDiscreto.LimiteVidaBaixa then
        local fator = (porcentagemVida - ConfiguracoesAimbotDiscreto.LimiteVidaBaixa) / (100 - ConfiguracoesAimbotDiscreto.LimiteVidaBaixa)
        local r = 255 * (1 - fator)
        local g = 255 * fator
        return Color3.fromRGB(r, g, 0) -- Transição verde para laranja
    else
        return Color3.fromRGB(255, 50, 50) -- Vermelho neon
    end
end

local function ObterInventario(jogador)
    local inventario = {}
    local backpack = jogador:FindFirstChild("Backpack")
    if backpack then
        for _, ferramenta in ipairs(backpack:GetChildren()) do
            if ferramenta:IsA("Tool") then
                table.insert(inventario, ferramenta.Name)
            end
        end
    end
    return table.concat(inventario, ", ") or "Nenhum"
end

local function ObterJogadorMaisProximo(configuracoes)
    local candidatos = {}
    local centroTela = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, jogador in ipairs(Players:GetPlayers()) do
        if jogador ~= LocalPlayer then
            if not configuracoes.IgnorarTime or not EhDoMesmoTime(jogador) then
                if not configuracoes.IgnorarAmigos or not EhAmigo(jogador) then
                    local personagem = jogador.Character
                    if personagem and (not configuracoes.IgnorarForceField or not TemForceField(personagem)) then
                        local vivo = EstaVivo(personagem)
                        if (not configuracoes.IgnorarMortos or vivo) and (not configuracoes.IgnorarVivos or not vivo) then
                            local parte = personagem:FindFirstChild(configuracoes.ParteDoCorpo)
                            if parte then
                                local dist = (parte.Position - Camera.CFrame.Position).Magnitude
                                if dist <= configuracoes.DistanciaMaxima then
                                    local posTela, naTela = Camera:WorldToViewportPoint(parte.Position)
                                    if naTela then
                                        local distTela = (Vector2.new(posTela.X, posTela.Y) - centroTela).Magnitude
                                        if distTela < configuracoes.CampoDeVisao and (not configuracoes.IgnorarParedes or EhVisivel(parte)) then
                                            local porcentagemVida = ObterPorcentagemVida(personagem)
                                            local prioridade
                                            if configuracoes.ModoPrioridade == "Automático" then
                                                prioridade = dist
                                                if porcentagemVida >= configuracoes.LimiteVidaBaixa then
                                                    prioridade = prioridade + 10000
                                                end
                                            elseif configuracoes.ModoPrioridade == "Vida Baixa" then
                                                prioridade = porcentagemVida + (dist / 100)
                                            elseif configuracoes.ModoPrioridade == "Mais Próximo" then
                                                prioridade = dist
                                                if dist > configuracoes.LimiteDistanciaProxima then
                                                    prioridade = prioridade + 10000
                                                end
                                            elseif configuracoes.ModoPrioridade == "Ameaça" then
                                                prioridade = dist -- Placeholder, ajustar para detectar arma
                                            end
                                            table.insert(candidatos, {parte = parte, prioridade = prioridade})
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
    
    if #candidatos > 0 then
        table.sort(candidatos, function(a, b) return a.prioridade < b.prioridade end)
        return candidatos[1].parte
    end
    return nil
end

local function EhAlvoValido(parteAlvo, configuracoes)
    if not parteAlvo or not parteAlvo.Parent then return false end
    local personagem = parteAlvo.Parent
    local jogador = Players:GetPlayerFromCharacter(personagem)
    if not jogador or jogador == LocalPlayer then return false end
    if configuracoes.IgnorarTime and EhDoMesmoTime(jogador) then return false end
    if configuracoes.IgnorarAmigos and EhAmigo(jogador) then return false end
    if configuracoes.IgnorarMortos and not EstaVivo(personagem) then return false end
    if configuracoes.IgnorarVivos and EstaVivo(personagem) then return false end
    if configuracoes.IgnorarParedes and not EhVisivel(parteAlvo) then return false end
    if configuracoes.IgnorarForceField and TemForceField(personagem) then return false end
    local dist = (parteAlvo.Position - Camera.CFrame.Position).Magnitude
    if dist > configuracoes.DistanciaMaxima then return false end
    local posTela, naTela = Camera:WorldToViewportPoint(parteAlvo.Position)
    if not naTela then return false end
    local centroTela = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local distTela = (Vector2.new(posTela.X, posTela.Y) - centroTela).Magnitude
    return distTela < configuracoes.CampoDeVisao
end

-- Aimbot Discreto
local ConexaoAimbotDiscreto
local function AlternarAimbotDiscreto(ativado)
    if ativado then
        ConexaoAimbotDiscreto = RunService.RenderStepped:Connect(function(delta)
            if ConfiguracoesAimbotDiscreto.LimitarFPS then
                task.wait(1/60)
            end
            if ConfiguracoesAimbotDiscreto.AlvoAtual and not EhAlvoValido(ConfiguracoesAimbotDiscreto.AlvoAtual, ConfiguracoesAimbotDiscreto) then
                ConfiguracoesAimbotDiscreto.AlvoAtual = nil
            end
            
            if not ConfiguracoesAimbotDiscreto.AlvoAtual then
                ConfiguracoesAimbotDiscreto.AlvoAtual = ObterJogadorMaisProximo(ConfiguracoesAimbotDiscreto)
            end
            
            if ConfiguracoesAimbotDiscreto.AlvoAtual then
                local posAlvo = ConfiguracoesAimbotDiscreto.AlvoAtual.Position
                if ConfiguracoesAimbotDiscreto.PreverMovimento then
                    local raiz = ConfiguracoesAimbotDiscreto.AlvoAtual.Parent:FindFirstChild("HumanoidRootPart")
                    if raiz and raiz.Velocity.Magnitude > 0 then
                        local dist = (ConfiguracoesAimbotDiscreto.AlvoAtual.Position - Camera.CFrame.Position).Magnitude
                        posAlvo = posAlvo + raiz.Velocity * (dist / raiz.Velocity.Magnitude) * (ConfiguracoesAimbotDiscreto.FatorPrevisao / 1000)
                    end
                end
                local centroTela = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local posTela, naTela = Camera:WorldToViewportPoint(posAlvo)
                local distTela = naTela and (Vector2.new(posTela.X, posTela.Y) - centroTela).Magnitude or math.huge
                local fatorLerp = math.clamp((1 / ConfiguracoesAimbotDiscreto.Suavidade) * ConfiguracoesAimbotDiscreto.SuavizacaoExtra * (1 + distTela / 500), 0.1, 0.9)
                local novoCFrame = CFrame.lookAt(Camera.CFrame.Position, posAlvo)
                Camera.CFrame = Camera.CFrame:Lerp(novoCFrame, fatorLerp)
                task.wait(math.random(0.01, 0.03))
            end
        end)
    else
        if ConexaoAimbotDiscreto then
            ConexaoAimbotDiscreto:Disconnect()
            ConexaoAimbotDiscreto = nil
        end
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
end

-- Aimbot Agressivo
local ConexaoAimbotAgressivo
local function AlternarAimbotAgressivo(ativado)
    if ativado then
        ConexaoAimbotAgressivo = RunService.RenderStepped:Connect(function(delta)
            if ConfiguracoesAimbotAgressivo.LimitarFPS then
                task.wait(1/60)
            end
            if ConfiguracoesAimbotAgressivo.AlvoAtual and not EhAlvoValido(ConfiguracoesAimbotAgressivo.AlvoAtual, ConfiguracoesAimbotAgressivo) then
                ConfiguracoesAimbotAgressivo.AlvoAtual = nil
            end
            
            if not ConfiguracoesAimbotAgressivo.AlvoAtual then
                ConfiguracoesAimbotAgressivo.AlvoAtual = ObterJogadorMaisProximo(ConfiguracoesAimbotAgressivo)
            end
            
            if ConfiguracoesAimbotAgressivo.AlvoAtual then
                local posAlvo = ConfiguracoesAimbotAgressivo.AlvoAtual.Position
                if ConfiguracoesAimbotAgressivo.PreverMovimento then
                    local raiz = ConfiguracoesAimbotAgressivo.AlvoAtual.Parent:FindFirstChild("HumanoidRootPart")
                    if raiz and raiz.Velocity.Magnitude > 0 then
                        local dist = (ConfiguracoesAimbotAgressivo.AlvoAtual.Position - Camera.CFrame.Position).Magnitude
                        posAlvo = posAlvo + raiz.Velocity * (dist / raiz.Velocity.Magnitude) * (ConfiguracoesAimbotAgressivo.FatorPrevisao / 1000)
                    end
                end
                local centroTela = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local posTela, naTela = Camera:WorldToViewportPoint(posAlvo)
                local distTela = naTela and (Vector2.new(posTela.X, posTela.Y) - centroTela).Magnitude or math.huge
                local fatorLerp = math.clamp(ConfiguracoesAimbotAgressivo.SuavizacaoExtra * (1 + distTela / 500), 0.3, 1.0)
                local novoCFrame = CFrame.lookAt(Camera.CFrame.Position, posAlvo)
                Camera.CFrame = Camera.CFrame:Lerp(novoCFrame, fatorLerp)
                task.wait(math.random(0.005, 0.015))
            end
        end)
    else
        if ConexaoAimbotAgressivo then
            ConexaoAimbotAgressivo:Disconnect()
            ConexaoAimbotAgressivo = nil
        end
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
end

-- Função para obter posição do elemento no ESP
local function ObterOffsetPosicao(posicao, alturaBase, elemento)
    local offsetY = alturaBase
    if elemento == "Nome" then
        offsetY = offsetY
    elseif elemento == "Distancia" then
        offsetY = offsetY + (ConfiguracoesESP.MostrarNomes and ConfiguracoesESP.PosicaoNome == posicao and 0.6 or 0)
    elseif elemento == "Vida" then
        offsetY = offsetY + (ConfiguracoesESP.MostrarNomes and ConfiguracoesESP.PosicaoNome == posicao and 0.6 or 0) +
                  (ConfiguracoesESP.MostrarDistancia and ConfiguracoesESP.PosicaoDistancia == posicao and 0.6 or 0)
    elseif elemento == "Arma" then
        offsetY = offsetY + (ConfiguracoesESP.MostrarNomes and ConfiguracoesESP.PosicaoNome == posicao and 0.6 or 0) +
                  (ConfiguracoesESP.MostrarDistancia and ConfiguracoesESP.PosicaoDistancia == posicao and 0.6 or 0) +
                  (ConfiguracoesESP.MostrarVida and ConfiguracoesESP.PosicaoVida == posicao and 0.6 or 0)
    elseif elemento == "Inventario" then
        offsetY = offsetY + (ConfiguracoesESP.MostrarNomes and ConfiguracoesESP.PosicaoNome == posicao and 0.6 or 0) +
                  (ConfiguracoesESP.MostrarDistancia and ConfiguracoesESP.PosicaoDistancia == posicao and 0.6 or 0) +
                  (ConfiguracoesESP.MostrarVida and ConfiguracoesESP.PosicaoVida == posicao and 0.6 or 0) +
                  (ConfiguracoesESP.MostrarArma and ConfiguracoesESP.PosicaoArma == posicao and 0.6 or 0)
    end

    if posicao == "Acima" then
        return Vector3.new(0, offsetY + 1.5, 0)
    elseif posicao == "Abaixo" then
        return Vector3.new(0, offsetY - 1.5, 0)
    elseif posicao == "Esquerda" then
        return Vector3.new(-2.0, offsetY, 0)
    elseif posicao == "Direita" then
        return Vector3.new(2.0, offsetY, 0)
    end
    return Vector3.new(0, offsetY, 0)
end

-- ESP
local function CriarESP(jogador)
    if not jogador or jogador == LocalPlayer then return end
    
    local destaque = Instance.new("Highlight")
    destaque.Name = "ESPHighlight"
    destaque.Enabled = false
    destaque.FillTransparency = ConfiguracoesESP.TransparenciaCaixa
    destaque.OutlineTransparency = ConfiguracoesESP.ContornoNeon and ConfiguracoesESP.OpacidadeContorno or 1
    destaque.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    local painel = Instance.new("BillboardGui")
    painel.Name = "ESPPainel"
    painel.Size = UDim2.new(0, 130, 0, 100)
    painel.AlwaysOnTop = true
    painel.Enabled = false
    painel.LightInfluence = 0
    
    local labelNome = Instance.new("TextLabel")
    labelNome.Size = UDim2.new(1, 0, 0.25, 0)
    labelNome.BackgroundTransparency = 1
    labelNome.TextColor3 = Color3.fromRGB(255, 255, 255)
    labelNome.TextStrokeTransparency = ConfiguracoesESP.SombraTexto and 0.4 or 1
    labelNome.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    labelNome.TextScaled = true
    labelNome.Font = Enum.Font.Gotham
    labelNome.Visible = false
    labelNome.Parent = painel
    
    local labelDistancia = Instance.new("TextLabel")
    labelDistancia.Size = UDim2.new(1, 0, 0.25, 0)
    labelDistancia.BackgroundTransparency = 1
    labelDistancia.TextColor3 = Color3.fromRGB(255, 255, 255)
    labelDistancia.TextStrokeTransparency = ConfiguracoesESP.SombraTexto and 0.4 or 1
    labelDistancia.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    labelDistancia.TextScaled = true
    labelDistancia.Font = Enum.Font.Gotham
    labelDistancia.Visible = false
    labelDistancia.Parent = painel
    
    local barraVida = Instance.new("Frame")
    barraVida.Size = UDim2.new(1, 0, 0.15, 0)
    barraVida.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    barraVida.BorderSizePixel = 0
    barraVida.BackgroundTransparency = 0.2
    barraVida.Visible = false
    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(0, 5)
    uicorner.Parent = barraVida
    barraVida.Parent = painel
    
    local labelArma = Instance.new("TextLabel")
    labelArma.Size = UDim2.new(1, 0, 0.2, 0)
    labelArma.BackgroundTransparency = 1
    labelArma.TextColor3 = Color3.fromRGB(255, 255, 255)
    labelArma.TextStrokeTransparency = ConfiguracoesESP.SombraTexto and 0.4 or 1
    labelArma.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    labelArma.TextScaled = true
    labelArma.Font = Enum.Font.Gotham
    labelArma.Visible = false
    labelArma.Parent = painel
    
    local labelInventario = Instance.new("TextLabel")
    labelInventario.Size = UDim2.new(1, 0, 0.25, 0)
    labelInventario.BackgroundTransparency = 1
    labelInventario.TextColor3 = Color3.fromRGB(255, 255, 255)
    labelInventario.TextStrokeTransparency = ConfiguracoesESP.SombraTexto and 0.4 or 1
    labelInventario.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    labelInventario.TextScaled = true
    labelInventario.Font = Enum.Font.Gotham
    labelInventario.Visible = false
    labelInventario.Parent = painel
    
    local iconeArma = Instance.new("ImageLabel")
    iconeArma.Size = UDim2.new(0, 30, 0, 30)
    iconeArma.BackgroundTransparency = 1
    iconeArma.Visible = false
    iconeArma.Parent = painel
    
    local linha = Drawing.new("Line")
    linha.Visible = false
    linha.Color = Color3.fromRGB(255, 255, 255)
    linha.Thickness = ConfiguracoesESP.EspessuraLinha
    linha.Transparency = 0.8
    
    ESPHighlights[jogador] = { Destaque = destaque, Painel = painel, LabelNome = labelNome, LabelDistancia = labelDistancia, BarraVida = barraVida, LabelArma = labelArma, LabelInventario = labelInventario, IconeArma = iconeArma }
    ESPLinhas[jogador] = linha
    
    local function AtualizarAdornee()
        local personagem = jogador.Character
        if personagem then
            destaque.Adornee = personagem
            painel.Adornee = personagem:FindFirstChild("Head")
            painel.Parent = personagem
        else
            destaque.Adornee = nil
            painel.Adornee = nil
            painel.Parent = nil
        end
    end
    
    if jogador.Character then
        AtualizarAdornee()
    end
    jogador.CharacterAdded:Connect(AtualizarAdornee)
    jogador.CharacterRemoving:Connect(function()
        destaque.Adornee = nil
        painel.Adornee = nil
        painel.Parent = nil
    end)
end

local function AtualizarESP()
    local alvoAtual = ConfiguracoesAimbotDiscreto.AlvoAtual or ConfiguracoesAimbotAgressivo.AlvoAtual
    local centroTela = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local tempo = tick()
    
    for jogador, esp in pairs(ESPHighlights) do
        local personagem = jogador.Character
        local linha = ESPLinhas[jogador]
        if ConfiguracoesESP.Ativado and personagem and not (ConfiguracoesESP.IgnorarTime and EhDoMesmoTime(jogador)) then
            local vivo = EstaVivo(personagem)
            if vivo then
                local raiz = personagem:FindFirstChild("HumanoidRootPart")
                local cabeca = personagem:FindFirstChild("Head")
                local humanoide = personagem:FindFirstChild("Humanoid")
                if raiz and cabeca and humanoide then
                    local dist = (raiz.Position - Camera.CFrame.Position).Magnitude
                    local cor = ConfiguracoesESP.DestacarAlvoAimbot and alvoAtual and alvoAtual.Parent == personagem and Color3.fromRGB(255, 255, 0) or ObterCorESP(personagem)
                    local corVida = ObterCorVida(personagem)
                    local tamanho = math.clamp(130 / (dist / 100), 60, 180) * ConfiguracoesESP.TamanhoTexto
                    local opacidadeContorno = ConfiguracoesESP.AnimacaoPulsante and alvoAtual and alvoAtual.Parent == personagem and (0.7 + 0.3 * math.sin(tempo * 3)) or ConfiguracoesESP.OpacidadeContorno
                    local espessuraContorno = alvoAtual and alvoAtual.Parent == personagem and 2.0 or 1.0
                    
                    esp.Destaque.Adornee = personagem
                    esp.Destaque.FillColor = cor
                    esp.Destaque.OutlineColor = cor
                    esp.Destaque.FillTransparency = ConfiguracoesESP.TransparenciaCaixa
                    esp.Destaque.OutlineTransparency = ConfiguracoesESP.ContornoNeon and opacidadeContorno or 1
                    esp.Destaque.Enabled = ConfiguracoesESP.MostrarCaixas
                    
                    esp.Painel.Adornee = cabeca
                    esp.Painel.Size = UDim2.new(0, tamanho, 0, tamanho / 1.5)
                    
                    local alturaBase = 2
                    if ConfiguracoesESP.MostrarNomes then
                        esp.LabelNome.Text = jogador.Name
                        esp.LabelNome.TextColor3 = cor
                        esp.LabelNome.Visible = true
                        esp.LabelNome.Position = UDim2.new(0, 0, 0, 0)
                        esp.Painel.StudsOffset = ObterOffsetPosicao(ConfiguracoesESP.PosicaoNome, alturaBase, "Nome")
                    else
                        esp.LabelNome.Visible = false
                    end
                    
                    if ConfiguracoesESP.MostrarDistancia then
                        esp.LabelDistancia.Text = math.floor(dist) .. " studs"
                        esp.LabelDistancia.TextColor3 = cor
                        esp.LabelDistancia.Visible = true
                        esp.LabelDistancia.Position = UDim2.new(0, 0, 0.25, 0)
                        esp.Painel.StudsOffset = ObterOffsetPosicao(ConfiguracoesESP.PosicaoDistancia, alturaBase, "Distancia")
                    else
                        esp.LabelDistancia.Visible = false
                    end
                    
                    if ConfiguracoesESP.MostrarVida then
                        local porcentagemVida = humanoide.Health / humanoide.MaxHealth
                        esp.BarraVida.Size = UDim2.new(porcentagemVida, 0, 0.15, 0)
                        esp.BarraVida.BackgroundColor3 = corVida
                        esp.BarraVida.Visible = true
                        esp.BarraVida.Position = UDim2.new(0, 0, 0.5, 0)
                        esp.Painel.StudsOffset = ObterOffsetPosicao(ConfiguracoesESP.PosicaoVida, alturaBase, "Vida")
                    else
                        esp.BarraVida.Visible = false
                    end
                    
                    if ConfiguracoesESP.MostrarArma then
                        local ferramenta = personagem:FindFirstChildOfClass("Tool")
                        esp.LabelArma.Text = ferramenta and ferramenta.Name or "Nenhuma arma"
                        esp.LabelArma.TextColor3 = cor
                        esp.LabelArma.Visible = true
                        esp.LabelArma.Position = UDim2.new(0, 0, 0.75, 0)
                        esp.Painel.StudsOffset = ObterOffsetPosicao(ConfiguracoesESP.PosicaoArma, alturaBase, "Arma")
                        
                        if ConfiguracoesESP.IconeArma and ferramenta then
                            esp.IconeArma.Image = ArmaIcones[ferramenta.Name] or "rbxassetid://0"
                            esp.IconeArma.Visible = true
                            esp.IconeArma.Position = UDim2.new(1, 5, 0.75, 0)
                        else
                            esp.IconeArma.Visible = false
                        end
                    else
                        esp.LabelArma.Visible = false
                        esp.IconeArma.Visible = false
                    end
                    
                    if ConfiguracoesESP.MostrarInventario then
                        esp.LabelInventario.Text = "Inv: " .. ObterInventario(jogador)
                        esp.LabelInventario.TextColor3 = cor
                        esp.LabelInventario.Visible = true
                        esp.LabelInventario.Position = UDim2.new(0, 0, 1.0, 0)
                        esp.Painel.StudsOffset = ObterOffsetPosicao("Abaixo", alturaBase, "Inventario")
                    else
                        esp.LabelInventario.Visible = false
                    end
                    
                    esp.Painel.Enabled = ConfiguracoesESP.MostrarNomes or ConfiguracoesESP.MostrarDistancia or ConfiguracoesESP.MostrarVida or ConfiguracoesESP.MostrarArma or ConfiguracoesESP.MostrarInventario
                    
                    if ConfiguracoesESP.MostrarLinhas and linha then
                        local posTela, naTela = Camera:WorldToViewportPoint(raiz.Position)
                        if naTela then
                            linha.From = Vector2.new(centroTela.X, Camera.ViewportSize.Y)
                            linha.To = Vector2.new(posTela.X, posTela.Y)
                            linha.Color = cor
                            linha.Thickness = alvoAtual and alvoAtual.Parent == personagem and ConfiguracoesESP.EspessuraLinha * 1.5 or ConfiguracoesESP.EspessuraLinha
                            linha.Visible = true
                        else
                            linha.Visible = false
                        end
                    else
                        linha.Visible = false
                    end
                else
                    esp.Destaque.Enabled = false
                    esp.Painel.Enabled = false
                    linha.Visible = false
                end
            else
                esp.Destaque.Enabled = false
                esp.Painel.Enabled = false
                linha.Visible = false
            end
        else
            esp.Destaque.Enabled = false
            esp.Painel.Enabled = false
            linha.Visible = false
        end
    end
end

local ConexaoESP
local function AlternarESP(ativado)
    ConfiguracoesESP.Ativado = ativado
    if ativado then
        for _, jogador in ipairs(Players:GetPlayers()) do
            if jogador ~= LocalPlayer then
                CriarESP(jogador)
            end
        end
        Players.PlayerAdded:Connect(function(jogador)
            if jogador ~= LocalPlayer then
                CriarESP(jogador)
            end
        end)
        Players.PlayerRemoving:Connect(function(jogador)
            if ESPHighlights[jogador] then
                ESPHighlights[jogador].Destaque:Destroy()
                ESPHighlights[jogador].Painel:Destroy()
                ESPLinhas[jogador]:Remove()
                ESPHighlights[jogador] = nil
                ESPLinhas[jogador] = nil
            end
        end)
        ConexaoESP = RunService.RenderStepped:Connect(AtualizarESP)
    else
        if ConexaoESP then
            ConexaoESP:Disconnect()
            ConexaoESP = nil
        end
        for jogador, esp in pairs(ESPHighlights) do
            if esp.Destaque then esp.Destaque:Destroy() end
            if esp.Painel then esp.Painel:Destroy() end
            if ESPLinhas[jogador] then ESPLinhas[jogador]:Remove() end
        end
        ESPHighlights = {}
        ESPLinhas = {}
    end
end

-- Interface
local AbaDiscreto = Window:MakeTab({"Aimbot Discreto", "crosshair"})
local AbaAgressivo = Window:MakeTab({"Aimbot Agressivo", "target"})
local AbaESP = Window:MakeTab({"Visuais", "eye"})

-- Aba Aimbot Discreto
local SecaoMiraDiscreto = AbaDiscreto:AddSection({"Mira"})
AbaDiscreto:AddToggle({
    Name = "Ativar",
    Description = "Mira suave",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.Ativado = Valor
        AlternarAimbotDiscreto(Valor)
        if Valor then AlternarAimbotAgressivo(false) end
    end
})

AbaDiscreto:AddSlider({
    Name = "Suavidade",
    Description = "Velocidade da mira",
    Min = 5,
    Max = 15,
    Increase = 0.5,
    Default = 8.0,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.Suavidade = Valor
    end
})

AbaDiscreto:AddSlider({
    Name = "Suavização Extra",
    Description = "Reduz tremores",
    Min = 0.5,
    Max = 1.0,
    Increase = 0.1,
    Default = 0.7,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.SuavizacaoExtra = Valor
    end
})

AbaDiscreto:AddToggle({
    Name = "Prever Movimento",
    Description = "Compensa movimento",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.PreverMovimento = Valor
    end
})

AbaDiscreto:AddTextBox({
    Name = "Força Previsão",
    Description = "Intensidade (120 padrão)",
    PlaceholderText = "120",
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.FatorPrevisao = tonumber(Valor) or 120
    end
})

AbaDiscreto:AddToggle({
    Name = "Limitar FPS",
    Description = "Reduz lag (60 FPS)",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.LimitarFPS = Valor
    end
})

local SecaoAlvoDiscreto = AbaDiscreto:AddSection({"Alvo"})
AbaDiscreto:AddSlider({
    Name = "Distância Máxima",
    Description = "Alcance em studs",
    Min = 50,
    Max = 1000,
    Increase = 50,
    Default = 500,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.DistanciaMaxima = Valor
    end
})

AbaDiscreto:AddSlider({
    Name = "Campo de Visão",
    Description = "Área de detecção",
    Min = 50,
    Max = 300,
    Increase = 10,
    Default = 150,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.CampoDeVisao = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddDropdown({
    Name = "Parte do Corpo",
    Description = "Ponto de mira",
    Options = {"Head (Cabeça)", "UpperTorso (Torso)", "HumanoidRootPart (Centro)", "LowerTorso (Base)"},
    Default = "Head (Cabeça)",
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.ParteDoCorpo = string.match(Valor, "^(%w+)")
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddDropdown({
    Name = "Prioridade",
    Description = "Seleção de alvo",
    Options = {"Automático", "Vida Baixa", "Mais Próximo", "Ameaça"},
    Default = "Automático",
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.ModoPrioridade = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddSlider({
    Name = "Vida Baixa (%)",
    Description = "Priorizar vida até",
    Min = 10,
    Max = 50,
    Increase = 5,
    Default = 40,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.LimiteVidaBaixa = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddSlider({
    Name = "Distância Próxima",
    Description = "Priorizar alvos até",
    Min = 50,
    Max = 500,
    Increase = 10,
    Default = 100,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.LimiteDistanciaProxima = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

local SecaoFiltrosPrimariosDiscreto = AbaDiscreto:AddSection({"Filtros Primários"})
AbaDiscreto:AddToggle({
    Name = "Ignorar Time",
    Description = "Evita aliados",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.IgnorarTime = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddToggle({
    Name = "Ignorar Mortos",
    Description = "Evita mortos",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.IgnorarMortos = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddToggle({
    Name = "Ignorar Paredes",
    Description = "Mira alvos visíveis",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.IgnorarParedes = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddToggle({
    Name = "Ignorar ForceField",
    Description = "Evita alvos com escudo",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.IgnorarForceField = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

local SecaoFiltrosSecundariosDiscreto = AbaDiscreto:AddSection({"Filtros Secundários"})
AbaDiscreto:AddToggle({
    Name = "Ignorar Vivos",
    Description = "Mira apenas mortos",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.IgnorarVivos = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddToggle({
    Name = "Ignorar Amigos",
    Description = "Evita amigos",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.IgnorarAmigos = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

AbaDiscreto:AddToggle({
    Name = "Prioridade Ameaça",
    Description = "Prioriza armas (se detectável)",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotDiscreto.PrioridadeAmeaca = Valor
        ConfiguracoesAimbotDiscreto.AlvoAtual = nil
    end
})

-- Aba Aimbot Agressivo
local SecaoMiraAgressivo = AbaAgressivo:AddSection({"Mira"})
AbaAgressivo:AddToggle({
    Name = "Ativar",
    Description = "Mira instantânea",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.Ativado = Valor
        AlternarAimbotAgressivo(Valor)
        if Valor then AlternarAimbotDiscreto(false) end
    end
})

AbaAgressivo:AddSlider({
    Name = "Suavização Extra",
    Description = "Reduz tremores",
    Min = 0.5,
    Max = 1.0,
    Increase = 0.1,
    Default = 0.9,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.SuavizacaoExtra = Valor
    end
})

AbaAgressivo:AddToggle({
    Name = "Prever Movimento",
    Description = "Compensa movimento",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.PreverMovimento = Valor
    end
})

AbaAgressivo:AddTextBox({
    Name = "Força Previsão",
    Description = "Intensidade (120 padrão)",
    PlaceholderText = "120",
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.FatorPrevisao = tonumber(Valor) or 120
    end
})

AbaAgressivo:AddToggle({
    Name = "Limitar FPS",
    Description = "Reduz lag (60 FPS)",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.LimitarFPS = Valor
    end
})

local SecaoAlvoAgressivo = AbaAgressivo:AddSection({"Alvo"})
AbaAgressivo:AddSlider({
    Name = "Distância Máxima",
    Description = "Alcance em studs",
    Min = 50,
    Max = 2000,
    Increase = 50,
    Default = 500,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.DistanciaMaxima = Valor
    end
})

AbaAgressivo:AddSlider({
    Name = "Campo de Visão",
    Description = "Área de detecção",
    Min = 100,
    Max = 1000,
    Increase = 10,
    Default = 500,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.CampoDeVisao = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddDropdown({
    Name = "Parte do Corpo",
    Description = "Ponto de mira",
    Options = {"Head (Cabeça)", "UpperTorso (Torso)", "HumanoidRootPart (Centro)", "LowerTorso (Base)"},
    Default = "Head (Cabeça)",
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.ParteDoCorpo = string.match(Valor, "^(%w+)")
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddDropdown({
    Name = "Prioridade",
    Description = "Seleção de alvo",
    Options = {"Automático", "Vida Baixa", "Mais Próximo", "Ameaça"},
    Default = "Automático",
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.ModoPrioridade = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddSlider({
    Name = "Vida Baixa (%)",
    Description = "Priorizar vida até",
    Min = 10,
    Max = 50,
    Increase = 5,
    Default = 40,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.LimiteVidaBaixa = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddSlider({
    Name = "Distância Próxima",
    Description = "Priorizar alvos até",
    Min = 50,
    Max = 500,
    Increase = 10,
    Default = 100,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.LimiteDistanciaProxima = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

local SecaoFiltrosPrimariosAgressivo = AbaAgressivo:AddSection({"Filtros Primários"})
AbaAgressivo:AddToggle({
    Name = "Ignorar Time",
    Description = "Evita aliados",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.IgnorarTime = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddToggle({
    Name = "Ignorar Mortos",
    Description = "Evita mortos",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.IgnorarMortos = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddToggle({
    Name = "Ignorar Paredes",
    Description = "Mira alvos visíveis",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.IgnorarParedes = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddToggle({
    Name = "Ignorar ForceField",
    Description = "Evita alvos com escudo",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.IgnorarForceField = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

local SecaoFiltrosSecundariosAgressivo = AbaAgressivo:AddSection({"Filtros Secundários"})
AbaAgressivo:AddToggle({
    Name = "Ignorar Vivos",
    Description = "Mira apenas mortos",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.IgnorarVivos = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddToggle({
    Name = "Ignorar Amigos",
    Description = "Evita amigos",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.IgnorarAmigos = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

AbaAgressivo:AddToggle({
    Name = "Prioridade Ameaça",
    Description = "Prioriza armas (se detectável)",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesAimbotAgressivo.PrioridadeAmeaca = Valor
        ConfiguracoesAimbotAgressivo.AlvoAtual = nil
    end
})

-- Aba Visuais
local SecaoVisualESP = AbaESP:AddSection({"Visual"})
AbaESP:AddToggle({
    Name = "Ativar ESP",
    Description = "Visão avançada",
    Default = false,
    Callback = function(Valor)
        AlternarESP(Valor)
    end
})

AbaESP:AddToggle({
    Name = "Nomes",
    Description = "Exibe nome",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarNomes = Valor
    end
})

AbaESP:AddDropdown({
    Name = "Posição Nome",
    Description = "Onde exibir nome",
    Options = {"Acima", "Abaixo", "Esquerda", "Direita"},
    Default = "Acima",
    Callback = function(Valor)
        ConfiguracoesESP.PosicaoNome = Valor
    end
})

AbaESP:AddToggle({
    Name = "Distância",
    Description = "Exibe distância",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarDistancia = Valor
    end
})

AbaESP:AddDropdown({
    Name = "Posição Distância",
    Description = "Onde exibir distância",
    Options = {"Acima", "Abaixo", "Esquerda", "Direita"},
    Default = "Abaixo",
    Callback = function(Valor)
        ConfiguracoesESP.PosicaoDistancia = Valor
    end
})

AbaESP:AddToggle({
    Name = "Vida",
    Description = "Exibe barra de vida",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarVida = Valor
    end
})

AbaESP:AddDropdown({
    Name = "Posição Vida",
    Description = "Onde exibir vida",
    Options = {"Acima", "Abaixo", "Esquerda", "Direita"},
    Default = "Esquerda",
    Callback = function(Valor)
        ConfiguracoesESP.PosicaoVida = Valor
    end
})

AbaESP:AddToggle({
    Name = "Arma Equipada",
    Description = "Exibe arma equipada",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarArma = Valor
    end
})

AbaESP:AddDropdown({
    Name = "Posição Arma",
    Description = "Onde exibir arma",
    Options = {"Acima", "Abaixo", "Esquerda", "Direita"},
    Default = "Direita",
    Callback = function(Valor)
        ConfiguracoesESP.PosicaoArma = Valor
    end
})

AbaESP:AddToggle({
    Name = "Inventário",
    Description = "Exibe armas no inventário",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarInventario = Valor
    end
})

local SecaoEstiloESP = AbaESP:AddSection({"Estilo"})
AbaESP:AddToggle({
    Name = "Caixas",
    Description = "Contorno neon",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarCaixas = Valor
    end
})

AbaESP:AddSlider({
    Name = "Transparência Caixa",
    Description = "Ajusta opacidade",
    Min = 0.3,
    Max = 0.8,
    Increase = 0.1,
    Default = 0.5,
    Callback = function(Valor)
        ConfiguracoesESP.TransparenciaCaixa = Valor
    end
})

AbaESP:AddToggle({
    Name = "Contorno Neon",
    Description = "Borda neon",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.ContornoNeon = Valor
    end
})

AbaESP:AddSlider({
    Name = "Opacidade Contorno",
    Description = "Ajusta contorno",
    Min = 0.5,
    Max = 1.0,
    Increase = 0.1,
    Default = 0.7,
    Callback = function(Valor)
        ConfiguracoesESP.OpacidadeContorno = Valor
    end
})

AbaESP:AddToggle({
    Name = "Animação Pulsante",
    Description = "Contorno pulsante",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.AnimacaoPulsante = Valor
    end
})

AbaESP:AddToggle({
    Name = "Linhas (Tracers)",
    Description = "Linhas até alvos",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesESP.MostrarLinhas = Valor
    end
})

AbaESP:AddSlider({
    Name = "Espessura Linha",
    Description = "Grossura das linhas",
    Min = 1,
    Max = 3,
    Increase = 0.1,
    Default = 1.2,
    Callback = function(Valor)
        ConfiguracoesESP.EspessuraLinha = Valor
    end
})

AbaESP:AddSlider({
    Name = "Tamanho Texto",
    Description = "Tamanho do texto",
    Min = 0.5,
    Max = 1.5,
    Increase = 0.1,
    Default = 1.0,
    Callback = function(Valor)
        ConfiguracoesESP.TamanhoTexto = Valor
    end
})

AbaESP:AddToggle({
    Name = "Sombra Texto",
    Description = "Adiciona sombra",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.SombraTexto = Valor
    end
})

AbaESP:AddToggle({
    Name = "Ícone de Arma",
    Description = "Exibe ícone da arma",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.IconeArma = Valor
    end
})

local SecaoFiltrosESP = AbaESP:AddSection({"Filtros"})
AbaESP:AddToggle({
    Name = "Cor por Time",
    Description = "Verde para aliados",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.CorTime = Valor
    end
})

AbaESP:AddToggle({
    Name = "Destacar Alvo Aimbot",
    Description = "Destaca alvo do aimbot",
    Default = true,
    Callback = function(Valor)
        ConfiguracoesESP.DestacarAlvoAimbot = Valor
    end
})

AbaESP:AddToggle({
    Name = "Ignorar Time",
    Description = "Esconde ESP de aliados",
    Default = false,
    Callback = function(Valor)
        ConfiguracoesESP.IgnorarTime = Valor
    end
})

-- Inicialização
for _, jogador in ipairs(Players:GetPlayers()) do
    if jogador ~= LocalPlayer then
        CriarESP(jogador)
    end
end
