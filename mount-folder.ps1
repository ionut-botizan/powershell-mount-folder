Param(
	[switch] $A = $False,
	[switch] $D = $False,
	[switch] $H = $False,
	[switch] $help = $False
)

function Show-The-Help
{
	Write-Host ""
	Write-Host " Available options:"
	Write-Host " =================="
	Write-Host -NoNewLine " <No-Flags>                        "
	Write-Host -ForegroundColor DarkGray "List mounted folders"
	Write-Host -NoNewLine " -A <Drive-Letter> <Folder-Path>   "
	Write-Host -ForegroundColor DarkGray "Mount a new folder to a drive letter"
	Write-Host -NoNewLine " -D <Drive-Letter>                 "
	Write-Host -ForegroundColor DarkGray "Remove a mounted folder"
	Write-Host -NoNewLine " /?, /h, -h, -help, --help         "
	Write-Host -ForegroundColor DarkGray "Show this help message"
	Write-Host ""
	Write-Host " Examples:"
	Write-Host " =================="
	Write-Host -NoNewLine " Mounting:      "
	Write-Host -ForegroundColor DarkGray " mount-folder -A B: C:\Users\jack.sparrow\Desktop"
	Write-Host -NoNewLine " Un-mounting:   "
	Write-Host -ForegroundColor DarkGray " mount-folder -D B:"
}

function Normalize-Drive-Letter($drive)
{
	$drive = $drive.ToUpper() -replace ':', ''
	return "${drive}:"
}

function List-Mounted-Folders
{
	$root = Get-Item -Path $HKLM
	$keys = @()

	$root.GetValueNames() | ForEach-Object {
		if ($_ -match "^[a-zA-Z]:$") {
			$path = $root.GetValue($_) -replace '^\\(\?\?|DosDevices)\\([a-zA-Z]:)', '$2'
			$keys += [PSCustomObject] @{
				Drive = $_;
				Path = $path
			}
		}
	}

	$columns = @{Expression = {" {0}" -f $_.Drive}; Width = 10},@{Expression = {$_.Path}}
	$headers = @(
		[PSCustomObject] @{Drive = "Drive"; Path = "Path"},
		[PSCustomObject] @{Drive = "-----"; Path = "----"}
	)

	$headers + ($keys | Sort-Object Drive) | Format-Table -HideTableHeaders -Wrap $columns
}

function Run-Elevated($command)
{
	Start-Process -FilePath powershell.exe -Verb runas -Wait -WindowStyle Hidden -ArgumentList "-noprofile -command $Command"
}

$HKLM = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices"

if ($H -or $help -or ($args[0] -eq "--help") -or ($args[0] -eq "/h") -or ($args[0] -eq "/?")) {
	Show-The-Help
	exit
}

if ($D) {
	$drive = Normalize-Drive-Letter $args[0]

	if (-not($drive -match "^[a-zA-Z]:$")) {
		Show-The-Help
		exit
	}

	# unmount for current session
	Invoke-Expression "subst $drive /D" | Out-Null

	# unmount for future sessions
	$command = "Remove-ItemProperty -Path '$HKLM' -Name '$drive'"
	Run-Elevated $command
}

if (-not($D) -and $A) {
	$drive = Normalize-Drive-Letter $args[0]
	$path  = $args[1].Trim('\')

	if (-not($drive -match "^[a-zA-Z]:$")) {
		Show-The-Help
		exit
	}
	
	if (-not($path) -or -not((Get-Item $path) -is [System.IO.DirectoryInfo])) {
		Show-The-Help
		exit
	}

	# mount for current session
	Invoke-Expression "subst $drive '${path}'" | Out-Null

	# mount for future sessions
	$command = "New-ItemProperty -Path '$HKLM' -Name '$drive' -PropertyType String -Value '\??\$path'"
	Run-Elevated $command
}

List-Mounted-Folders