Set-StrictMode -Version 3.0

$script:CalcXProtocolVersion = 1
$script:CalcXBundleName = 'com.startyi.calcx'

function Write-CalcXDiagnostic {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
}

function ConvertTo-CalcXBase64Url {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function ConvertFrom-CalcXBase64Url {
    param([Parameter(Mandatory)][string]$Text)
    if ($Text -notmatch '^[A-Za-z0-9_-]+$') {
        throw 'Value is not URL-safe Base64.'
    }
    $padded = $Text.Replace('-', '+').Replace('_', '/')
    switch ($padded.Length % 4) {
        0 { }
        2 { $padded += '==' }
        3 { $padded += '=' }
        default { throw 'URL-safe Base64 has an invalid length.' }
    }
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($padded))
}

function Resolve-CalcXHdcExecutable {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "HDC was not found at the supplied path: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $command = Get-Command hdc -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($environmentName in @('DEVECO_SDK_HOME', 'HARMONYOS_SDK_HOME')) {
        $environmentValue = [Environment]::GetEnvironmentVariable($environmentName)
        if ($environmentValue) {
            $candidates.Add((Join-Path $environmentValue 'default\openharmony\toolchains\hdc.exe'))
            $candidates.Add((Join-Path $environmentValue 'openharmony\toolchains\hdc.exe'))
        }
    }

    foreach ($entry in Get-ChildItem Env: -ErrorAction SilentlyContinue) {
        if ($entry.Name -match 'DevEco' -and $entry.Value) {
            $installRoot = Split-Path -Parent $entry.Value
            $candidates.Add((Join-Path $installRoot 'sdk\default\openharmony\toolchains\hdc.exe'))
        }
    }

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($application in Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue) {
        $displayNameProperty = $application.PSObject.Properties['DisplayName']
        $installLocationProperty = $application.PSObject.Properties['InstallLocation']
        if ($displayNameProperty -and $installLocationProperty -and
            $displayNameProperty.Value -like '*DevEco Studio*' -and $installLocationProperty.Value) {
            $candidates.Add((Join-Path $installLocationProperty.Value 'sdk\default\openharmony\toolchains\hdc.exe'))
        }
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'HDC was not found in PATH, an SDK environment variable, or a DevEco Studio installation. Use -HdcPath.'
}

function Invoke-CalcXProcessWithTimeout {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Failed to start process: $FilePath"
    }
    $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
    $standardErrorTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw [TimeoutException]::new("Process timed out after $TimeoutSeconds seconds.")
    }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $standardOutputTask.GetAwaiter().GetResult()
        StdErr = $standardErrorTask.GetAwaiter().GetResult()
    }
}

function Get-CalcXDevice {
    param(
        [Parameter(Mandatory)][string]$HdcPath,
        [string]$DeviceId
    )

    $listResult = Invoke-CalcXProcessWithTimeout -FilePath $HdcPath -ArgumentList @('list', 'targets') -TimeoutSeconds 10
    if ($listResult.ExitCode -ne 0) {
        throw "HDC could not list devices (exit $($listResult.ExitCode)): $($listResult.StdErr.Trim())"
    }
    $targets = @($listResult.StdOut -split "`r?`n" | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -ne '[Empty]' -and -not $_.StartsWith('[') })

    if ($DeviceId) {
        if ($targets -notcontains $DeviceId) {
            throw "Requested device '$DeviceId' is not connected."
        }
        return $DeviceId
    }
    if ($targets.Count -eq 0) {
        throw 'No HarmonyOS device is connected. Device execution was not attempted.'
    }
    if ($targets.Count -gt 1) {
        throw 'Multiple HarmonyOS devices are connected. Use -DeviceId to select one.'
    }
    return $targets[0]
}

function New-CalcXRequestId {
    return [Guid]::NewGuid().ToString('D')
}

function Get-CalcXProtocolVersion {
    return $script:CalcXProtocolVersion
}

function Get-CalcXBundleName {
    return $script:CalcXBundleName
}

function Get-CalcXLayoutDocument {
    param(
        [Parameter(Mandatory)][string]$HdcPath,
        [Parameter(Mandatory)][string]$DeviceId,
        [int]$TimeoutSeconds = 15
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $dumpResult = Invoke-CalcXProcessWithTimeout -FilePath $HdcPath `
                -ArgumentList @('-t', $DeviceId, 'shell', 'uitest', 'dumpLayout') `
                -TimeoutSeconds $TimeoutSeconds
            if ($dumpResult.ExitCode -ne 0) {
                throw "uitest dumpLayout failed (exit $($dumpResult.ExitCode)): $($dumpResult.StdErr.Trim())"
            }
            $pathMatch = [regex]::Match($dumpResult.StdOut + "`n" + $dumpResult.StdErr, '(/[^\s]+\.json)')
            if (-not $pathMatch.Success) {
                throw 'uitest dumpLayout did not report a remote JSON path.'
            }
            $localLayoutPath = [IO.Path]::GetTempFileName()
            try {
                $readResult = Invoke-CalcXProcessWithTimeout -FilePath $HdcPath `
                    -ArgumentList @('-t', $DeviceId, 'file', 'recv', $pathMatch.Groups[1].Value, $localLayoutPath) `
                    -TimeoutSeconds $TimeoutSeconds
                if ($readResult.ExitCode -ne 0 -or (Get-Item -LiteralPath $localLayoutPath).Length -eq 0) {
                    throw "Unable to receive the layout JSON (exit $($readResult.ExitCode))."
                }
                $layoutText = Get-Content -Raw -LiteralPath $localLayoutPath
                try {
                    return $layoutText | ConvertFrom-Json
                } catch {
                    # Some platform builds emit unescaped LaTeX in originalText. The CLI does not consume that field.
                    $sanitizedLayout = [regex]::Replace(
                        $layoutText,
                        '"originalText":".*?","scrollable":',
                        '"originalText":"","scrollable":',
                        [Text.RegularExpressions.RegexOptions]::Singleline
                    )
                    return $sanitizedLayout | ConvertFrom-Json
                }
            } finally {
                Remove-Item -LiteralPath $localLayoutPath -Force -ErrorAction SilentlyContinue
            }
        } catch {
            $lastError = $_.Exception
            if ($attempt -lt 3) {
                Start-Sleep -Milliseconds 100
            }
        }
    }
    throw "Unable to obtain a valid UI layout after 3 attempts: $($lastError.Message)"
}

