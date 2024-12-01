# Lista de aplicativos para instalar via Winget
$apps = @(
    @{ Name = "7-Zip"; Command = "7zip.7zip" },
    @{ Name = "DBeaver"; Command = "dbeaver.dbeaver" },
    @{ Name = "Java JDK 18"; Command = "EclipseAdoptium.Temurin.18.JDK" },
    @{ Name = "Google Chrome"; Command = "Google.Chrome" },
    @{ Name = "Lightshot"; Command = "Skillbrains.Lightshot" }, # ID corrigido
    @{ Name = "LibreOffice"; Command = "TheDocumentFoundation.LibreOffice" },
    @{ Name = "OneDrive"; Command = "Microsoft.OneDrive" },
    @{ Name = "Teams"; Command = "Microsoft.Teams" },
    @{ Name = "Visual Studio Code"; Command = "Microsoft.VisualStudioCode" },
    @{ Name = "MobaXterm"; Command = "Mobatek.MobaXterm" },
    @{ Name = "Postman"; Command = "Postman.Postman" },
    @{ Name = "PowerShell"; Command = "Microsoft.PowerShell" },
    @{ Name = "Python 3.13"; Command = "Python.Python.3.13" },
    @{ Name = "Sublime Text 4"; Command = "SublimeHQ.SublimeText.4" }
)

# Inicializa a lista de seleção com todos os aplicativos desmarcados
$selectedApps = @($false) * $apps.Count
$position = 0  # Controla a posição atual no menu
$exitMenu = $false  # Controle explícito para sair do loop do menu

Function Show-Menu {
    Clear-Host
    Write-Host "Menu de Seleção de Aplicativos para Instalação" -ForegroundColor Cyan
    Write-Host "------------------------------------------------"
    Write-Host "Use as setas ↑/↓ para navegar, Barra de Espaço para selecionar."
    Write-Host "Pressione Enter para iniciar a instalação." -ForegroundColor Yellow
    Write-Host "------------------------------------------------"

    for ($i = 0; $i -lt $apps.Count; $i++) {
        $prefix = if ($i -eq $position) { ">" } else { " " }
        $status = if ($selectedApps[$i]) { "[X]" } else { "[ ]" }
        Write-Host "$prefix $status $($apps[$i].Name)"
    }

    Write-Host "------------------------------------------------"
    Write-Host "Teclas disponíveis: ↑ (Seta para cima), ↓ (Seta para baixo), Barra de Espaço, Enter"
}

Function Install-App {
    param (
        [string]$Name,
        [string]$Command
    )

    Write-Host "Iniciando instalação do aplicativo: $Name..." -ForegroundColor Cyan

    # Executa o Winget e captura a saída
    $wingetOutput = & winget install --id=$Command --exact --silent --accept-source-agreements --accept-package-agreements --force 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "Aplicativo $Name instalado com sucesso!" -ForegroundColor Green
    } elseif ($wingetOutput -match "Nenhum pacote encontrou os critérios de entrada correspondentes") {
        Write-Host "Erro: Aplicativo $Name não encontrado no repositório Winget." -ForegroundColor Red
    } else {
        Write-Host "Erro ao instalar o aplicativo $Name. Código de saída: $exitCode" -ForegroundColor Red
        Write-Host "Detalhes do erro: $wingetOutput" -ForegroundColor DarkGray
    }
}

# Loop para navegação e seleção
Do {
    Show-Menu
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Switch ($key.VirtualKeyCode) {
        38 { # Seta para cima
            $position = if ($position -gt 0) { $position - 1 } else { $apps.Count - 1 }
        }
        40 { # Seta para baixo
            $position = if ($position -lt ($apps.Count - 1)) { $position + 1 } else { 0 }
        }
        32 { # Barra de espaço para marcar/desmarcar
            $selectedApps[$position] = -not $selectedApps[$position]
        }
        13 { # Enter para confirmar
            $exitMenu = $true
        }
    }
} While (-not $exitMenu)

# Verifica se nenhum aplicativo foi selecionado
if ($selectedApps -notcontains $true) {
    Write-Host "Nenhum aplicativo foi selecionado. Encerrando o instalador." -ForegroundColor Red
    exit
}

# Início da instalação
Clear-Host
Write-Host "Iniciando a instalação dos aplicativos selecionados..." -ForegroundColor Green

for ($i = 0; $i -lt $apps.Count; $i++) {
    if ($selectedApps[$i]) {
        $app = $apps[$i]
        Install-App -Name $app.Name -Command $app.Command
    }
}

Write-Host "Instalação concluída!" -ForegroundColor Green
Read-Host "Pressione Enter para sair"
