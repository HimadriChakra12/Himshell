if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}
function Update-PowerShell {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }   
        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell
# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

Update-Profile - Checks for profile updates from a remote repository and updates if necessary.

Update-PowerShell - Checks for the latest PowerShell release and updates if a new version is available.

Edit-Profile - Opens the current user's profile for editing using the configured editor.

touch <file> - Creates a new empty file.

ff <name> - Finds files recursively with the specified name.

Get-PubIP - Retrieves the public IP address of the machine.

winutil - Runs the WinUtil script from Chris Titus Tech.

uptime - Displays the system uptime.

reload - Reloads the current user's PowerShell.

unzip <file> - Extracts a zip file to the current directory.

hb <file> - Uploads the specified file's content to a hastebin-like service and returns the URL.

grep <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.

df - Displays information about volumes.

sed <file> <find> <replace> - Replaces text in a file.

which <name> - Shows the path of the command.

export <name> <value> - Sets an environment variable.

pkill <name> - Kills processes by name.

pgrep <name> - Lists processes by name.

head <path> [n] - Displays the first n lines of a file (default 10).

tail <path> [n] - Displays the last n lines of a file (default 10).

nf <name> - Creates a new file with the specified name.

mkcd <dir> - Creates and changes to a new directory.

docs - Changes the current directory to the user's Documents folder.

dtop - Changes the current directory to the user's Desktop folder.

ep - Opens the profile for editing.

k9 <name> - Kills a process by name.

la - Lists all files in the current directory with detailed formatting.

ll - Lists all files, including hidden, in the current directory with detailed formatting.

gs - Shortcut for 'git status'.

ga - Shortcut for 'git add .'.

gc <message> - Shortcut for 'git commit -m'.

gp - Shortcut for 'git push'.

g - Changes to the GitHub directory.

gcom <message> - Adds all changes and commits with the specified message.

lazyg <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

sysinfo - Displays detailed system information.

flushdns - Clears the DNS cache.

cpy <text> - Copies the specified text to the clipboard.

pst - Retrieves text from the clipboard.

Use 'Show-Help' to display this help message.
"@
}
# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

clear
# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists nano) {'nano'}
          elseif (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR
function Edit-Profile {
    explorer "C:\Users\Himadri\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
}
function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}
# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }
# Open WinUtil
function winutil {
	iwr -useb https://christitus.com/win | iex
}
# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = "& '$args'"
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}
function reload {
    Invoke-Command { & "powershell.exe" } -NoNewScope
}
function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function hb {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    
    $FilePath = $args[0]
    
    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Write-Output $url
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}
function df {
    get-volume
}
function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}
function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}
function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}
function pgrep($name) {
    Get-Process $name
}
function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}
function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}
# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }
# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }
### Quality of Life Aliases
# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }
function dtop { Set-Location -Path $HOME\Desktop }
# Quick Access to Editing the Profile
function ep { vim $PROFILE }
# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }
# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }
# Quick Access to System Information
function sysinfo { Get-ComputerInfo }
# Networking Utilities
function flushdns {
	Clear-DnsClientCache
	Write-Host "DNS has been flushed"
}
# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }
# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock
function su {
    start-process powershell -verb runas   
}
function Spotify-install{
    git clone https://github.com/HimadriChakra12/Spotold.git
    cd Spotold
    Write-Host "Welcome to the Spotify Installer!" -ForegroundColor Cyan
    # Prompt for package manager selection
    Write-Host "Please choose the UI(version) manager:" -ForegroundColor Yellow
    Write-Host "[O] - Old"
    Write-Host "[N] - New"
    Write-Host " "
    $choice = Read-Host Enter the version of your choice:
    Write-Host " "
    switch ($choice) {
        O {
            start-process Install_Old_theme.bat
        }
        N {
            start-process Install_New_theme.bat
        }
        default {
            Write-Host "Invalid choice." -ForegroundColor Red
        }
    }
}
function zf{
    fzf --height 60% --layout reverse --border 
}
function wi ($file){winget install $file}
function ch ($file){choco install $file}
function sc ($file){scoop install $file}
function fast{ fastfetch }
function d{cd d:}
function c{cd c:}
function uwu{ls | fzf --height 60% --layout reverse --border }
function b{cd ..}
function wtf?{
    $path = rg --files --no-filename | fzf --height 60% --layout reverse --border
    $files = Get-ChildItem -Path $path | select-Object FullName | fzf --height 60% --layout reverse --border
    Start-Process $path
    }
function wtd? {
    $directories = Get-ChildItem -Directory -Recurse | Select-Object FullName
    $selectedDirectory = $directories | fzf --height 60% --layout reverse --border --height 60% --layout reverse --border
    explorer $selectedDirectory
    }