function Get-CalcXNodeAttribute {
    param(
        [Parameter(Mandatory)][psobject]$Node,
        [Parameter(Mandatory)][string]$Name
    )
    $attributesProperty = $Node.PSObject.Properties['attributes']
    if (-not $attributesProperty -or $null -eq $attributesProperty.Value) {
        return $null
    }
    $property = $attributesProperty.Value.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }
    return $null
}

function Find-CalcXLayoutNodes {
    param(
        [Parameter(Mandatory)][psobject]$Root,
        [Parameter(Mandatory)][scriptblock]$Predicate
    )

    $matches = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Stack[object]]::new()
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        $node = $pending.Pop()
        if (& $Predicate $node) {
            $matches.Add($node)
        }
        $childrenProperty = $node.PSObject.Properties['children']
        if ($childrenProperty -and $childrenProperty.Value) {
            foreach ($child in @($childrenProperty.Value)) {
                $pending.Push($child)
            }
        }
    }
    return @($matches)
}

function ConvertTo-CalcXBoolean {
    param([object]$Value)
    return "$Value" -eq 'true'
}

function ConvertTo-CalcXControl {
    param([Parameter(Mandatory)][psobject]$Node)

    $id = [string](Get-CalcXNodeAttribute -Node $Node -Name 'id')
    $key = [string](Get-CalcXNodeAttribute -Node $Node -Name 'key')
    $semanticId = if ($id) { $id } else { $key }
    return [pscustomobject][ordered]@{
        id = $semanticId
        platformId = $id
        key = $key
        type = [string](Get-CalcXNodeAttribute -Node $Node -Name 'type')
        text = [string](Get-CalcXNodeAttribute -Node $Node -Name 'text')
        description = [string](Get-CalcXNodeAttribute -Node $Node -Name 'description')
        bounds = [string](Get-CalcXNodeAttribute -Node $Node -Name 'bounds')
        visible = ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $Node -Name 'visible')
        enabled = ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $Node -Name 'enabled')
        clickable = ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $Node -Name 'clickable')
        selected = ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $Node -Name 'selected')
        focused = ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $Node -Name 'focused')
        hierarchy = [string](Get-CalcXNodeAttribute -Node $Node -Name 'hierarchy')
    }
}

function Get-CalcXAppLayout {
    param([Parameter(Mandatory)][psobject]$Document)

    $bundleName = Get-CalcXBundleName
    $appRoots = @(Find-CalcXLayoutNodes -Root $Document -Predicate {
        param($node)
        (Get-CalcXNodeAttribute -Node $node -Name 'bundleName') -eq $bundleName
    })
    if ($appRoots.Count -eq 0) {
        return $null
    }
    $focusedRoots = @($appRoots | Where-Object {
        ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $_ -Name 'focused')
    })
    $appRoot = if ($focusedRoots.Count -gt 0) { $focusedRoots[0] } else { $appRoots[0] }
    $controls = @(Find-CalcXLayoutNodes -Root $appRoot -Predicate {
        param($node)
        $true
    } | ForEach-Object { ConvertTo-CalcXControl -Node $_ })
    return [pscustomobject]@{
        Root = $appRoot
        Controls = $controls
        Ability = [string](Get-CalcXNodeAttribute -Node $appRoot -Name 'abilityName')
        PagePath = [string](Get-CalcXNodeAttribute -Node $appRoot -Name 'pagePath')
        Foreground = ConvertTo-CalcXBoolean (Get-CalcXNodeAttribute -Node $appRoot -Name 'focused')
    }
}

function Get-CalcXBoundsCenter {
    param([Parameter(Mandatory)][string]$Bounds)

    $match = [regex]::Match($Bounds, '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
    if (-not $match.Success) {
        throw "Invalid control bounds: $Bounds"
    }
    $left = [int]$match.Groups[1].Value
    $top = [int]$match.Groups[2].Value
    $right = [int]$match.Groups[3].Value
    $bottom = [int]$match.Groups[4].Value
    if ($right -le $left -or $bottom -le $top) {
        throw "Control bounds have no clickable area: $Bounds"
    }
    return [pscustomobject]@{
        X = [int][Math]::Floor(($left + $right) / 2)
        Y = [int][Math]::Floor(($top + $bottom) / 2)
    }
}

Export-ModuleMember -Function @(
    'Write-CalcXDiagnostic',
    'ConvertTo-CalcXBase64Url',
    'ConvertFrom-CalcXBase64Url',
    'Resolve-CalcXHdcExecutable',
    'Invoke-CalcXProcessWithTimeout',
    'Get-CalcXDevice',
    'New-CalcXRequestId',
    'Get-CalcXProtocolVersion',
    'Get-CalcXBundleName',
    'Get-CalcXLayoutDocument',
    'Get-CalcXNodeAttribute',
    'Find-CalcXLayoutNodes',
    'ConvertTo-CalcXControl',
    'Get-CalcXAppLayout',
    'Get-CalcXBoundsCenter'
)
