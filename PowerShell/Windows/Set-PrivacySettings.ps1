# Set-PrivacySettings.ps1
# Applies privacy-focused registry settings on Windows 10/11:
#   - Disables advertising ID and tailored experiences
#   - Disables activity history and cloud sync (Timeline)
#   - Disables Start menu suggestions and lock screen spotlight
#   - Disables Windows Copilot and Recall (24H2+)
#   - Disables Bing web search integration in Start
#
# Run as Administrator.

# Disable advertising ID and tailored experiences
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"  -Name "Enabled"                                     -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"           -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force

# Disable activity history and cloud sync
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed"   -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force

# Disable suggestions, tips, and lock screen spotlight
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled"          -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled"       -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled"       -Value 0 -Type DWord -Force

# Disable Copilot and Recall (Windows 11 24H2+)
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"      -Name "DisableWindowsRecall"  -Value 1 -Type DWord -Force

# Disable Bing web search in Start
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force

Write-Host "Privacy settings applied. Some changes require a reboot." -ForegroundColor Green
