-- SISTEMA UBER v7.0: WHISKY MENU (GUI & AutoFarm Integrado)
-- Criado por Gemini
-- Projetado para ser executado via loadstring(game:HttpGet("..."))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- CONFIGURAÇÕES E VARIÁVEIS DE CONTROLE
local emRotaInterno = false -- Trava do nosso script (se estamos em rota de teleporte)
local autoUberAtivo = false -- Controle do botão da GUI (se o script está rodando ou não)

local carro = nil
local delayEntrePontos = 1.0 
local raioDetecaoCarro = 15
local timeoutMonitor = 10 

local autoUberThread = nil -- Variável para armazenar a thread do Auto-Aceite/Monitor

-- =========================================================================
-- FUNÇÕES DE AUTOFARM (LÓGICA DA V6.3)
-- =========================================================================

function encontrarCarro()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Humanoid") then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if humanoid.SeatPart and (humanoid.SeatPart:IsA("VehicleSeat") or humanoid.SeatPart:IsA("Seat")) then
        local veiculo = humanoid.SeatPart.Parent
        if veiculo:IsA("Model") then
            return veiculo
        end
    end
    
    local hRoot = character:FindFirstChild("HumanoidRootPart")
    if hRoot then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("VehicleSeat") then
                local seat = obj:FindFirstChildOfClass("VehicleSeat")
                local distance = (hRoot.Position - seat.Position).Magnitude
                if distance < raioDetecaoCarro and seat.Occupant == nil then
                    hRoot.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
                    wait(0.5)
                    if seat.Occupant == humanoid then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

function executarRota()
    local ValorEmRota = LocalPlayer:FindFirstChild("Uber") and LocalPlayer.Uber:FindFirstChild("EmRota")
    if not ValorEmRota or emRotaInterno then return end 
    emRotaInterno = true
    
    print("[WHISKY] 🚗 Rota Iniciada.")

    local RotaClienteFolder = Workspace:FindFirstChild("Construcoes") and 
                              Workspace.Construcoes:FindFirstChild("LocaisCorrida") and 
                              Workspace.Construcoes.LocaisCorrida:FindFirstChild("RotasCliente")
    
    if not RotaClienteFolder then
        print("[WHISKY] ❌ Pasta 'RotasCliente' não encontrada. Rota cancelada.")
        emRotaInterno = false
        return
    end

    while ValorEmRota.Value and autoUberAtivo do -- Adicionada verificação de autoUberAtivo
        carro = encontrarCarro()
        if not carro or not carro.PrimaryPart then
            print("[WHISKY] ❌ Sem carro! Tentando re-entrar em 3s...")
            wait(3)
            if not encontrarCarro() then break end 
        end

        local pontos = RotaClienteFolder:GetChildren()

        if #pontos == 0 then
            wait(2) 
        else
            -- Ordenar os pontos
            table.sort(pontos, function(a, b)
                local nomeA = a.Name:lower()
                local nomeB = b.Name:lower()
                if nomeA == "pegar" then return true end
                if nomeB == "pegar" then return false end
                if nomeA == "final" then return false end
                if nomeB == "final" then return true end
                local numA = tonumber(nomeA) or 99
                local numB = tonumber(nomeB) or 99
                return numA < numB
            end)

            local pontoAtual = pontos[1]
            print("[WHISKY] 📍 Indo para: " .. pontoAtual.Name)
            
            pcall(function()
                carro:SetPrimaryPartCFrame(CFrame.new(pontoAtual.Position + Vector3.new(0, 3, 0)))
            end)
            
            wait(delayEntrePontos)
        end
    end
    
    print("[WHISKY] 🏁 Loop de rota finalizado.")
    emRotaInterno = false 
end

