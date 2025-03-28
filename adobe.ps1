###############################################################################
# Interactive PowerShell Script for Complete Adobe Product Cleanup
# This script deletes directories, registry keys, caches, services,
# scheduled tasks, and startup entries related to Adobe software.
# Compatible with Windows 10/11. Must be run as an administrator.
###############################################################################

# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as an administrator." -ForegroundColor Red
    Write-Host "Please restart PowerShell in administrator mode and try again."
    exit 1
}

# Step 1: Delete Adobe Directories
Write-Host "`n=== Step 1: Adobe Directories ===" -ForegroundColor Cyan
$folders = @(
    "$Env:ProgramFiles\Adobe",
    "${Env:ProgramFiles(x86)}\Adobe",
    "$Env:ProgramFiles\Common Files\Adobe",
    "${Env:ProgramFiles(x86)}\Common Files\Adobe",
    "$Env:APPDATA\Adobe",
    "$Env:LOCALAPPDATA\Adobe",
    "$Env:ProgramData\Adobe"
)
Write-Host "The following folders (if they exist) will be deleted:" -ForegroundColor Yellow
foreach ($folder in $folders) {
    Write-Host " - $folder"
}
$response = Read-Host "Do you confirm the deletion of these folders and their contents? (Y/N)"
if ($response -notin @('Y','y','O','o')) {
    Write-Host "Step 1 canceled by the user." -ForegroundColor Yellow
    $deletedFolders = @()
    $failedFolders = @()
} else {
    $deletedFolders = @()
    $failedFolders = @()
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            try {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                $deletedFolders += $folder
            } catch {
                $failedFolders += $folder
            }
        }
    }
    if ($deletedFolders.Count -gt 0) {
        Write-Host "Deleted folders:" -ForegroundColor Green
        $deletedFolders | ForEach-Object { Write-Host "  [OK] $_" -ForegroundColor Green }
    }
    if ($failedFolders.Count -gt 0) {
        Write-Host "Folders failed to delete:" -ForegroundColor Red
        $failedFolders | ForEach-Object { Write-Host "  [FAILED] $_" -ForegroundColor Red }
    }
    if (($deletedFolders.Count + $failedFolders.Count) -eq 0) {
        Write-Host "No Adobe folders found to delete." -ForegroundColor Yellow
    }
}

# Step 2: Cleanup Adobe Registry Keys
Write-Host "`n=== Step 2: Registry ===" -ForegroundColor Cyan
$registryKeys = @()
$hives = @("HKLM:\SOFTWARE", "HKLM:\SOFTWARE\Wow6432Node", "HKCU:\SOFTWARE")
foreach ($hive in $hives) {
    try {
        Get-ChildItem -Path $hive -ErrorAction Stop | Where-Object { $_.PSChildName -match '(?i)Adobe' } | ForEach-Object {
            $registryKeys += "$($hive)\$($_.PSChildName)"
        }
    } catch {
        continue
    }
}
$registryKeys = $registryKeys | Select-Object -Unique
if ($registryKeys.Count -eq 0) {
    Write-Host "No registry key containing 'Adobe' was found in HKLM/HKCU."
    $deletedRegistry = @(); $failedRegistry = @()
} else {
    Write-Host "The following registry keys will be deleted (if present):"
    foreach ($key in $registryKeys) {
        Write-Host " - $key"
    }
    $response = Read-Host "Do you confirm the deletion of these registry keys? (Y/N)"
    $deletedRegistry = @(); $failedRegistry = @()
    if ($response -notin @('Y','y','O','o')) {
        Write-Host "Step 2 canceled by the user." -ForegroundColor Yellow
    } else {
        foreach ($key in $registryKeys) {
            if (Test-Path $key) {
                try {
                    Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                    $deletedRegistry += $key
                } catch {
                    $failedRegistry += $key
                }
            }
        }
        if ($deletedRegistry.Count -gt 0) {
            Write-Host "Deleted registry keys:" -ForegroundColor Green
            $deletedRegistry | ForEach-Object { Write-Host "  [OK] $_" -ForegroundColor Green }
        }
        if ($failedRegistry.Count -gt 0) {
            Write-Host "Registry keys failed to delete:" -ForegroundColor Red
            $failedRegistry | ForEach-Object { Write-Host "  [FAILED] $_" -ForegroundColor Red }
        }
        if (($deletedRegistry.Count + $failedRegistry.Count) -eq 0) {
            Write-Host "No Adobe registry key found to delete." -ForegroundColor Yellow
        }
    }
}

