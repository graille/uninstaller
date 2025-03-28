# Description: Cleans all traces of Autodesk software (AutoCAD, Revit, 3ds Max, Fusion 360) on Windows 11.
# Note: Run as administrator. This script is interactive and will ask for confirmation at each step.
# Version: 1.0
# Language: English

Write-Host "=== Complete Autodesk Cleanup: AutoCAD, Revit, 3ds Max, Fusion 360 ===`n" -ForegroundColor Cyan

# 1. Check for administrator privileges
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
} catch {
    $isAdmin = $false
}
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as an administrator." -ForegroundColor Red
    Write-Host "Please restart PowerShell in Administrator mode and try again." -ForegroundColor Yellow
    return 1  # exit with error code
}

# Initialize lists for the final report
$DeletedItems   = @{}
$FailedItems    = @{}
$SkippedSections = @()

# Helper functions to add items to the deleted/failed lists
function Add-DeletedItem($category, $item) {
    if (-not $DeletedItems.ContainsKey($category)) {
        $DeletedItems[$category] = New-Object System.Collections.Generic.List[string]
    }
    $DeletedItems[$category].Add($item)
}
function Add-FailedItem($category, $item) {
    if (-not $FailedItems.ContainsKey($category)) {
        $FailedItems[$category] = New-Object System.Collections.Generic.List[string]
    }
    $FailedItems[$category].Add($item)
}

# 2. Delete Residual Autodesk Folders and Files
Write-Host "Searching for residual Autodesk folders..." -ForegroundColor White
# Define target paths
$pathsToRemove = @(
    "$Env:ProgramFiles\Autodesk",
    "$Env:ProgramFiles\Common Files\Autodesk Shared",
    "$Env:ProgramFiles(x86)\Autodesk",
    "$Env:ProgramFiles(x86)\Common Files\Autodesk Shared",
    "$Env:ProgramData\Autodesk",
    "$Env:ProgramData\FLEXnet",              # Contains license files (adsk*.data)
    "$Env:PUBLIC\Documents\Autodesk",       # Autodesk Public Documents folder (if present)
    "$Env:APPDATA\Autodesk",                # AppData Roaming
    "$Env:LOCALAPPDATA\Autodesk",           # AppData Local (includes Web Services/LoginState.xml, Fusion webdeploy, etc.)
    "C:\Autodesk"                           # Autodesk root installation folder (installation cache)
)
# Filter only existing paths
$existingPaths = $pathsToRemove | Where-Object { Test-Path $_ }
if ($existingPaths.Count -eq 0) {
    Write-Host "No residual Autodesk folder was found." -ForegroundColor Green
} else {
    Write-Host "Found folders:" -ForegroundColor Yellow
    $existingPaths | ForEach-Object { Write-Host "  - $_" }
    # User confirmation
    $confirm = Read-Host "Delete these folders and their contents? (Y/N)"
    if ($confirm -match '^(?:Y|y)$') {
        foreach ($path in $existingPaths) {
            Write-Host "Deleting folder $path ..." -ForegroundColor White
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Add-DeletedItem "Folders" $path
                Write-Host "  -> Deleted" -ForegroundColor Green
            }
            catch {
                Add-FailedItem "Folders" $path
                Write-Host "  -> Failed to delete: $path" -ForegroundColor Red
            }
        }
    } else {
        Write-Host ">> Step 'Folders' skipped by the user." -ForegroundColor Yellow
        $SkippedSections += "Folders"
    }
}
Write-Host ""  # empty line

