#Requires -RunAsAdministrator

<#
.SYNOPSIS
Installs a Windows logon heartbeat task for the Home Assistant screen light.

.DESCRIPTION
The task starts in the interactive user's session at logon and sends an "on"
heartbeat every 30 seconds. Home Assistant must treat each heartbeat as a
90-second lease: restart the lease when another heartbeat arrives, and turn the
light off when it expires. This also handles sleep, shutdown, crashes, and power
loss, where Windows cannot reliably send a final "off" request.

The Home Assistant webhook ID is kept in an ACL-restricted ProgramData directory.
#>

[CmdletBinding()]
param(
    [string] $InteractiveUser,

    [switch] $ReplaceWebhookId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InteractiveUser)) {
    $InteractiveUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
}

if ([string]::IsNullOrWhiteSpace($InteractiveUser)) {
    throw 'No interactive Windows user was detected. Re-run with -InteractiveUser ''DOMAIN\User''.'
}

$InteractiveUserAccount = [System.Security.Principal.NTAccount]::new($InteractiveUser)
$InteractiveUserSid = $InteractiveUserAccount.Translate(
    [System.Security.Principal.SecurityIdentifier]
).Value

$InstallDirectory = Join-Path $env:ProgramData 'HomeAssistantScreenLight'
$ControlScriptPath = Join-Path $InstallDirectory 'Set-ScreenLight.ps1'
$WebhookIdPath = Join-Path $InstallDirectory 'webhook-id.txt'
$PowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$IcaclsPath = Join-Path $env:SystemRoot 'System32\icacls.exe'

$SessionTaskName = 'Home Assistant - Screen Light On'
$LegacyShutdownTaskName = 'Home Assistant - Screen Light Off'

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null

# Recover files created by an earlier installer version that could have had
# inheritance removed without receiving explicit file permissions. Missing
# files are expected during the first installation, so ignore those failures.
foreach ($ExistingPath in @($ControlScriptPath, $WebhookIdPath)) {
    & $IcaclsPath $ExistingPath `
        '/grant:r' `
        '*S-1-5-18:F' `
        '*S-1-5-32-544:F' `
        '/C' 2>$null | Out-Null
}

$WebhookId = $null
if (-not $ReplaceWebhookId -and (Test-Path -LiteralPath $WebhookIdPath)) {
    $StoredWebhookId = (Get-Content -LiteralPath $WebhookIdPath -Raw).Trim()

    if ($StoredWebhookId -match '^[0-9a-fA-F]{32}$') {
        $WebhookId = $StoredWebhookId
        Write-Host 'Reusing the existing secured Home Assistant webhook ID.'
    }
}

if ([string]::IsNullOrWhiteSpace($WebhookId)) {
    $SecureWebhookId = Read-Host 'Paste the private 32-character Home Assistant webhook ID' -AsSecureString
    $WebhookId = [System.Net.NetworkCredential]::new('', $SecureWebhookId).Password.Trim()
}

if ($WebhookId -notmatch '^[0-9a-fA-F]{32}$') {
    throw 'The webhook ID must be the 32-character value generated with [guid]::NewGuid().ToString("N").'
}

Set-Content -LiteralPath $WebhookIdPath -Value $WebhookId -Encoding Ascii -NoNewline

$ControlScript = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('watch', 'on', 'off')]
    [string] $State
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WebhookIdPath = Join-Path $PSScriptRoot 'webhook-id.txt'
$WebhookId = (Get-Content -LiteralPath $WebhookIdPath -Raw).Trim()

if ($WebhookId -notmatch '^[0-9a-fA-F]{32}$') {
    throw 'The stored Home Assistant webhook ID is invalid.'
}

$Uri = "http://homeassistant.local:8123/api/webhook/$WebhookId"

function Send-LightState {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('on', 'off')]
        [string] $RequestedState,

        [Parameter(Mandatory = $true)]
        [int] $AttemptLimit,

        [Parameter(Mandatory = $true)]
        [int] $TimeoutSeconds
    )

    $Body = @{ state = $RequestedState } | ConvertTo-Json -Compress

    for ($Attempt = 1; $Attempt -le $AttemptLimit; $Attempt++) {
        try {
            Invoke-WebRequest `
                -Method Post `
                -Uri $Uri `
                -ContentType 'application/json' `
                -Body $Body `
                -TimeoutSec $TimeoutSeconds `
                -UseBasicParsing | Out-Null
            return
        }
        catch {
            if ($Attempt -eq $AttemptLimit) {
                throw "Home Assistant screen light request failed after $Attempt attempt(s): $($_.Exception.Message)"
            }

            Start-Sleep -Seconds 3
        }
    }
}