function omg {
    set-Location "D:\Games\The shortcuts"
    $path = rg --files --no-filename | fzf --height 60% --layout reverse --border
    Start-Process $path
    }
function posh-kid{
   winget install JanDeDobbeleer.OhMyPosh -s winget
   oh-my-posh font install meslo
   oh-my-posh get shell
   notepad $PROFILE
   oh-my-posh init pwsh | Invoke-Expression
    }
function Bye-posh{
    winget uninstall JanDeDobbeleer.OhMyPosh}
function Track {
    $url1 = "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    Invoke-WebRequest -Uri $url1 -OutFile "D:\Random\Trackers\BasicTracker.txt"
    $url2 = "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt" 
    Invoke-WebRequest -Uri $url2 -OutFile "D:\Random\Trackers\DNSTrackers.txt"
    $url3 = "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt" 
    Invoke-WebRequest -Uri $url3 -OutFile "D:\Random\Trackers\DNSTrackers-best.txt"
    $url4 = "https://cf.trackerslist.com/best.txt" 
    Invoke-WebRequest -Uri $url4 -OutFile "D:\Random\Trackers\CFTrackers-best.txt"
    $url5 = "https://cf.trackerslist.com/all.txt" 
    Invoke-WebRequest -Uri $url5 -OutFile "D:\Random\Trackers\CFTrackers-All.txt"
    $url6 = "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt" 
    Invoke-WebRequest -Uri $url6 -OutFile "D:\Random\Trackers\BasicTracker-best.txt"
    start-process "D:\Random\Trackers\BasicTracker.txt"
    start-process "D:\Random\Trackers\DNSTrackers.txt"
    start-process "D:\Random\Trackers\DNSTrackers-best.txt"
    start-process "D:\Random\Trackers\CFTrackers-best.txt"
    start-process "D:\Random\Trackers\CFTrackers-All.txt"
    start-process "D:\Random\Trackers\BasicTracker-best.txt" }
function rot ($url){
    $Filename = Read-Host "Save the file with the name of"
    Invoke-WebRequest -Uri $url -OutFile "D:\Random\Trackers\$Filename.txt" 
    }
function tf?{
    $selected_item = $(rg --files --no-filename | fzf --height 60% --layout reverse --border)
    if ($selected_item) {
    $selected_item.FullName | Set-Clipboard
    Write-Host "Path copied to clipboard: $($selected_item.FullName)"
    } else {
    Write-Host "No item selected."
    }}
function td? {
    $directories = Get-ChildItem -Directory -Recurse | Select-Object -ExpandProperty FullName | Where-Object { $_.Substring(2) } | Where-Object { Test-Path $_ -PathType Container -ErrorAction Ignore }
    $selectedDirectory = $directories | fzf --height 60% --layout reverse --border
    cd $selectedDirectory 
    }
function Commander {
    $command= Get-Command | fzf --height 60% --layout reverse --border
    if ($command -eq "exit") {break}
    Invoke-Expression $command
    }
function czf{
    $start_directory = Read-Host "Enter the starting directory:"
    $files = Get-ChildItem $start_directory -File
    $selected_file = $files | ConvertTo-Json | fzf | ConvertFrom-Json
    if ($selected_file) {
    $destination = Read-Host "Enter the destination path:"
    Copy-Item $selected_file.FullName $destination
    Write-Host "File copied successfully!"
    }
    else {
    Write-Host "No file selected."
    } 
    }
    function Soundcloud{
        cd "D:\BetterSoundCloud"
        npm start
    }
function ytdlm ($url){
    $Filename = Read-Host "Name of the song"
    D:\Foobar2032\yt-dlp_win\yt-dlp.exe -f bestaudio --extract-audio --audio-format flac --audio-quality 0 -o "D:\Musics\$Filename.flac" $url 
    D:\Foobar2032\yt-dlp_win\yt-dlp.exe -f bestaudio --extract-audio --audio-format opus --audio-quality 0 -o "D:\Musics\$Filename.opus" $url
    explorer "D:\Musics"
    }
function ytdlno{
    $Filename = Read-Host "Name of the song"
    D:\Foobar2032\yt-dlp_win\yt-dlp.exe -f bestaudio --extract-audio --audio-quality 0 -o "D:\Musics\$Filename.mp3" $url 
}
function ytdlp ($url){
    $Filename = Read-Host "Name of the Playlist"
    D:\Foobar2032\yt-dlp_win\yt-dlp.exe -f bestaudio --extract-audio --audio-format opus --audio-quality 0 -o "D:\Musics\" $url 
    }
function spf-install{
    powershell -ExecutionPolicy Bypass -Command "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://superfile.netlify.app/install.ps1'))" 
    }
function real-stuffs{
    winget install aria2 fzf nvim
    }