# 3. Clean Up Autodesk Registry Keys
Write-Host "Searching for Autodesk registry keys..." -ForegroundColor White
$regPathsToSearch = @(
    "HKLM:\Software",
    "HKLM:\Software\Wow6432Node",
    "HKCU:\Software"
)
# Store found keys in a list
$regKeysFound = New-Object System.Collections.Generic.List[string]
# Terms to search in key names (Autodesk, AutoCAD, Revit, 3ds Max, Fusion 360, FlexNet)
$terms = @("Autodesk", "AutoCAD", "Revit", "3ds Max", "Fusion 360", "Fusion360", "FlexNet")
foreach ($regBase in $regPathsToSearch) {
    try {
        # Recursive search of subkeys (limited depth for performance)
        Get-ChildItem -Path $regBase -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object {
                $keyPath = $_.Name  # Full key path
                foreach ($term in $terms) {
                    if ($keyPath -match $term) {
                        $regKeysFound.Add($keyPath) | Out-Null
                        break  # Exit inner loop as soon as a term matches
                    }
                }
            }
    } catch {
        # Ignore access errors for protected system keys
    }
}
# Remove redundant keys (skip subkeys if parent is already listed)
$regKeysList = $regKeysFound.ToArray() | Sort-Object -Unique
$regKeysToRemove = New-Object System.Collections.Generic.List[string]
foreach ($key in $regKeysList) {
    if ($regKeysToRemove -notmatch [regex]::Escape($key + "\")) {
        $regKeysToRemove.Add($key) | Out-Null
    }
}
if ($regKeysToRemove.Count -eq 0) {
    Write-Host "No Autodesk registry key found to clean." -ForegroundColor Green
} else {
    Write-Host "Found registry keys:" -ForegroundColor Yellow
    $regKeysToRemove | ForEach-Object { Write-Host "  - $_" }
    $confirm = Read-Host "Delete these registry keys? (Y/N)"
    if ($confirm -match '^(?:Y|y)$') {
        foreach ($regKey in $regKeysToRemove) {
            Write-Host "Deleting registry key $regKey ..." -ForegroundColor White
            try {
                Remove-Item -Path $regKey -Recurse -Force -ErrorAction Stop
                Add-DeletedItem "Registry" $regKey
                Write-Host "  -> Deleted" -ForegroundColor Green
            }
            catch {
                Add-FailedItem "Registry" $regKey
                Write-Host "  -> Failed to delete: $regKey" -ForegroundColor Red
            }
        }
    } else {
        Write-Host ">> Step 'Registry' skipped by the user." -ForegroundColor Yellow
        $SkippedSections += "Registry"
    }
}
Write-Host ""

# 4. Delete Autodesk Temporary Files and Caches
Write-Host "Searching for Autodesk temporary files..." -ForegroundColor White
$tempDir = [System.IO.Path]::GetTempPath()  # Path to %TEMP%
# Look for any file/folder in the temp directory whose name contains Autodesk terms
$tempPattern = @("Autodesk", "ADSK", "AutoCAD", "Revit", "3dsMax", "Fusion", "FlexNet")
$tempItems = Get-ChildItem -Path $tempDir -Force -ErrorAction SilentlyContinue | Where-Object {
    $name = $_.Name
    foreach ($term in $tempPattern) {
        if ($name -match $term) { return $true }
    }
    return $false
}
if ($tempItems.Count -eq 0) {
    Write-Host "No Autodesk temporary file/folder found in $tempDir." -ForegroundColor Green
} else {
    Write-Host "Temporary items found in $tempDir:" -ForegroundColor Yellow
    $tempItems | ForEach-Object { Write-Host "  - $($_.FullName)" }
    $confirm = Read-Host "Delete these temporary files/folders? (Y/N)"
    if ($confirm -match '^(?:Y|y)$') {
        foreach ($item in $tempItems) {
            Write-Host "Deleting $($item.FullName) ..." -ForegroundColor White
            try {
                if ($item.PSIsContainer) {
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                } else {
                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                }
                Add-DeletedItem "Temp" $item.FullName
                Write-Host "  -> Deleted" -ForegroundColor Green
            }
            catch {
                Add-FailedItem "Temp" $item.FullName
                Write-Host "  -> Failed to delete: $($item.FullName)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host ">> Step 'Temporary Files' skipped by the user." -ForegroundColor Yellow
        $SkippedSections += "TempFiles"
    }
}
Write-Host ""

# 5. Delete Autodesk Services, Scheduled Tasks, and Automatic Startup Entries
Write-Host "Searching for Autodesk Windows services..." -ForegroundColor White
# Find services whose name or display name contains Autodesk or FlexNet
$servicesToRemove = Get-Service | Where-Object { $_.DisplayName -match "Autodesk|FlexNet" -or $_.Name -match "Autodesk|FlexNet" }
if ($servicesToRemove.Count -eq 0) {
    Write-Host "No Autodesk/FlexNet service is running." -ForegroundColor Green
} else {
    Write-Host "Detected services:" -ForegroundColor Yellow
    $servicesToRemove | ForEach-Object { Write-Host ("  - {0} (ServiceName: {1})" -f $_.DisplayName, $_.Name) }
}
Write-Host "`nSearching for Autodesk scheduled tasks..." -ForegroundColor White
$tasksToRemove = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.TaskName -match "Autodesk|FlexNet|AutoCAD|Revit|3ds|Fusion" -or $_.TaskPath -match "Autodesk"
}
if ($tasksToRemove.Count -eq 0) {
    Write-Host "No Autodesk scheduled task detected." -ForegroundColor Green
} else {
    Write-Host "Detected scheduled tasks:" -ForegroundColor Yellow
    $tasksToRemove | ForEach-Object {
        $fullTaskPath = ($_.TaskPath -ne "\") ? ($_.TaskPath.TrimEnd("\") + "\" + $_.TaskName) : $_.TaskName
        Write-Host "  - $fullTaskPath"
    }
}
Write-Host "`nSearching for Autodesk automatic startup entries..." -ForegroundColor White
$runLocations = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
)
$startupRegItems = New-Object System.Collections.Generic.List[string]
foreach ($loc in $runLocations) {
    try {
        $regKey = $null
        if ($loc -like "HKLM*") {
            $regKey = [Microsoft.Win32.Registry]::LocalMachine
        } elseif ($loc -like "HKCU*") {
            $regKey = [Microsoft.Win32.Registry]::CurrentUser
        }
        $subPath = ($loc -split "HKLM:|HKCU:")[1].TrimStart("\")
        $key = $regKey.OpenSubKey($subPath)
        if ($key) {
            foreach ($valName in $key.GetValueNames()) {
                $valData = $key.GetValue($valName) 
                foreach ($term in $terms) {
                    if ($valName -match $term -or ($valData -and $valData.ToString() -match $term)) {
                        $startupRegItems.Add("$loc -> Value '$valName'") | Out-Null
                        break
                    }
                }
            }
        }
    } catch { }
}
# Get Startup folder (for current user and common)
$startupFolders = @(
    [Environment]::GetFolderPath("Startup"),
    [Environment]::GetFolderPath("CommonStartup")
)
$startupFiles = New-Object System.Collections.Generic.List[string]
foreach ($folder in $startupFolders) {
    if ($folder -and (Test-Path $folder)) {
        Get-ChildItem -Path $folder -File -Force -ErrorAction SilentlyContinue | Where-Object {
            foreach ($term in $terms) {
                if ($_.Name -match $term) { return $true }
            }
            return $false
        } | ForEach-Object {
            $startupFiles.Add("$folder\$($_.Name)") | Out-Null
        }
    }
}
if ($startupRegItems.Count -eq 0 -and $startupFiles.Count -eq 0) {
    Write-Host "No Autodesk startup entry detected." -ForegroundColor Green
} else {
    Write-Host "Detected startup items:" -ForegroundColor Yellow
    $startupRegItems + $startupFiles | ForEach-Object { Write-Host "  - $_" }
}

if ($servicesToRemove.Count -eq 0 -and $tasksToRemove.Count -eq 0 -and $startupRegItems.Count -eq 0 -and $startupFiles.Count -eq 0) {
    Write-Host "`nNo Autodesk service, scheduled task or automatic startup entry to delete." -ForegroundColor Green
} else {
    $confirm = Read-Host "`nDelete the services, tasks and startup items listed above? (Y/N)"
    if ($confirm -match '^(?:Y|y)$') {
        # Stop and delete services
        foreach ($svc in $servicesToRemove) {
            Write-Host "Stopping service $($svc.Name) ..." -ForegroundColor White
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            } catch { }
            Write-Host "Deleting service $($svc.Name) ..." -ForegroundColor White
            try {
                & sc.exe delete $svc.Name | Out-Null   # Use sc.exe to delete the service
                Add-DeletedItem "Services" "$($svc.Name) ($($svc.DisplayName))"
                Write-Host "  -> Service deleted: $($svc.DisplayName)" -ForegroundColor Green
            }
            catch {
                Add-FailedItem "Services" "$($svc.Name) ($($svc.DisplayName))"
                Write-Host "  -> Failed to delete service: $($svc.DisplayName)" -ForegroundColor Red
            }
        }
        # Delete scheduled tasks
        foreach ($task in $tasksToRemove) {
            $fullTaskName = ($task.TaskPath -ne "\") ? ($task.TaskPath.TrimEnd("\") + "\" + $task.TaskName) : $task.TaskName
            Write-Host "Deleting scheduled task '$fullTaskName' ..." -ForegroundColor White
            try {
                Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                Add-DeletedItem "Tasks" $fullTaskName
                Write-Host "  -> Task deleted: $fullTaskName" -ForegroundColor Green
            }
            catch {
                Add-FailedItem "Tasks" $fullTaskName
                Write-Host "  -> Failed to delete task: $fullTaskName" -ForegroundColor Red
            }
        }
        # Delete startup entries (registry)
        foreach ($loc in $runLocations) {
            try {
                $regKey = $null
                if ($loc -like "HKLM*") {
                    $regKey = [Microsoft.Win32.Registry]::LocalMachine
                } elseif ($loc -like "HKCU*") {
                    $regKey = [Microsoft.Win32.Registry]::CurrentUser
                }
                $subPath = ($loc -split "HKLM:|HKCU:")[1].TrimStart("\")
                $key = $regKey.OpenSubKey($subPath, $true)
                if ($key) {
                    foreach ($valName in $key.GetValueNames()) {
                        $valData = $key.GetValue($valName)
                        foreach ($term in $terms) {
                            if ($valName -match $term -or ($valData -and $valData.ToString() -match $term)) {
                                Write-Host "Deleting startup entry '$valName' in $loc ..." -ForegroundColor White
                                try {
                                    $key.DeleteValue($valName)
                                    Add-DeletedItem "Startup" "Key $loc -> $valName"
                                    Write-Host "  -> Registry entry deleted: $valName ($loc)" -ForegroundColor Green
                                }
                                catch {
                                    Add-FailedItem "Startup" "Key $loc -> $valName"
                                    Write-Host "  -> Failed to delete registry entry: $valName ($loc)" -ForegroundColor Red
                                }
                                break
                            }
                        }
                    }
                }
            } catch { }
        }
        # Delete Startup folder files
        foreach ($filePath in $startupFiles) {
            Write-Host "Deleting startup shortcut $filePath ..." -ForegroundColor White
            try {
                Remove-Item -Path $filePath -Force -ErrorAction Stop
                Add-DeletedItem "Startup" $filePath
                Write-Host "  -> Shortcut deleted: $filePath" -ForegroundColor Green
            }
            catch {
                Add-FailedItem "Startup" $filePath
                Write-Host "  -> Failed to delete shortcut: $filePath" -ForegroundColor Red
            }
        }
    } else {
        Write-Host ">> Step 'Services/Tasks/Startup' skipped by the user." -ForegroundColor Yellow
        $SkippedSections += "ServicesAndTasks"
    }
}
Write-Host ""

# 6. Final Report
Write-Host "=== Autodesk Cleanup Report ===" -ForegroundColor Cyan
# Processed sections
if ($SkippedSections.Count -gt 0) {
    Write-Host "Steps skipped by the user: $($SkippedSections -join ', ')" -ForegroundColor Yellow
}
# Successfully deleted items
if ($DeletedItems.Keys.Count -gt 0) {
    Write-Host "`nDeleted items:" -ForegroundColor Green
    foreach ($category in $DeletedItems.Keys) {
        $items = $DeletedItems[$category]
        foreach ($it in $items) {
            Write-Host "  [$category] $it" -ForegroundColor Green
        }
    }
} else {
    Write-Host "`nNo item was deleted." -ForegroundColor Yellow
}
# Items that failed to delete
if ($FailedItems.Keys.Count -gt 0) {
    Write-Host "`nItems that failed to delete:" -ForegroundColor Red
    foreach ($category in $FailedItems.Keys) {
        $items = $FailedItems[$category]
        foreach ($it in $items) {
            Write-Host "  [$category] $it" -ForegroundColor Red
        }
    }
    Write-Host "`nSome items could not be deleted." -ForegroundColor Red
    Write-Host "They may be in use, have insufficient permissions or might not exist." -ForegroundColor Red
} else {
    Write-Host "`nAll targeted items were successfully deleted." -ForegroundColor Green
}
Write-Host "`n*** End of Autodesk cleanup script ***" -ForegroundColor Cyan