# Step 3: Delete Adobe Temporary Files and Caches
Write-Host "`n=== Step 3: Adobe Temp/Caches ===" -ForegroundColor Cyan
$tempDir = $Env:TEMP
$tempFiles = @()
try {
    $tempFiles = Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction Stop |
                    Where-Object { $_.Name -match '(?i)^(Adobe|Photoshop Temp)' }
} catch {
    Write-Host "Error accessing temporary folder: $_" -ForegroundColor Red
    $tempFiles = @()
}
if (!$tempFiles) {
    Write-Host "No Adobe temporary file found to delete."
    $deletedTemp = @(); $failedTemp = @()
} else {
    $nbTemp = $tempFiles.Count
    $examples = ($tempFiles | Select-Object -First 3 -ExpandProperty Name) -join ", "
    if ($nbTemp -le 3) {
        Write-Host "$nbTemp Adobe temporary file(s)/folder(s) found: $examples"
    } else {
        Write-Host "$nbTemp Adobe temporary files/folders found (examples: $examples ...)"
    }
    $response = Read-Host "Do you confirm the deletion of these Adobe temporary files? (Y/N)"
    $deletedTemp = @(); $failedTemp = @()
    if ($response -notin @('Y','y','O','o')) {
        Write-Host "Step 3 canceled by the user." -ForegroundColor Yellow
    } else {
        foreach ($item in $tempFiles) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedTemp += $item.FullName
            } catch {
                $failedTemp += $item.FullName
            }
        }
        if ($deletedTemp.Count -gt 0) {
            Write-Host "Deleted temporary files/folders:" -ForegroundColor Green
            $deletedTemp | ForEach-Object { Write-Host "  [OK] $_" -ForegroundColor Green }
        }
        if ($failedTemp.Count -gt 0) {
            Write-Host "Failed to delete (Temp):" -ForegroundColor Red
            $failedTemp | ForEach-Object { Write-Host "  [FAILED] $_" -ForegroundColor Red }
        }
        if (($deletedTemp.Count + $failedTemp.Count) -eq 0) {
            Write-Host "No Adobe temporary file found to delete." -ForegroundColor Yellow
        }
    }
}

# Step 4: Delete Adobe Services, Scheduled Tasks and Startup Entries
Write-Host "`n=== Step 4: Adobe Services and Tasks ===" -ForegroundColor Cyan
$servicesFound = Get-CimInstance Win32_Service -Filter "Name LIKE '%Adobe%' OR DisplayName LIKE '%Adobe%'"
$tasksFound = Get-ScheduledTask | Where-Object { $_.TaskName -like '*Adobe*' -or $_.TaskPath -like '*Adobe*' }
$runPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$startupEntries = @()
foreach ($rp in $runPaths) {
    try {
        $values = Get-ItemProperty -Path $rp -ErrorAction Stop
    } catch {
        continue
    }
    $props = $values.PSObject.Properties | Where-Object { $_.Name -match '(?i)Adobe' }
    foreach ($prop in $props) {
        $location = if ($rp -match 'HKCU:') { "(user startup)" } else { "(machine startup)" }
        $startupEntries += "$($prop.Name) $location"
    }
}
if ((-not $servicesFound) -and (-not $tasksFound) -and ($startupEntries.Count -eq 0)) {
    Write-Host "No Adobe service, scheduled task or startup entry detected."
    $deletedServices=@(); $failedServices=@()
    $deletedTasks=@(); $failedTasks=@()
    $deletedRun=@(); $failedRun=@()
} else {
    if ($servicesFound) {
        Write-Host "Adobe Windows Services found:" -ForegroundColor Yellow
        $servicesFound | ForEach-Object {
            Write-Host " - $($_.DisplayName) [Service: $($_.Name)]"
        }
    } else {
        Write-Host "No Adobe service found."
    }
    if ($tasksFound) {
        Write-Host "Adobe Scheduled Tasks found:" -ForegroundColor Yellow
        $tasksFound | ForEach-Object {
            Write-Host " - $($_.TaskName) (Path: $($_.TaskPath))"
        }
    } else {
        Write-Host "No Adobe scheduled task found."
    }
    if ($startupEntries.Count -gt 0) {
        Write-Host "Adobe startup entries found in the registry:" -ForegroundColor Yellow
        $startupEntries | ForEach-Object {
            Write-Host " - $_"
        }
    } else {
        Write-Host "No Adobe startup entry found."
    }
    $response = Read-Host "Do you confirm deletion of these Adobe services/tasks/startup entries? (Y/N)"
    $deletedServices=@(); $failedServices=@()
    $deletedTasks=@(); $failedTasks=@()
    $deletedRun=@(); $failedRun=@()
    if ($response -notin @('Y','y','O','o')) {
        Write-Host "Step 4 canceled by the user." -ForegroundColor Yellow
    } else {
        # Delete services
        foreach ($svc in $servicesFound) {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            } catch { }
            & sc.exe delete $($svc.Name) | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $deletedServices += "$($svc.DisplayName) ($($svc.Name))"
            } else {
                $failedServices += "$($svc.DisplayName) ($($svc.Name))"
            }
        }
        # Delete scheduled tasks
        foreach ($task in $tasksFound) {
            try {
                Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                $deletedTasks += "$($task.TaskName) $($task.TaskPath)"
            } catch {
                $failedTasks += "$($task.TaskName) $($task.TaskPath)"
            }
        }
        # Delete startup entries (Run)
        foreach ($rp in $runPaths) {
            try {
                $values = Get-ItemProperty -Path $rp -ErrorAction Stop
            } catch {
                continue
            }
            $props = $values.PSObject.Properties | Where-Object { $_.Name -match '(?i)Adobe' }
            foreach ($prop in $props) {
                try {
                    Remove-ItemProperty -Path $rp -Name $prop.Name -ErrorAction Stop
                    $deletedRun += "$($prop.Name) [$rp]"
                } catch {
                    $failedRun += "$($prop.Name) [$rp]"
                }
            }
        }
    }
}

