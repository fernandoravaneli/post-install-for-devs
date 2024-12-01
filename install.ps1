# --------------------------------------------
# Função: Carregar Aplicativos do Arquivo apps.txt
# --------------------------------------------
Function Load-AppsFromFile {
    param (
        [string]$FilePath = ".\apps.txt" # Caminho padrão do arquivo
    )

    # Verifica se o arquivo existe
    if (-not (Test-Path $FilePath)) {
        Write-Host "Erro: O arquivo de aplicativos '$FilePath' não foi encontrado." -ForegroundColor Red
        exit
    }

    # Lê o arquivo e converte as linhas em objetos
    $apps = @()
    $content = Get-Content $FilePath
    foreach ($line in $content | Select-Object -Skip 1) { # Ignora o cabeçalho
        $parts = $line -split ";"
        $apps += [PSCustomObject]@{
            Name    = $parts[0]
            Command = $parts[1]
        }
    }

    return $apps
}

# --------------------------------------------
# Função: Adicionar App pelo Winget
# --------------------------------------------
Function Add-AppFromWinget {
    param (
        [string]$FilePath = ".\apps.txt" # Caminho padrão do arquivo
    )

    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         ADICIONAR NOVO APP PELO WINGET       " -ForegroundColor Yellow
    Write-Host "============================================="

    # Solicita o termo de busca ao usuário
    $searchTerm = Read-Host "Digite o nome ou parte do nome do aplicativo que deseja buscar no Winget"
    if (-not $searchTerm) {
        Write-Host "Nenhuma busca realizada. Retornando ao menu de instalação." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    # Realiza a busca no Winget
    Write-Host "Buscando aplicativos no Winget com o termo: '$searchTerm'..." -ForegroundColor Cyan
    $wingetOutput = winget search $searchTerm 2>&1

    # Processa a saída para extrair resultados válidos
    $results = $wingetOutput |
        Where-Object { $_ -match '^\S+\s+\S+\s+\S+' } | # Exclui linhas que não têm conteúdo significativo
        Select-Object -Skip 2 |                       # Ignora os cabeçalhos
        ForEach-Object {
            $line = $_ -replace '\s{2,}', ';'         # Substitui espaços extras por ";"
            $columns = $line -split ';'
            if ($columns.Count -ge 3) { # Inclui "Name", "Id" e "Version"
                [PSCustomObject]@{
                    Name    = $columns[0]
                    Id      = $columns[1]
                    Version = $columns[2]
                }
            }
        }

    # Filtra os resultados para garantir que o termo de busca esteja na coluna "Id"
    $filteredResults = $results | Where-Object { $_.Id -like "*$searchTerm*" }
    if (-not $filteredResults) {
        Write-Host "Nenhum aplicativo válido encontrado com o termo '$searchTerm' na coluna ID." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    # Exibe os resultados da busca em um formato similar ao Winget
    Write-Host ""
    Write-Host "Resultados Encontrados:" -ForegroundColor Cyan
    Write-Host "Nome                       ID                                Versão"
    Write-Host "--------------------------------------------------------------------------------"
    $index = 1
    $appOptions = @()
    foreach ($result in $filteredResults) {
        Write-Host ("[{0}] {1,-25} {2,-35} {3}" -f $index, $result.Name, $result.Id, $result.Version)
        $appOptions += $result
        $index++
    }
    Write-Host ""

    # Solicita ao usuário para selecionar um dos aplicativos
    $selectedIndex = Read-Host "Digite o número do aplicativo desejado (1-$($appOptions.Count))"
    if (-not $selectedIndex -or $selectedIndex -notmatch '^\d+$' -or $selectedIndex -lt 1 -or $selectedIndex -gt $appOptions.Count) {
        Write-Host "Seleção inválida. Retornando ao menu de instalação." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    # Obtém o aplicativo selecionado
    $selectedApp = $appOptions[$selectedIndex - 1]

    # Adiciona o aplicativo ao arquivo apps.txt
    $appName = $selectedApp.Name
    $appCommand = $selectedApp.Id
    Add-Content -Path $FilePath -Value "$appName;$appCommand"

    Write-Host "O aplicativo '$appName' foi adicionado ao arquivo 'apps.txt' com sucesso!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# --------------------------------------------
# Função: Menu de Seleção de Aplicativos
# --------------------------------------------
Function Show-Menu {
    param (
        [array]$Apps,       # Lista de aplicativos carregados
        [array]$SelectedApps, # Lista para armazenar seleções
        [string]$FilePath = ".\apps.txt" # Caminho do arquivo de apps
    )

    Clear-Host
    Write-Host "Menu de Seleção de Aplicativos para Instalação" -ForegroundColor Cyan
    Write-Host "------------------------------------------------"
    Write-Host "Use as setas ↑/↓ para navegar, Barra de Espaço para selecionar."
    Write-Host "Pressione Enter para iniciar a instalação." -ForegroundColor Yellow
    Write-Host "[A] Adicionar novo app pelo Winget" -ForegroundColor Green
    Write-Host "[R] Remover app selecionado" -ForegroundColor Red
    Write-Host "------------------------------------------------"

    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $prefix = if ($i -eq $position) { ">" } else { " " }
        $status = if ($SelectedApps[$i]) { "[X]" } else { "[ ]" }
        Write-Host "$prefix $status $($Apps[$i].Name)"
    }

    Write-Host "------------------------------------------------"
    Write-Host "Teclas disponíveis: ↑ (Seta para cima), ↓ (Seta para baixo), Barra de Espaço, Enter, A, R"
}

# --------------------------------------------
# Função: Remover App Selecionado
# --------------------------------------------
Function Remove-AppFromList {
    param (
        [int]$SelectedIndex, # Índice do aplicativo selecionado
        [array]$Apps,        # Lista de aplicativos carregados
        [string]$FilePath = ".\apps.txt" # Caminho do arquivo de apps
    )

    # Obtém o aplicativo selecionado
    $appToRemove = $Apps[$SelectedIndex]
    $appDisplay = "$($appToRemove.Name);$($appToRemove.Command)"

    # Confirmação antes de excluir
    $confirmation = Read-Host "Tem certeza que deseja remover o aplicativo '$($appToRemove.Name)'? (S/N)"
    if ($confirmation -notmatch "^[Ss]$") {
        Write-Host "Remoção cancelada. Retornando ao menu..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return $Apps # Retorna a lista inalterada
    }

    # Remove o aplicativo selecionado da lista
    Write-Host "Removendo aplicativo: $appDisplay..." -ForegroundColor Yellow
    $newApps = $Apps | Where-Object { $_ -ne $appToRemove }

    # Atualiza o arquivo apps.txt
    $header = "Nome;Comando"
    $newContent = $newApps | ForEach-Object { "$($_.Name);$($_.Command)" }
    $header + $newContent | Set-Content -Path $FilePath

    Write-Host "O aplicativo '$($appToRemove.Name)' foi removido com sucesso!" -ForegroundColor Green
    Start-Sleep -Seconds 2
    return $newApps # Retorna a nova lista
}

# --------------------------------------------
# Função: Instalar Aplicativos
# --------------------------------------------
Function Install-Apps {
    $appsFilePath = ".\apps.txt"

    # Carrega os aplicativos do arquivo
    $apps = Load-AppsFromFile -FilePath $appsFilePath

    # Inicializa a lista de seleção
    $selectedApps = @($false) * $apps.Count
    $position = 0  # Posição inicial no menu
    $exitMenu = $false

# Loop do menu de instalação
Do {
    Show-Menu -Apps $apps -SelectedApps $selectedApps -FilePath $appsFilePath
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    Switch ($key.VirtualKeyCode) {
        38 { # Seta para cima
            $position = if ($position -gt 0) { $position - 1 } else { $apps.Count - 1 }
        }
        40 { # Seta para baixo
            $position = if ($position -lt ($apps.Count - 1)) { $position + 1 } else { 0 }
        }
        32 { # Barra de Espaço
            $selectedApps[$position] = -not $selectedApps[$position]
        }
        13 { # Enter para confirmar
            $exitMenu = $true
        }
        65 { # Tecla 'A' para adicionar novo app
            Add-AppFromWinget -FilePath $appsFilePath
            # Recarrega a lista de aplicativos após adicionar um novo
            $apps = Load-AppsFromFile -FilePath $appsFilePath
            $selectedApps = @($false) * $apps.Count
        }
        82 { # Tecla 'R' para remover o app selecionado
            $apps = Remove-AppFromList -SelectedIndex $position -Apps $apps -FilePath $appsFilePath
            $selectedApps = @($false) * $apps.Count # Reseta as seleções
            $position = 0 # Redefine a posição para o início
        }
    }
} While (-not $exitMenu)



    # Verifica se nenhum aplicativo foi selecionado
    if ($selectedApps -notcontains $true) {
        Write-Host "Nenhum aplicativo foi selecionado. Encerrando o instalador." -ForegroundColor Red
        return
    }

    # Início da Instalação
    Clear-Host
    Write-Host "Iniciando a instalação dos aplicativos selecionados..." -ForegroundColor Green

    for ($i = 0; $i -lt $apps.Count; $i++) {
        if ($selectedApps[$i]) {
            $app = $apps[$i]
            Install-App -Name $app.Name -Command $app.Command
        }
    }

    Write-Host "Instalação concluída!" -ForegroundColor Green
    Read-Host "Pressione Enter para retornar ao menu principal"
}

# --------------------------------------------
# Função: Instalar Aplicativo com Winget
# --------------------------------------------
Function Install-App {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,    # Nome do aplicativo
        [Parameter(Mandatory = $true)]
        [string]$Command  # Identificador do aplicativo no Winget
    )

    Write-Host "Iniciando instalação do aplicativo: $Name..." -ForegroundColor Cyan

    try {
        # Executa o Winget para instalar o aplicativo
        # Sem redirecionar a saída, para exibir a barra de progresso do Winget
        winget install --id=$Command --exact --accept-source-agreements --accept-package-agreements --force

        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host "Aplicativo $Name instalado com sucesso!" -ForegroundColor Green
        } elseif ($exitCode -eq 1) {
            Write-Host "Erro: Aplicativo $Name não encontrado ou não foi possível instalar." -ForegroundColor Red
        } elseif ($exitCode -eq 5) {
            Write-Host "Erro: Permissões insuficientes. Tente executar como administrador." -ForegroundColor Red
        } else {
            Write-Host "Erro desconhecido ao instalar o aplicativo $Name. Código de saída: $exitCode" -ForegroundColor Red
        }
    } catch {
        Write-Host "Erro inesperado ao tentar instalar o aplicativo ${Name}: $_" -ForegroundColor Red
    }
}

Function Install-WSL2 {
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         CONFIGURAR WSL 2 (Linux)            " -ForegroundColor Yellow
    Write-Host "============================================="

    Write-Host "Verificando o status do WSL 2 no sistema..." -ForegroundColor Cyan

    # Verifica se o WSL está disponível
    if (-not (Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "Microsoft-Windows-Subsystem-Linux" })) {
        Write-Host "O WSL não está habilitado. Habilitando agora..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    } else {
        Write-Host "WSL já está habilitado no sistema." -ForegroundColor Green
    }

    # Verifica se a Virtual Machine Platform está habilitada
    if (-not (Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "VirtualMachinePlatform" })) {
        Write-Host "Habilitando a Virtual Machine Platform (necessário para WSL 2)..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
    } else {
        Write-Host "Virtual Machine Platform já está habilitada." -ForegroundColor Green
    }

    # Define o WSL 2 como padrão
    Write-Host "Definindo WSL 2 como padrão para todas as distribuições..." -ForegroundColor Cyan
    wsl --set-default-version 2

    # Pergunta se o usuário deseja instalar o Ubuntu
    Write-Host "Deseja instalar o Ubuntu (distribuição Linux padrão)? (S/N)" -ForegroundColor Yellow
    $response = Read-Host "Digite S para instalar ou N para pular"
    if ($response -match "^[Ss]$") {
        Write-Host "Baixando e instalando o Ubuntu (distribuição padrão)..." -ForegroundColor Cyan
        winget install -e --id Canonical.Ubuntu
        Write-Host "Ubuntu instalado com sucesso! Você pode iniciá-lo usando o comando 'wsl' no terminal." -ForegroundColor Green
    } else {
        Write-Host "Instalação do Ubuntu ignorada. Você pode instalar outra distribuição posteriormente." -ForegroundColor Yellow
    }

    Write-Host "Configuração do WSL 2 concluída! Reinicie o sistema para garantir que todas as alterações sejam aplicadas." -ForegroundColor Green
    Read-Host "Pressione Enter para retornar ao menu principal"
}


# --------------------------------------------
# Menu Principal
# --------------------------------------------
Function Show-MainMenu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "               MENU PRINCIPAL                " -ForegroundColor Yellow
    Write-Host "============================================="
    Write-Host "[1] Instalar Aplicativos"
    Write-Host "[2] WSL 2 + Ubuntu"
    Write-Host "[3] Windows Terminal (Em breve)"
    Write-Host "[4] Sair"
    Write-Host "============================================="
    $choice = Read-Host "Escolha uma opção (1-4)"
    return $choice
}

# --------------------------------------------
# Execução do Menu Principal
# --------------------------------------------
Do {
    $choice = Show-MainMenu

    Switch ($choice) {
        "1" { Install-Apps } # Chama a função para instalação de aplicativos
        "2" {
            Install-WSL2
        }
        "3" {
            Write-Host "Opção Windows Terminal ainda não implementada. Em breve!" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "4" {
            Write-Host "Saindo... Até mais!" -ForegroundColor Green
            exit
        }
        Default {
            Write-Host "Opção inválida. Por favor, escolha entre 1 e 4." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} While ($true)