function crack-office{
    Write-Host "Check both folder Please choose a package manager:" -ForegroundColor Yellow
    explorer "C:\Program Files"
    explorer "C:\Program Files(x86)"
    Write-Host "[PF] - Program Files"
    Write-Host "[PF86] - Program Files(x86)"
    Write-Host " "
    $choice = Read-Host Enter the your choice:
    Write-Host " "
    switch ($choice) {
    PF {
        cd /d %ProgramFiles%\Microsoft Office\Office16
        invoke-Expression "for /f %x in ('dir /b ..\root\Licenses16\proplusvl_kms*.xrm-ms') do cscript ospp.vbs /inslic:"..\root\Licenses16\%x""
        cscript ospp.vbs /inpkey:XQNVK-8JYDB-WJ9W3-YJ8YR-WFG99
        cscript ospp.vbs /unpkey:BTDRB >nul
        cscript ospp.vbs /unpkey:KHGM9 >nul
        cscript ospp.vbs /unpkey:CPQVG >nul
        cscript ospp.vbs /sethst:107.175.77.7
        cscript ospp.vbs /setprt:1688
        cscript ospp.vbs /act
        }
    PF86 {
        cd /d %ProgramFiles(x86)%\Microsoft Office\Office16
        invoke-Expression "for /f %x in ('dir /b ..\root\Licenses16\proplusvl_kms*.xrm-ms') do cscript ospp.vbs /inslic:"..\root\Licenses16\%x""
        cscript ospp.vbs /inpkey:XQNVK-8JYDB-WJ9W3-YJ8YR-WFG99
        cscript ospp.vbs /unpkey:BTDRB >nul
        cscript ospp.vbs /unpkey:KHGM9 >nul
        cscript ospp.vbs /unpkey:CPQVG >nul
        cscript ospp.vbs /sethst:107.175.77.7
        cscript ospp.vbs /setprt:1688
        cscript ospp.vbs /act
        }
    default {
        Write-Host "Failed to crack" -ForegroundColor Red
        }
    }
}
function spot ($url){
    cd D:\Musics
    $env:SPOTIPY_CLIENT_ID='e5e6bc45381e4bcd9640974043fab7a5'
    $env:SPOTIPY_CLIENT_SECRET='cae56005226d4c948600f9f4c2e38206'
     spotify_dl -l $url
}
function searchapp ($appname) {
    winget search --query $appname
    choco search --query $appname
    }
# Choco
    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
    }
function wlan{
    netsh wlan show profiles
    $choice = Read-Host "Enter your choice"
    netsh wlan show profiles $choice key=clear
}
function office-setup{
    aria2c 'https://go.microsoft.com/fwlink/?linkid=2264705&clcid=0x409&culture=en-us&country=us'
    start-process OfficeSetup.exe
}
function pkg ($SoftwareName) {
    Write-Host "Welcome to the Software Installer!" -ForegroundColor Cyan
    # Prompt for package manager selection
    Write-Host "Please choose a package manager:" -ForegroundColor Yellow
    Write-Host "[wi] - winget"
    Write-Host "[ch] - choco"
    Write-Host "[sc] - scoop"
    Write-Host " "
    $choice = Read-Host Enter your choice:
    switch ($choice) {
        wi {
            Write-Host "Installing $SoftwareName using winget..." -ForegroundColor Green
            winget install "$SoftwareName"
        }
        ch {
            Write-Host "Installing $SoftwareName using choco..." -ForegroundColor Green
            choco install "$SoftwareName"
        }
        sc {
            Write-Host "Installing $SoftwareName using choco..." -ForegroundColor Green
            scoop install "$SoftwareName"
        }
        default {
            Write-Host "Invalid choice." -ForegroundColor Red
        }
}
}
function cl ($url){
    cd D:
    git clone $url
}
function explore{
    $location= Get-location
    explorer $location
}
function Hash{
    explorer "D:\HashTWM\hashtwm.exe"
}
Function Komorebi-start{
    komorebic start --whkd --bar
}
Function Musics{
    cd "D:\musics"
}
Function Search ($SearchFor){
$Query = "http://www.bing.com/search?q=$SearchFor"
Start $Query
}
function previewer{
    fzf --preview 'C:\Users\Himadri\Downloads\ABDM\bat-v0.24.0-x86_64-pc-windows-msvc\bat.exe {}' --height 60% --layout reverse --border 
}
function ex ($dir){
    explorer $dir
}
function redit{
    # Get all registry keys under HKLM and HKCU
$registryKeys = Get-ChildItem -Path HKLM:\, HKCU:\ -Recurse | Select-Object -ExpandProperty PSPath

# Filter registry keys using fzf
$selectedKey = $registryKeys | Invoke-Fzf

# Open the selected key in RegEdit
if ($selectedKey) {
    Start-Process regedit.exe -ArgumentList $selectedKey
}
}
