param (
	[PARAMETER(Mandatory = $false)]
	[switch]$oneclick
)

$response = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet

if ($response) {
    Write-Host "Internet detected. Continue..." -ForegroundColor Green
} else {
    Write-Host "No internet detected! Restart script when internet will be available" -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit
}

$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition

# Initial settings
$oh_theme = 'night-owl'
$features = @{
    cmd        = [PSCustomObject]@{ status = '++'; description = 'Install Clink for CMD (oh-my-cmd)'; argument = '-cmd' }
    ps7        = [PSCustomObject]@{ status = '++'; description = 'Install latest powershell 7'; argument = '-ps7' }
    terminal   = [PSCustomObject]@{ status = '++'; description = 'Install WindowsTerminal'; argument = '-terminal' }
    ps_profile = [PSCustomObject]@{ status = '++'; description = 'Write powershell 5 and 7 profiles (you must do it later by yourself)'; argument = '-ps_profile' }
    nano       = [PSCustomObject]@{ status = '++'; description = 'Install nano editor for Windows'; argument = '-nano' }
}

# Colorized
function Write-StatusLine {
    param (
        [string]$status,
        [string]$lineText
    )
    $textColor = if ($status -eq '++') { 'Green' } else { 'Red' }
    Write-Host $lineText -ForegroundColor $textColor
}

function MainRun {
    $args_r = @()
    $args_r += "-oh_theme $($oh_theme)"
    $features.GetEnumerator() | ForEach-Object {
        if ($_.Value.status -eq '++') {
            $args_r += $_.Value.argument
        }
    }
    cls
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath\main.ps1`" $($args_r -join ' ')" -NoNewWindow -Wait
    exit
}

if ($oneclick){ MainRun }

# Main menu loop
do {
    cls
    Write-Host '----'
    Write-Host "Configs" -ForegroundColor Yellow
    Write-Host '----'
    Write-Host "1. Set oh_theme (current: " -NoNewline
    Write-Host "$oh_theme" -ForegroundColor Cyan -NoNewline
    Write-Host ")"
    $count = 2
    $features.GetEnumerator() | ForEach-Object {
        Write-StatusLine -status $_.Value.status -lineText "$count. $($_.Value.status) $($_.Value.description)"
        $count++
    }
    
    Write-Host '----'
    Write-Host "R. Run installation Script" -ForegroundColor Blue
    Write-Host "Q. Do nothing and exit" -ForegroundColor Red
    Write-Host '----'
    Write-Host 'Default choose - all functions enabled'
    Write-Host 'Choose option with numbers plus enter to disable/enable function'
    Write-Host 'Run script install with R option or Q for quit'
    Write-Host ''
    Write-Host ''
    $option = Read-Host "Enable or disable option (1-$($features.Count))"

    switch ($option) {
        '1' {
            cls
            Write-Host '----'
            Write-Host "Set oh_theme (current: " -NoNewline
            Write-Host "$oh_theme" -ForegroundColor Cyan -NoNewline
            Write-Host ")"
            Write-Host '----'
            $themes = @()
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes"
            if ($response) {
                foreach ($item in $response) {
                    if ($item.type -eq "file") {
                        $themes += $($item.name).Replace('.omp.json', '')
                    }
                }
            } else {
                Write-Host "No files found or request failed." -ForegroundColor Red
            }
    
            $count = 1
            $themes | ForEach-Object {
                Write-Host "$count. $_"
                $count++
            }

            Write-Host '----'
            Write-Host "B. Go back and set theme to $oh_theme"
            Write-Host '----'

            $choice = Read-Host "Select theme by number"

            if ($choice -eq 'B' -or $choice -eq 'b') {
                continue
            }

            if ($themes[$choice - 1] -and ($choice -gt 0)) {
                $oh_theme = $themes[$choice - 1]
            } else {
                Write-Host "Invalid selection. Try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        { $_ -in (2..5) } {
            $feature = $features.Keys | Select-Object -Index ($option - 2)
            if ($features[$feature].status -eq '++') {
                $features[$feature].status = '--'
            } else {
                $features[$feature].status = '++'
            }
        }
        'R' {
            MainRun
        }
        'Q' {
            exit
        }
        default {
            Write-Host "Invalid option. Please try again."
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