function configurarAutoAceitar()
    local EventoAceitar = ReplicatedStorage:WaitForChild("Uber", timeoutMonitor) and ReplicatedStorage.Uber:FindFirstChild("Aceitar")

    if not EventoAceitar then
        print("[WHISKY] ❌ RemoteEvent 'Aceitar' não encontrado.")
        return
    end
    
    print("[WHISKY] 💵 Auto-Aceitar VIGIANDO em loop.")

    while autoUberAtivo do -- Loop infinito enquanto o autoUberAtivo for true
        wait(0.5)
        
        if not emRotaInterno then
            local UiOferta = LocalPlayer.PlayerGui:FindFirstChild("Celular") and 
                             LocalPlayer.PlayerGui.Celular:FindFirstChild("Celular") and 
                             LocalPlayer.PlayerGui.Celular.Celular:FindFirstChild("Aplicativos") and
                             LocalPlayer.PlayerGui.Celular.Celular.Aplicativos:FindFirstChild("Uber") and
                             LocalPlayer.PlayerGui.Celular.Celular.Aplicativos.Uber:FindFirstChild("MenuPrincipal") and
                             LocalPlayer.PlayerGui.Celular.Celular.Aplicativos.Uber.MenuPrincipal:FindFirstChild("InfosOfertaRota")

            if UiOferta and UiOferta.Visible then
                local BotaoAceitar = UiOferta:FindFirstChild("Button") 
                
                if BotaoAceitar and BotaoAceitar.Visible and BotaoAceitar.AbsoluteTransparency < 1 then
                    
                    print("[WHISKY] ✅ OFERTA DETECTADA! Aceitando...")
                    EventoAceitar:FireServer()
                    emRotaInterno = true 
                    
                    wait(1) 
                end
            end
        end
    end
    print("[WHISKY] 😴 Auto-Aceitar parado.")
end

function monitorarStatusRota()
    local PlayerUberFolder = LocalPlayer:WaitForChild("Uber", timeoutMonitor)
    if not PlayerUberFolder then
        print("[WHISKY] ❌ Pasta 'Player.Uber' não encontrada.")
        return
    end
    
    local ValorEmRota = PlayerUberFolder:WaitForChild("EmRota", timeoutMonitor)
    if not ValorEmRota then
        print("[WHISKY] ❌ Valor 'Player.Uber.EmRota' não encontrado.")
        return
    end
    
    print("[WHISKY] 📍 Monitor de Rota ativo.")

    ValorEmRota.Changed:Connect(function(novoValor)
        if novoValor == true then
            if not emRotaInterno and autoUberAtivo then
                spawn(executarRota)
            end
        else
            emRotaInterno = false 
            print("[WHISKY] 🏁 Rota finalizada pelo jogo.")
        end
    end)
    
    -- Checagem inicial
    if ValorEmRota.Value == true and not emRotaInterno and autoUberAtivo then
        spawn(executarRota)
    end
end

-- =========================================================================
-- FUNÇÕES DE CONTROLE (INICIAR/PARAR)
-- =========================================================================

local function iniciarAutoUber()
    if autoUberAtivo then return end
    autoUberAtivo = true
    print("[WHISKY] 🟢 AUTO UBER ATIVADO!")
    
    -- Inicia as funções em uma nova thread.
    autoUberThread = spawn(function()
        spawn(monitorarStatusRota)
        spawn(configurarAutoAceitar)
    end)

    if BotaoAutoUber.TextButton then
        BotaoAutoUber.TextButton.Text = "AUTO UBER (ATIVO)"
    end
end

local function pararAutoUber()
    if not autoUberAtivo then return end
    autoUberAtivo = false
    emRotaInterno = false -- Desliga a trava de rota
    print("[WHISKY] 🔴 AUTO UBER DESATIVADO!")

    -- Tenta matar a thread antiga (pode não funcionar em todos os executores)
    if autoUberThread and typeof(autoUberThread) == "thread" then
        coroutine.close(autoUberThread) 
    end
    
    -- Se o ValorEmRota for true, a função executarRota irá parar no próximo loop
    
    if BotaoAutoUber.TextButton then
        BotaoAutoUber.TextButton.Text = "AUTO UBER (INATIVO)"
    end
end

-- =========================================================================
-- CRIAÇÃO DA INTERFACE GRÁFICA (GUI)
-- =========================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WhiskyMenuGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- 1. BOTÃO FLUTUANTE (Arrastável, "WY")
local BotaoFlutuante = Instance.new("Frame")
BotaoFlutuante.Name = "BotaoFlutuante"
BotaoFlutuante.Size = UDim2.new(0, 50, 0, 50)
BotaoFlutuante.Position = UDim2.new(1, -60, 0.5, -25) -- Canto direito
BotaoFlutuante.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
BotaoFlutuante.BorderSizePixel = 0
BotaoFlutuante.Parent = ScreenGui

local UICornerBotao = Instance.new("UICorner")
UICornerBotao.CornerRadius = UDim.new(0, 10)
UICornerBotao.Parent = BotaoFlutuante

local BotaoTexto = Instance.new("TextButton")
BotaoTexto.Text = "WY"
BotaoTexto.Size = UDim2.new(1, 0, 1, 0)
BotaoTexto.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
BotaoTexto.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoTexto.TextScaled = true
BotaoTexto.Font = Enum.Font.Code
BotaoTexto.TextStrokeTransparency = 0 -- Estilo
BotaoTexto.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
BotaoTexto.Parent = BotaoFlutuante

