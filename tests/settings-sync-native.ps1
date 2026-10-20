# Runs in a new, hidden AutoCAD 2026 instance using only disposable drawings.
# Does not attach to an existing session or save DWG files.
param(
    [string]$Template = "$env:LOCALAPPDATA\Autodesk\C3D 2026\enu\Template\AutoCAD Template\acadiso.dwt"
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Template)) { throw "Template not found: $Template" }
$taskSource = (Join-Path (Split-Path -Parent $PSScriptRoot) 'bota_help_v5_pt.lsp').Replace('\', '/')
$taskResults = Join-Path $env:TEMP ('botahelp-sync-native-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskResults | Out-Null
$taskAcad = $null
$taskDrawings = [System.Collections.Generic.List[object]]::new()

function Invoke-CadCall([scriptblock]$Action) {
    $taskDeadline = [DateTime]::UtcNow.AddSeconds(45)
    while ($true) {
        try { return & $Action }
        catch [System.Runtime.InteropServices.COMException] {
            if ($_.Exception.HResult -notin @(-2147418111, -2147417846) -or [DateTime]::UtcNow -gt $taskDeadline) { throw }
            Start-Sleep -Milliseconds 250
        }
    }
}

function Invoke-CadCheck($Drawing, [string]$Label, [string]$Setup, [string]$Condition) {
    $taskResultFile = Join-Path $taskResults ($Label + '.txt')
    $taskLispFile = $taskResultFile.Replace('\', '/')
    Invoke-CadCall { $Drawing.Activate() }
    $taskCode = '(progn ' + $Setup + ' (setq bssResult (open "' + $taskLispFile + '" "w")) ' +
        '(write-line (if ' + $Condition + ' "PASS" "FAIL") bssResult) (close bssResult) (princ))' + "`n"
    Invoke-CadCall { $Drawing.SendCommand($taskCode) }
    $taskDeadline = [DateTime]::UtcNow.AddSeconds(45)
    while (-not (Test-Path -LiteralPath $taskResultFile)) {
        if ([DateTime]::UtcNow -gt $taskDeadline) { throw "Timed out: $Label" }
        Start-Sleep -Milliseconds 250
    }
    $taskResult = (Get-Content -LiteralPath $taskResultFile -Raw).Trim()
    if ($taskResult -ne 'PASS') { throw "FAIL: $Label" }
    Write-Output "PASS: $Label"
}

function New-CadDrawing {
    $taskDrawing = Invoke-CadCall { $taskAcad.Documents.Add($Template) }
    $taskDrawings.Add($taskDrawing)
    Invoke-CadCheck $taskDrawing ('load-' + $taskDrawings.Count) `
        ('(setq *BOTAHELP_SUPPRESS_STARTUP_HELP* T) (load "' + $taskSource + '")') `
        '(_bota_session_pull)' | Out-Host
    return $taskDrawing
}

try {
    Write-Output 'Starting isolated AutoCAD 2026 instance...'
    $taskAcad = New-Object -ComObject AutoCAD.Application.25.1
    Invoke-CadCall { $taskAcad.Visible = $false }
    $taskA = New-CadDrawing
    $taskB = New-CadDrawing
    $taskValues = "'(12.0 40.0 0.7 0.0 28.0 1.1 11.0 0.8 ((80.0 90.0 9.0 0.5) (90.0 110.0 11.0 0.8) (110.0 130.0 14.0 1.0) (130.0 180.0 17.0 1.2)) 0.0 0.0 0.0 0.0 0.6)"
    Invoke-CadCheck $taskA 'publish-all' `
        "(setq *BOTA_RECTO_K* 0.0) (_bota_cfg_apply_values $taskValues)" `
        "(equal (_bota_cfg_current_values) $taskValues 1e-8)"
    Invoke-CadCheck $taskB 'existing-drawing' '(_bota_session_pull)' `
        "(and (equal (_bota_cfg_current_values) $taskValues 1e-8) (= *BOTA_RECTO_K* 0.0) (not *BOTA3_DENSIFY*) (not *BOTA_CONECTAR_CAB*) (not *BOTA_CORTAR_CIRCULO*))"
    Invoke-CadCheck $taskB 'publish-back' '(setq *BOTA_RGIRO* 17.0) (_bota_session_publish)' '(= *BOTA_RGIRO* 17.0)'
    Invoke-CadCheck $taskA 'reverse-direction' '(_bota_session_pull)' '(= *BOTA_RGIRO* 17.0)'
    $taskC = New-CadDrawing
    Invoke-CadCheck $taskC 'new-drawing' '' '(and (= *BOTA_RGIRO* 17.0) (= *BOTA_IMPL* 40.0) (= *BOTA_RECTO_K* 0.0))'
    Invoke-CadCheck $taskB 'reload' `
        ('(setq *BOTA_IMPL* 2.0) (load "' + $taskSource + '")') `
        '(and (= *BOTA_IMPL* 40.0) (= *BOTA_RGIRO* 17.0) (not *BOTA3_DENSIFY*))'
    Invoke-CadCheck $taskA 'reject-invalid' `
        '(setq bssBefore (vl-bb-ref (quote BOTAHELP_SETTINGS_V1))) (_bota_cfg_apply_values (cons -1.0 (cdr (_bota_cfg_current_values))))' `
        '(equal bssBefore (vl-bb-ref (quote BOTAHELP_SETTINGS_V1)))'
    Write-Output "Native multi-drawing checks passed. Results: $taskResults"
}
finally {
    if ($taskAcad) {
        foreach ($taskDrawing in $taskDrawings) {
            try { Invoke-CadCall { $taskDrawing.Close($false) } } catch { Write-Warning $_ }
        }
        try { Invoke-CadCall { $taskAcad.Quit() } } catch { Write-Warning $_ }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($taskAcad)
    }
}
