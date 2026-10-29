param([string]$TdHome = 'C:\APP2\ALTD')

$ErrorActionPreference = 'Stop'

$taskProjectName = 'wb_ui_dsi'

$taskTdExe = Join-Path $TdHome 'bin/td_commands_prompt.exe'

$taskFlow = (Join-Path $TdHome 'doc/scripts/DefaultFlow.tcl').Replace('\', '/')

if (!(Test-Path -LiteralPath $taskTdExe) -or !(Test-Path -LiteralPath $taskFlow)) {

    throw '请用 -TdHome 指定 TD 6.2.1 安装目录。'

}

$taskBuildStart = Get-Date

# The .al is the GUI source of truth. Reapply its fixed routing profile to
# generated run settings, which TD may replace when the user resets a run.
$taskProjectText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'td_project/wb_ui_dsi.al') -Raw -Encoding UTF8
# TD's XML-like format contains literal P&R attribute values and :: tag names.
$taskPhyRun = [regex]::Match($taskProjectText, '(?s)<Run\b[^>]*Name="phy_1"[^>]*>.*?</Run>').Value
$taskPlaceProfile = [regex]::Match($taskPhyRun, '(?s)<PlaceProperty>(.*?)</PlaceProperty>').Groups[1].Value
$taskRouteProfile = [regex]::Match($taskPhyRun, '(?s)<RouteProperty>(.*?)</RouteProperty>').Groups[1].Value
if ($taskPlaceProfile -notmatch '<seed>\s*1\s*</seed>' -or
    $taskRouteProfile -notmatch '<effort>\s*normal\s*</effort>') {
    throw '工程布线策略不匹配：请使用修复版 .al（seed=1，route effort=normal）。'
}
$taskPhySettings = Join-Path $PSScriptRoot 'td_project/wb_ui_dsi_Runs/phy_1/settings.cfg'
$taskSettingsText = Get-Content -LiteralPath $taskPhySettings -Raw
$taskSettingsText = [regex]::Replace($taskSettingsText, '(?m)^set phyWildParams[^\r\n]*\r?\n?', '')
$taskSettingsText = [regex]::Replace($taskSettingsText, '(?m)^set end_step[^\r\n]*\r?\n?', '')
$taskSettingsText += "`nset end_step opt_route`nset phyWildParams {place seed 1 route effort normal}`n"
[IO.File]::WriteAllText($taskPhySettings, $taskSettingsText, [Text.Encoding]::ASCII)

