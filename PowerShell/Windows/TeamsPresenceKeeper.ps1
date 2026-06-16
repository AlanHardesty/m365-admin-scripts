# TeamsPresenceKeeper.ps1
# Keeps Teams status as Available during defined working hours by sending a
# harmless keypress every 4 minutes. Outside working hours, only the display/
# sleep prevention stays active — Teams is allowed to go Away naturally.
#
# Uses Windows SetThreadExecutionState API to prevent the display from sleeping
# for the duration of the script (screen stays on while script is running).
# Normal sleep behavior is restored automatically when the script exits.
#
# No admin rights required. Press Ctrl+C to stop.

# ---- CONFIGURATION ----
$MorningStart = "08:00"   # Start of working hours
$LunchStart   = "12:00"   # Lunch break start (Teams goes Away)
$LunchEnd     = "13:00"   # Lunch break end
$AfternoonEnd = "17:00"   # End of working hours (Teams goes Away after this)
$Timezone     = "Central Standard Time"   # TimeZoneInfo ID — see [System.TimeZoneInfo]::GetSystemTimeZones()
# -----------------------

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Sleep {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);

    public const uint ES_CONTINUOUS       = 0x80000000;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
    public const uint ES_SYSTEM_REQUIRED  = 0x00000001;
}
"@

[Sleep]::SetThreadExecutionState([Sleep]::ES_CONTINUOUS -bor [Sleep]::ES_DISPLAY_REQUIRED -bor [Sleep]::ES_SYSTEM_REQUIRED)

$wsh = New-Object -ComObject WScript.Shell
$tz  = [System.TimeZoneInfo]::FindSystemTimeZoneById($Timezone)

function Test-ActiveTime {
    $local = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
    $tod   = $local.TimeOfDay
    $s1    = [TimeSpan]::Parse($MorningStart)
    $e1    = [TimeSpan]::Parse($LunchStart)
    $s2    = [TimeSpan]::Parse($LunchEnd)
    $e2    = [TimeSpan]::Parse($AfternoonEnd)
    return ($tod -ge $s1 -and $tod -lt $e1) -or ($tod -ge $s2 -and $tod -lt $e2)
}

$local = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
Write-Host "Current time ($Timezone): $($local.ToString('dddd HH:mm'))" -ForegroundColor Magenta
Write-Host "Working hours: $MorningStart-$LunchStart, $LunchEnd-$AfternoonEnd"
Write-Host "Press Ctrl+C to stop."

try {
    $lastState = ""
    while ($true) {
        if (Test-ActiveTime) {
            if ($lastState -ne "active") {
                Write-Host "`n[WORKING] Keeping Teams active" -ForegroundColor Green
                $lastState = "active"
            }
            $wsh.SendKeys('+{F15}')
            Write-Host "   [$(Get-Date -Format 'HH:mm:ss')] Activity ping" -ForegroundColor Gray
            Start-Sleep -Seconds 240
        }
        else {
            if ($lastState -ne "inactive") {
                Write-Host "`n[AWAY] Outside working hours — Teams allowed to go Away" -ForegroundColor Yellow
                $lastState = "inactive"
            }
            [Sleep]::SetThreadExecutionState([Sleep]::ES_CONTINUOUS -bor [Sleep]::ES_DISPLAY_REQUIRED -bor [Sleep]::ES_SYSTEM_REQUIRED)
            Start-Sleep -Seconds 60
        }
    }
}
finally {
    [Sleep]::SetThreadExecutionState([Sleep]::ES_CONTINUOUS)
    Write-Host "`nScript stopped. Normal sleep behavior restored." -ForegroundColor White
}