-- Script de arrastar (Drag script)
local dragging = false
local dragStart = nil
local originalPos = nil

BotaoTexto.MouseButton1Down:Connect(function()
    dragging = true
    dragStart = BotaoFlutuante.Position
    originalPos = BotaoFlutuante.AbsolutePosition
    BotaoTexto.TextTransparency = 0.5
end)

BotaoTexto.MouseButton1Up:Connect(function()
    if dragging then
        dragging = false
        BotaoTexto.TextTransparency = 0
    end
end)

BotaoTexto.MouseLeave:Connect(function()
    if not dragging then return end
    -- Se o mouse sair enquanto arrasta, a próxima ação (Mouse.Move) o moverá
end)

RunService.RenderStepped:Connect(function()
    if dragging then
        local mouse = LocalPlayer:GetMouse()
        local delta = mouse.AbsolutePosition - originalPos
        BotaoFlutuante.Position = UDim2.new(dragStart.X.Scale, dragStart.X.Offset + delta.X, dragStart.Y.Scale, dragStart.Y.Offset + delta.Y)
    end
end)

-- 2. JANELA PRINCIPAL (Menu)
local MenuPrincipal = Instance.new("Frame")
MenuPrincipal.Name = "MenuPrincipal"
MenuPrincipal.Size = UDim2.new(0, 250, 0, 200) -- Não tão grande
MenuPrincipal.Position = UDim2.new(0.5, -125, 0.5, -100) -- Centro da tela
MenuPrincipal.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MenuPrincipal.BorderSizePixel = 0
MenuPrincipal.Visible = false
MenuPrincipal.Parent = ScreenGui

local UICornerMenu = Instance.new("UICorner")
UICornerMenu.CornerRadius = UDim.new(0, 10)
UICornerMenu.Parent = MenuPrincipal

-- Título
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Header.BorderSizePixel = 0
Header.Parent = MenuPrincipal

local UICornerHeader = Instance.new("UICorner")
UICornerHeader.CornerRadius = UDim.new(0, 10)
UICornerHeader.Parent = Header

local Titulo = Instance.new("TextLabel")
Titulo.Text = "🥃 WHISKY MENU"
Titulo.Size = UDim2.new(1, 0, 1, 0)
Titulo.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
Titulo.Font = Enum.Font.Code
Titulo.TextScaled = true
Titulo.TextStrokeTransparency = 0
Titulo.Parent = Header

-- Botões de Funcionalidade
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 1, -50)
Container.Position = UDim2.new(0, 10, 0, 40)
Container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Container.BorderSizePixel = 0
Container.Parent = MenuPrincipal

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Parent = Container

-- Botão AUTO UBER (Alternância)
local BotaoAutoUber = Instance.new("Frame")
BotaoAutoUber.Name = "AutoUberToggle"
BotaoAutoUber.Size = UDim2.new(1, 0, 0, 30)
BotaoAutoUber.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
BotaoAutoUber.BorderSizePixel = 0
BotaoAutoUber.Parent = Container

local TextButton = Instance.new("TextButton")
TextButton.Name = "TextButton"
TextButton.Text = "AUTO UBER (INATIVO)"
TextButton.Size = UDim2.new(1, 0, 1, 0)
TextButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TextButton.Font = Enum.Font.SourceSans
TextButton.TextScaled = true
TextButton.Parent = BotaoAutoUber
BotaoAutoUber.TextButton = TextButton -- Referência
local autoUberOn = false

TextButton.MouseButton1Click:Connect(function()
    if autoUberOn then
        pararAutoUber()
    else
        iniciarAutoUber()
    end
    autoUberOn = not autoUberOn
end)

-- Conexão de Abrir/Fechar
BotaoTexto.MouseButton1Click:Connect(function()
    MenuPrincipal.Visible = not MenuPrincipal.Visible
    BotaoFlutuante.Visible = not MenuPrincipal.Visible
end)

-- Fecha o menu se ele for aberto no início, deixando apenas o botão flutuante
MenuPrincipal.Visible = false
BotaoFlutuante.Visible = true

print("[WHISKY] Interface (WY) carregada! Clique para abrir o menu.")

-- Inicia o monitor de carro
carro = encontrarCarro()
if carro then
    print("[WHISKY] ✅ Carro encontrado.")
else
    print("[WHISKY] ⚠️ Entre em um carro para começar.")
end