foreach ($taskRun in @('syn_1', 'phy_1')) {

    $taskRunDir = Join-Path $PSScriptRoot "td_project/${taskProjectName}_Runs/$taskRun"

    $taskExtra = ''

    if ($taskRun -eq 'phy_1') {

        $taskExtra = "source ../../../tools/finalize_timing.tcl`nset_param bitgen compress off`nbitgen -bit ${taskProjectName}.bit`nset_param bitgen compress on`nbitgen -bit ${taskProjectName}.bit"

    }

    @"

if {[catch {

    source {$taskFlow}

$taskExtra

} taskError]} {

    puts stderr `$taskError

    exit 1

}

exit

"@ | Set-Content -LiteralPath (Join-Path $taskRunDir 'build.tcl') -Encoding ascii

    Push-Location -LiteralPath $taskRunDir

    try {

        # Windows PowerShell 5 treats any native stderr text as an ErrorRecord.
        # Capture it, then decide success from the process exit and TD report.
        $ErrorActionPreference = 'Continue'
        & $taskTdExe 'build.tcl' *> 'build_console.txt'
        $taskNativeExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        if ($taskNativeExit -ne 0) { throw "TD 构建失败：$taskRun" }

        if (Select-String -LiteralPath 'build_console.txt' -Pattern '\bERROR[: ]' -Quiet) {

            throw "TD 报告错误：$taskRun，请查看 build_console.txt。"

        }

    } finally { Pop-Location }

}

$taskPhysical = Join-Path $PSScriptRoot "td_project/${taskProjectName}_Runs/phy_1"

$taskTiming = Join-Path $taskPhysical "${taskProjectName}_pr.timing"

$taskTimingText = Get-Content -LiteralPath $taskTiming -Raw

$taskPhysicalConsole = Get-Content -LiteralPath (Join-Path $taskPhysical 'build_console.txt') -Raw
$taskFinalRoute = [regex]::Matches($taskPhysicalConsole, 'over cnt = (\d+).*?over = (\d+), worst = (\d+), crit = (\d+)')
$taskOpenNets = [regex]::Matches($taskPhysicalConsole, 'eco open net = (\d+)')
if ($taskTimingText -notmatch 'Confidence\s*:\s*Routed' -or
    $taskPhysicalConsole -notmatch 'PASS FINAL_TIMING' -or
    $taskFinalRoute.Count -eq 0 -or $taskOpenNets.Count -eq 0) {
    throw '缺少本次完整布线和最终时序通过记录，停止复制镜像。'
}
foreach ($taskCounter in 1..4) {
    if ([int]$taskFinalRoute[$taskFinalRoute.Count - 1].Groups[$taskCounter].Value -ne 0) {
        throw '最终布线仍有冲突，停止复制镜像。'
    }
}
if ([int]$taskOpenNets[$taskOpenNets.Count - 1].Groups[1].Value -ne 0) {
    throw '最终布线仍有开路，停止复制镜像。'
}

$taskSetup = [regex]::Match($taskTimingText, 'SWNS:\s*(-?[0-9.]+)ns')

$taskHold = [regex]::Match($taskTimingText, 'HWNS:\s*(-?[0-9.]+)ns')

$taskPeriod = [regex]::Match($taskTimingText, 'Period Check WNS:\s*(-?[0-9.]+)ns')

if (!$taskSetup.Success -or !$taskHold.Success -or !$taskPeriod.Success) { throw '无法读取最终建立、保持及周期检查结论。' }

if ([double]$taskSetup.Groups[1].Value -lt 0 -or
    [double]$taskHold.Groups[1].Value -lt 0 -or
    [double]$taskPeriod.Groups[1].Value -lt 0) {

    throw '本次构建仍有时序违例。镜像保留在 phy_1，未复制为可上板调试镜像。'

}

$taskArea = Join-Path $taskPhysical "${taskProjectName}_phy.area"
$taskAreaText = Get-Content -LiteralPath $taskArea -Raw
$taskResources = [regex]::Matches($taskAreaText, '(?m)^#(?:lut6|slice|eram|dsp)\s+(\d+)\s+out of\s+(\d+)')
if ($taskResources.Count -ne 4) { throw '无法读取最终资源报告，停止交付镜像。' }
foreach ($taskResource in $taskResources) {
    if ([int]$taskResource.Groups[1].Value -gt [int]$taskResource.Groups[2].Value) {
        throw "资源超过器件上限：$($taskResource.Value)"
    }
}

foreach ($taskSuffix in @('', '_compress')) {

    $taskSource = Join-Path $taskPhysical "${taskProjectName}${taskSuffix}.bit"

    if (!(Test-Path -LiteralPath $taskSource) -or
        (Get-Item -LiteralPath $taskSource).LastWriteTime -lt $taskBuildStart -or
        (Get-Item -LiteralPath $taskSource).Length -le 100000) {

        throw '没有本次构建的完整新镜像（文件须大于 100000 字节），停止复制。'

    }

    Copy-Item -LiteralPath $taskSource -Destination (Join-Path $PSScriptRoot "DSI_ISP_RGB_INTEGRATED_SC500_7inch${taskSuffix}.bit") -Force

}

Write-Host '综合、布局布线及最终时序检查完成；ISP + RGB 整合版新镜像已复制到工程根目录。尚需实际开发板验证。'

Write-Host '重新构建后请以本次 TD 报告为准。'