if ($State -eq 'watch') {
    while ($true) {
        try {
            Send-LightState -RequestedState 'on' -AttemptLimit 1 -TimeoutSeconds 3
        }
        catch {
            # A temporary DNS, DHCP, Wi-Fi, or Home Assistant outage must not
            # terminate the session watcher. The next heartbeat retries it.
            Write-Warning $_.Exception.Message
        }

        Start-Sleep -Seconds 30
    }
}

$AttemptLimit = if ($State -eq 'on') { 20 } else { 2 }
$TimeoutSeconds = if ($State -eq 'on') { 3 } else { 2 }
Send-LightState `
    -RequestedState $State `
    -AttemptLimit $AttemptLimit `
    -TimeoutSeconds $TimeoutSeconds
'@

Set-Content -LiteralPath $ControlScriptPath -Value $ControlScript -Encoding UTF8

# The webhook is a credential. Grant the directory inheritable permissions, then
# protect each existing file with explicit file permissions. Directory-only
# inheritance flags must not be applied recursively to files.
& $IcaclsPath $InstallDirectory `
    '/inheritance:r' `
    '/grant:r' `
    '*S-1-5-18:(OI)(CI)F' `
    '*S-1-5-32-544:(OI)(CI)F' `
    "*${InteractiveUserSid}:(OI)(CI)RX" `
    '/C' | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to secure $InstallDirectory with icacls.exe."
}

& $IcaclsPath $ControlScriptPath `
    '/inheritance:r' `
    '/grant:r' `
    '*S-1-5-18:F' `
    '*S-1-5-32-544:F' `
    "*${InteractiveUserSid}:RX" `
    '/C' | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to secure $ControlScriptPath with icacls.exe."
}

& $IcaclsPath $WebhookIdPath `
    '/inheritance:r' `
    '/grant:r' `
    '*S-1-5-18:F' `
    '*S-1-5-32-544:F' `
    "*${InteractiveUserSid}:R" `
    '/C' | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to secure $WebhookIdPath with icacls.exe."
}

# Stop and remove both tasks from previous installer versions. A running
# startup task normally has already exited, but stopping it makes upgrades safe.
foreach ($ExistingTaskName in @($SessionTaskName, $LegacyShutdownTaskName)) {
    $ExistingTask = Get-ScheduledTask `
        -TaskName $ExistingTaskName `
        -ErrorAction SilentlyContinue

    if ($null -ne $ExistingTask) {
        Stop-ScheduledTask -TaskName $ExistingTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $ExistingTaskName -Confirm:$false
    }
}

$ActionArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ' +
    "-File `"$ControlScriptPath`" -State watch"
$TaskAction = New-ScheduledTaskAction `
    -Execute $PowerShellPath `
    -Argument $ActionArguments
$TaskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $InteractiveUser
$TaskPrincipal = New-ScheduledTaskPrincipal `
    -UserId $InteractiveUser `
    -LogonType Interactive `
    -RunLevel Limited
$TaskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $SessionTaskName `
    -Description 'Keeps the Home Assistant screen-light lease alive while this user session exists.' `
    -Action $TaskAction `
    -Trigger $TaskTrigger `
    -Principal $TaskPrincipal `
    -Settings $TaskSettings `
    -Force | Out-Null

Write-Host ''
Write-Host 'Installed the Home Assistant screen-light session task.' -ForegroundColor Green
Write-Host "Interactive user: $InteractiveUser"
Write-Host "Runtime script: $ControlScriptPath"
Write-Host ''
Write-Host 'Start it now (future logons start it automatically):'
Write-Host "  Start-ScheduledTask -TaskName '$SessionTaskName'"
Write-Host ''
Write-Host 'A successful session watcher reports State Running:'
Write-Host "  Get-ScheduledTask -TaskName '$SessionTaskName' | Select-Object TaskName, State"
Write-Host ''
Write-Warning 'Before starting the task, update the Home Assistant webhook automation to use a 90-second restartable lease.'
