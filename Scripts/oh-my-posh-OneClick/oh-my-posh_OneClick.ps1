if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $CommandLine = "-ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`" "
    Start-Process -FilePath powershell.exe -Verb Runas -ArgumentList $CommandLine
}

mode con: cols=105 lines=30

function Main {
	param (
	[PARAMETER(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$oh_theme = 'night-owl',
	[PARAMETER(Mandatory = $false)]
	[switch]$nano,
	[PARAMETER(Mandatory = $false)]
	[switch]$cmd,
	[PARAMETER(Mandatory = $false)]
	[switch]$ps7,
	[PARAMETER(Mandatory = $false)]
	[switch]$ps_profile,
	[PARAMETER(Mandatory = $false)]
	[switch]$terminal
)

	$savePath = "$env:TEMP\oh-my-posh_OneClick"

	if (-not (Test-Path $savePath)) {
		New-Item -Path $savePath -ItemType Directory -Force | Out-Null
	}

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	function Shout {
		param(
			[parameter(Mandatory = $true)]
			$text,
			$color
		)

		$date = (Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString()
		$finaltext = $date + ' ' + $text
		if ($color){
			Write-Host $finaltext -ForegroundColor $color
		} else {
			Write-Host $finaltext
		}
	}

	function GitHubParce {
		param(
			[PARAMETER(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			$username,
			[PARAMETER(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			$repo,
			[PARAMETER(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			$zip_name

		)
		
		$latestReleaseUrl = "https://api.github.com/repos/$username/$repo/releases/latest"
		if ($latestRelease -eq $null) {
			Shout "Error fetching release information. Check your network connection or repository." -color "Red"
			return
		}
		
		$latestRelease = Invoke-WebRequest -Uri $latestReleaseUrl | ConvertFrom-Json

		$link = $latestRelease.assets.browser_download_url | Select-String -Pattern "$zip_name" | select-object -First 1
		$link = $link.ToString().Trim()
		return $link
	}

	function Install-oh {
		if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
			Shout 'oh-my-posh is already installed. Skipping...'
			return
		}

		try {
			Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1')) 6>$null
		} catch {
			Shout "Error installing oh-my-posh. Rerun the script!" -color "Red"
			pause
			return
		}
		
		$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)
		$userPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
		$env:Path = $machinePath + ";" + $userPath
		
		if (!(Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
			Shout "oh-my-posh not installed! Rerun the script!" -color 'Red'
			pause
			return
		}
	}

	function Install-Pwsh {
		$releaseZipUrl = GitHubParce -username "PowerShell" -repo "PowerShell" -zip_name "-win-x64.msi"
		$fileName = $releaseZipUrl.Split('/')[-1]

		try {
			Start-BitsTransfer -Source $releaseZipUrl -Destination "$savePath\$fileName" -ErrorAction Stop | Out-Null
		} catch {
			Invoke-WebRequest -Uri $releaseZipUrl -OutFile "$savePath\$fileName" -ErrorAction Stop | Out-Null
		}

		Start-Process "$savePath\$fileName" `
					-ArgumentList "/quiet /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1" -Wait
	}

	function Install-Clink {
		$releaseZipUrl = GitHubParce -username "chrisant996" -repo "clink" -zip_name "clink.*.exe"
		$fileName = $releaseZipUrl.Split('/')[-1]
		
		try {
			Start-BitsTransfer -Source $releaseZipUrl -Destination "$savePath\$fileName" -ErrorAction Stop | Out-Null
		} catch {
			Invoke-WebRequest -Uri $releaseZipUrl -OutFile "$savePath\$fileName" -ErrorAction Stop | Out-Null
		}

		Start-Process -FilePath "$savePath\$fileName" -ArgumentList '/S'
		New-Item -Path "$env:LOCALAPPDATA\clink" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
		$cfg_path = "$env:LOCALAPPDATA/Programs/oh-my-posh/themes".Replace("\", "/")
		$scriptContent = @"
load(io.popen('oh-my-posh.exe --config="$cfg_path/$oh_theme.omp.json" --init --shell cmd'):read("*a"))()
"@
		$scriptContent | Out-File -FilePath "$env:LOCALAPPDATA\clink\oh-my-posh.lua" -Force -Encoding utf8
	}

	function Install-Nano {
		if (Get-Command nano -ErrorAction SilentlyContinue) {
			Shout 'Nano is already installed. Skipping...'
			return
		}

		$releaseZipUrl = GitHubParce -username "okibcn" -repo "nano-for-windows" -zip_name "nano-for-windows_win64*"
		$fileName = $releaseZipUrl.Split('/')[-1]

		try {
			Start-BitsTransfer -Source $releaseZipUrl -Destination "$savePath\$fileName" -ErrorAction Stop | Out-Null
		} catch {
			Invoke-WebRequest -Uri $releaseZipUrl -OutFile "$savePath\$fileName" -ErrorAction Stop | Out-Null
		}

		$archivePath = "$savePath\$fileName"
		$destinationPath = "$env:ProgramFiles\Nano"
		
		if (-not (Test-Path $destinationPath)) {
			New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
		}
		
		$shellApp = New-Object -ComObject Shell.Application
		$zipFile = $shellApp.NameSpace($archivePath)
		$destinationFolder = $shellApp.NameSpace($destinationPath)
		
		foreach ($item in $zipFile.Items()) {
			$destinationFolder.CopyHere($item, 0x0004 + 0x0010 + 0x0400)
		}
		
		$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
		$newPath = $currentPath + ";C:\Program Files\Nano"
		[System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
	}

	function Install-WindowsTerminal {
		if (Get-AppxPackage -Name Microsoft.WindowsTerminal) {
			Shout "Windows Terminal is installed. Skipping..."
		} else {
			$releaseZipUrl = GitHubParce -username "microsoft" -repo "terminal" -zip_name ".msixbundle"
			$fileName = $releaseZipUrl.Split('/')[-1]
		
			try {
				Start-BitsTransfer -Source $releaseZipUrl -Destination "$savePath\$fileName" -ErrorAction Stop | Out-Null
			} catch {
				Invoke-WebRequest -Uri $releaseZipUrl -OutFile "$savePath\$fileName" -ErrorAction Stop | Out-Null
			}
		
			try {
				Add-AppxPackage -Path "$savePath\$fileName" | Out-Null
			} catch {
				Shout "$($_.Exception.Message)" -color 'Red'
				Shout "WindowsTerminal is not installed. Skipping..." -color 'Red'
			}
		}
	}

	function Configure-WindowsTerminal {
		$get_wt = Get-AppxPackage -Name Microsoft.WindowsTerminal
		if ($get_wt){
			Shout 'Some preparation for WindowsTerminal'
			$wtExecutablePath = Join-Path -Path $($get_wt.InstallLocation) -ChildPath "wt.exe"
			if (Test-Path $wtExecutablePath) {
				Start-Process -FilePath $wtExecutablePath -WindowStyle Hidden
				Start-Sleep -Seconds 2
				Get-Process -Name WindowsTerminal | Stop-Process

				if (Test-Path -Path "$($get_wt.InstallLocation)"){
					$file_path =  "$env:localappdata\Packages\$($get_wt.PackageFamilyName)\LocalState\settings.json"
					$jsonContent = Get-Content $file_path
					$newContent = $jsonContent -replace '"defaults": \{\},', `
					'"defaults": {
								"font": {
									"face": "FiraCode Nerd Font"
								} 
							},' 
					Set-Content $file_path $newContent
				}
			}
		} else {
			Shout "WindowsTerminal is not installed. Skipping" -color 'Red'
		}
	}

	function Write-Profile {
		param(
			[PARAMETER(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			[ValidateSet("5", "7")]
			$ps_ver,
			[PARAMETER(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			$oh_theme
		)

		$mydocuments = [environment]::getfolderpath("mydocuments")

		if ($ps_ver -eq '5'){
			$ps_com = 'powershell'
			$profile_dir = Join-Path -ChildPath 'WindowsPowerShell' -Path $mydocuments
			$profile_path = "$profile_dir\Microsoft.PowerShell_profile.ps1"
		} else {
			$ps_com = 'pwsh'
			$profile_dir = Join-Path -ChildPath 'PowerShell' -Path $mydocuments
			$profile_path = "$profile_dir\Profile.ps1"
		}

		if (Test-Path $profile_path) {
			$profile_content = Get-Content -Path $profile_path -Raw
			if ($profile_content -match "oh-my-posh") {
				Write-Host "Profile $profile_path already contains 'oh-my-posh'. No changes made."
				return
			}
		}

		$scriptContent = @"
`$oh_my_theme="$oh_theme"

Import-Module Terminal-Icons
oh-my-posh init $ps_com --config "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\`$oh_my_theme.omp.json" | Invoke-Expression
# Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion for arrow keys
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

Set-PSReadLineOption -PredictionViewStyle ListView
"@

		New-Item -Path "$profile_dir" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
		$scriptContent | Out-File -FilePath "$profile_path" -Append -Force -Encoding utf8
	}

	# =======================  Main Script Body =======================
	cls
	Shout "Script is starting" -color 'Green'

	Shout 'Installing NuGet packageProvider'; Install-PackageProvider -Name NuGet -Confirm:$False -Force | Out-Null
	Shout 'Configuring PSGallery repository'; Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Out-Null
	Shout 'Installing psreadline powershell module'; Install-Module -Name psreadline -Force -ErrorAction SilentlyContinue | Out-Null
	Shout 'Installing Terminal-Icons module'; Install-Module -Name Terminal-Icons -Confirm:$False | Out-Null
	Shout 'Installing oh-my-posh'; Install-oh

	if ($nano) { Shout 'Installing nano for console'; Install-Nano }
	if ($cmd) { Shout 'Installing clink for cmd'; Install-Clink }
	if ($ps7) { Shout 'Installing latest powershell 7'; Install-Pwsh }
	if ($ps_profile) { Shout "Creating profiles for PS5/7"; Write-Profile -ps_ver '7' -oh_theme $oh_theme; Write-Profile -ps_ver '5' -oh_theme $oh_theme }
	if ($terminal) { Shout 'Installing WindowsTerminal'; Install-WindowsTerminal }
	Shout 'Configuring WindowsTerminal'; Configure-WindowsTerminal | out-null
	Shout 'Installing oh-my-posh fonts'; oh-my-posh font install FiraCode | out-null

	Remove-Item "$savePath" -Force -Recurse
	Shout '------------------------------------' -color 'Cyan'
	Shout '   The script is completed! Enjoy!  ' -color 'Blue'
	Shout '------------------------------------' -color 'Cyan'
    pause
    exit
}

############################################################

$response = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet

if ($response) {
    Write-Host "Internet detected. Continue..." -ForegroundColor Green
} else {
    Write-Host "No internet detected! Restart the script when internet will be available" -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Initial settings
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition

$oh_theme = 'night-owl'

$features = @{
	cmd        = [PSCustomObject]@{ status = '++'; description = 'Install Clink for CMD (oh-my-cmd)'; argument = '-cmd' }
	ps7        = [PSCustomObject]@{ status = '++'; description = 'Install the latest powershell 7'; argument = '-ps7' }
	terminal   = [PSCustomObject]@{ status = '++'; description = 'Install WindowsTerminal'; argument = '-terminal' }
	ps_profile = [PSCustomObject]@{ status = '++'; description = 'Create powershell profiles (or do it manually later)'; argument = '-ps_profile' }
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
	$oh_theme = $oh_theme
    $cmd = $features.cmd.status -eq '++'
    $ps7 = $features.ps7.status -eq '++'
    $terminal = $features.terminal.status -eq '++'
    $ps_profile = $features.ps_profile.status -eq '++'
    $nano = $features.nano.status -eq '++'
    Main -oh_theme $oh_theme -cmd:$cmd -ps7:$ps7 -terminal:$terminal -ps_profile:$ps_profile -nano:$nano
}

# Main menu loop
do {
    cls
    Write-Host '------------------------------------------------'
    Write-Host "    Oh-my-posh OneClick installer" -ForegroundColor Yellow
    Write-Host "------------------------------------------------`n`n"
    Write-Host " T or 0 - Set oh_theme (current: " -NoNewline
    Write-Host "$oh_theme" -ForegroundColor Cyan -NoNewline
    Write-Host ")"
    Write-Host "`n"
    $count = 1
    $features.GetEnumerator() | ForEach-Object {
        Write-StatusLine -status $_.Value.status -lineText " $count. $($_.Value.status) $($_.Value.description)"
		$count++
    }
    Write-Host "`n`n--------------------------------------"
    Write-Host " R. Run installation Script" -ForegroundColor Blue
    Write-Host " Q. Do nothing and exit" -ForegroundColor Red
    Write-Host "--------------------------------------`n`n"
    Write-Host ' Notes:'
    Write-Host '  By default, all functions are enabled unless manually disabled.'
    Write-Host "  Choose option with numbers plus enter to disable/enable function `n`n"

    $option = Read-Host " Enter your choice"

    switch ($option) {
        {($_ -eq 'T') -or ($_ -eq 0)} {
			cls
			Write-Host '----'
			Write-Host " Set oh_theme (current: " -NoNewline
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
			
			$columnCount = 3
			$itemsPerColumn = [math]::Ceiling($themes.Count / $columnCount)
			
			for ($row = 0; $row -lt $itemsPerColumn; $row++) {
				$line = ""
				for ($col = 0; $col -lt $columnCount; $col++) {
					$index = $row + $col * $itemsPerColumn
					if ($index -lt $themes.Count) {
						$line += "{0,-4} {1,-30}" -f ($index + 1), $themes[$index]
					}
				}
				Write-Host $line
			}
			
			Write-Host "`n`n------------"
			Write-Host " B. Go back and set theme to $oh_theme"
			Write-Host "------------`n`n"
			
			$choice = Read-Host " Select theme by number"
            
            if ($choice -eq 'B' -or $choice -eq 'b') {
                continue
            }
            
            if ($themes[$choice - 1] -and ($choice -gt 0)) {
                $oh_theme = $themes[$choice - 1]
            } else {
                Write-Host " Invalid selection. Try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        { $_ -in (1..5) } {
            $feature = $features.Keys | Select-Object -Index ($option - 1)
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
            Write-Host " Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
