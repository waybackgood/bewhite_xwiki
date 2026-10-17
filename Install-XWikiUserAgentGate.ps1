#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$XWikiHome = 'C:\xwiki',
    [string]$TaskName = 'Xwiki',
    [ValidatePattern('^[A-Za-z0-9-]+$')]
    [string]$AllowedUserAgent = 'BW-SJKIM940708'
)

$ErrorActionPreference = 'Stop'
$webXml = Join-Path $XWikiHome 'webapps\xwiki\WEB-INF\web.xml'
$libDir = Join-Path $XWikiHome 'webapps\xwiki\WEB-INF\lib'
$jarSource = Join-Path $PSScriptRoot 'ua-gate-1.0.0.jar'
if (-not (Test-Path -LiteralPath $jarSource)) {
    $jarSource = Join-Path $PSScriptRoot 'target\ua-gate-1.0.0.jar'
}
$jarTarget = Join-Path $libDir 'ua-gate-1.0.0.jar'
$warFile = Join-Path $XWikiHome 'webapps\xwiki.war'

foreach ($path in @($webXml, $libDir, $jarSource)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing required path: $path" }
}
if (Test-Path -LiteralPath $jarTarget) {
    throw "Gate JAR already exists; inspect the current installation first: $jarTarget"
}
$originalTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop

$document = New-Object System.Xml.XmlDocument
$document.PreserveWhitespace = $true
$document.XmlResolver = $null
$document.Load($webXml)
$root = $document.DocumentElement
if ($root.LocalName -ne 'web-app') { throw "Unexpected web.xml root: $($root.LocalName)" }

$filters = @($root.ChildNodes | Where-Object {
    $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.LocalName -eq 'filter'
})
$mappings = @($root.ChildNodes | Where-Object {
    $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.LocalName -eq 'filter-mapping'
})
if ($filters.Count -eq 0 -or $mappings.Count -eq 0) {
    throw 'Existing XWiki filters or filter mappings were not found; inspect web.xml manually.'
}
if ($document.SelectNodes("//*[local-name()='filter-name' and text()='userAgentGate']").Count -gt 0) {
    throw 'userAgentGate is already declared in web.xml; inspect it before changing anything.'
}

function New-WebElement {
    param([string]$Name, [string]$Value)
    $element = $document.CreateElement($Name, $root.NamespaceURI)
    if ($PSBoundParameters.ContainsKey('Value')) { $element.InnerText = $Value }
    return $element
}

function Get-IndentBefore {
    param([System.Xml.XmlNode]$Node)
    if ($Node.PreviousSibling -and
        $Node.PreviousSibling.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) {
        return $Node.PreviousSibling.Value
    }
    return "`r`n  "
}

$filter = New-WebElement 'filter'
$null = $filter.AppendChild((New-WebElement 'filter-name' 'userAgentGate'))
$null = $filter.AppendChild((New-WebElement 'filter-class' 'lab.UserAgentGateFilter'))
$initParam = New-WebElement 'init-param'
$null = $initParam.AppendChild((New-WebElement 'param-name' 'allowedUserAgent'))
$null = $initParam.AppendChild((New-WebElement 'param-value' $AllowedUserAgent))
$null = $filter.AppendChild($initParam)

$mapping = New-WebElement 'filter-mapping'
$null = $mapping.AppendChild((New-WebElement 'filter-name' 'userAgentGate'))
$null = $mapping.AppendChild((New-WebElement 'url-pattern' '/*'))
$null = $mapping.AppendChild((New-WebElement 'dispatcher' 'REQUEST'))

$filterIndent = Get-IndentBefore $filters[0]
$mappingIndent = Get-IndentBefore $mappings[0]
$null = $root.InsertBefore($filter, $filters[0])
$null = $root.InsertBefore($document.CreateWhitespace($filterIndent), $filters[0])
$null = $root.InsertBefore($mapping, $mappings[0])
$null = $root.InsertBefore($document.CreateWhitespace($mappingIndent), $mappings[0])

$backup = "$webXml.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$taskStopped = $false
$backupCreated = $false
$jarAdded = $false
try {
    if (Test-Path -LiteralPath $warFile) {
        Write-Warning "xwiki.war exists. A future redeployment may overwrite this web.xml and JAR."
    }
    if ($originalTask.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName
        $taskStopped = $true
    }
    $deadline = (Get-Date).AddSeconds(45)
    do {
        $listener = @(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)
        if ($listener.Count -eq 0) { break }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    if ($listener.Count -gt 0) {
        throw 'Port 8080 is still listening after stopping the task; no files were changed.'
    }

    Copy-Item -LiteralPath $webXml -Destination $backup -ErrorAction Stop
    $backupCreated = $true
    Copy-Item -LiteralPath $jarSource -Destination $jarTarget -ErrorAction Stop
    $jarAdded = $true
    $document.Save($webXml)

    $check = New-Object System.Xml.XmlDocument
    $check.XmlResolver = $null
    $check.Load($webXml)
    Start-ScheduledTask -TaskName $TaskName
    $taskStopped = $false
    Write-Host "Gate files installed for User-Agent: $AllowedUserAgent"
    Write-Host "Backup: $backup"
    Write-Host 'XWiki start requested. Wait for port 8080, then verify blocked and allowed HTTP requests.'
} catch {
    $originalError = $_
    $configRestored = -not $backupCreated
    if ($backupCreated) {
        try {
            Copy-Item -LiteralPath $backup -Destination $webXml -Force -ErrorAction Stop
            $configRestored = $true
        } catch { Write-Warning "Could not restore web.xml from $backup : $_" }
    }
    if ($backupCreated -and (Test-Path -LiteralPath $jarTarget)) {
        try {
            Remove-Item -LiteralPath $jarTarget -Force -ErrorAction Stop
        } catch { Write-Warning "Could not remove gate JAR at $jarTarget : $_" }
    }
    if ($taskStopped -and $configRestored) {
        try {
            Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        } catch { Write-Warning "Could not restart task $TaskName : $_" }
    }
    throw $originalError
}