# Final Report
Write-Host "`n===== FINAL REPORT =====" -ForegroundColor Cyan
# 1. Folders
if ($deletedFolders) {
    Write-Host "[Folders] Deleted:" -ForegroundColor Green
    $deletedFolders | ForEach-Object { Write-Host "  - $_" }
}
if ($failedFolders) {
    Write-Host "[Folders] Failed to delete:" -ForegroundColor Red
    $failedFolders | ForEach-Object { Write-Host "  - $_" }
}
if (-not $deletedFolders -and -not $failedFolders) {
    Write-Host "[Folders] No targeted folder was deleted." -ForegroundColor Yellow
}
# 2. Registry
if ($deletedRegistry) {
    Write-Host "[Registry] Deleted keys:" -ForegroundColor Green
    $deletedRegistry | ForEach-Object { Write-Host "  - $_" }
}
if ($failedRegistry) {
    Write-Host "[Registry] Failed to delete keys:" -ForegroundColor Red
    $failedRegistry | ForEach-Object { Write-Host "  - $_" }
}
if (-not $deletedRegistry -and -not $failedRegistry) {
    Write-Host "[Registry] No targeted registry key was deleted." -ForegroundColor Yellow
}
# 3. Temporary Files
if ($deletedTemp) {
    Write-Host "[Temporary Files] Deleted:" -ForegroundColor Green
    $deletedTemp | ForEach-Object { Write-Host "  - $_" }
}
if ($failedTemp) {
    Write-Host "[Temporary Files] Failed to delete:" -ForegroundColor Red
    $failedTemp | ForEach-Object { Write-Host "  - $_" }
}
if (-not $deletedTemp -and -not $failedTemp) {
    Write-Host "[Temporary Files] No targeted file/folder was deleted." -ForegroundColor Yellow
}
# 4. Services
if ($deletedServices) {
    Write-Host "[Services] Deleted:" -ForegroundColor Green
    $deletedServices | ForEach-Object { Write-Host "  - $_" }
}
if ($failedServices) {
    Write-Host "[Services] Failed to delete:" -ForegroundColor Red
    $failedServices | ForEach-Object { Write-Host "  - $_" }
}
if (-not $deletedServices -and -not $failedServices) {
    Write-Host "[Services] No targeted service was deleted." -ForegroundColor Yellow
}
# 5. Scheduled Tasks
if ($deletedTasks) {
    Write-Host "[Tasks] Deleted:" -ForegroundColor Green
    $deletedTasks | ForEach-Object { Write-Host "  - $_" }
}
if ($failedTasks) {
    Write-Host "[Tasks] Failed to delete:" -ForegroundColor Red
    $failedTasks | ForEach-Object { Write-Host "  - $_" }
}
if (-not $deletedTasks -and -not $failedTasks) {
    Write-Host "[Tasks] No targeted task was deleted." -ForegroundColor Yellow
}
# 6. Startup Entries
if ($deletedRun) {
    Write-Host "[Startup] Deleted (Run):" -ForegroundColor Green
    $deletedRun | ForEach-Object { Write-Host "  - $_" }
}
if ($failedRun) {
    Write-Host "[Startup] Failed to delete (Run):" -ForegroundColor Red
    $failedRun | ForEach-Object { Write-Host "  - $_" }
}
if (-not $deletedRun -and -not $failedRun) {
    Write-Host "[Startup] No targeted startup entry was deleted." -ForegroundColor Yellow
}

Write-Host "`nAutodesk cleanup completed. See details above." -ForegroundColor Cyan
Write-Host "Tip: A system restart is recommended if any services were deleted to complete their removal." -ForegroundColor Cyan
