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
	$latestRelease = Invoke-WebRequest -Uri $latestReleaseUrl | ConvertFrom-Json

	$link = $latestRelease.assets.browser_download_url | Select-String -Pattern "$zip_name" | select-object -First 1
	$link = $link.ToString().Trim()
	return $link
}

function Install-oh {
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
		Shout 'Nano already installed. Skipping...'
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
		Shout "WindowsTerminal not installed. Skipping..." -color 'Red'
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
		Shout "WindowsTerminal not installed. Skiping" -color 'Red'
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
Shout "Script starting" -color 'Green'

Shout 'Installing NuGet packageProvider'; Install-PackageProvider -Name NuGet -Confirm:$False -Force | Out-Null
Shout 'Configuring PSGallery repository'; Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Out-Null
Shout 'Installing psreadline powershell module'; Install-Module -Name psreadline -Force -ErrorAction SilentlyContinue | Out-Null
Shout 'Installing Terminal-Icons module'; Install-Module -Name Terminal-Icons -Confirm:$False | Out-Null
Shout 'Installing oh-my-posh'; Install-oh

if ($nano) { Shout 'Installing nano for console'; Install-Nano }
if ($cmd) { Shout 'Installing clink for cmd'; Install-Clink }
if ($ps7) { Shout 'Installing latest powershell 7'; Install-Pwsh }
if ($ps_profile) { Shout "Creating profiles for PS5/7"; Write-Profile -ps_ver '7' -oh_theme $oh_theme; Write-Profile -ps_ver '5' -oh_theme $oh_theme }
if ($terminal) { Shout 'Installing WindowsTerminal'; Install-WindowsTerminal; Configure-WindowsTerminal }

Shout 'Installing oh-my-posh fonts'; oh-my-posh font install FiraCode | out-null

Remove-Item "$savePath" -Force -Recurse
Shout '------------------------------------' -color 'Cyan'
Shout '   The script is completed! Enjoy!  ' -color 'Blue'
Shout '------------------------------------' -color 'Cyan'
