# gaokao-zhiyuan-advisor industry trend dictionary generator
#
# Creates a pipeline-compatible extracted/industry_trends-YYYY-MM.csv file.
# The generator is intentionally conservative: it only emits keyword rows whose
# aliases appear in the current data pack's plan/admission text.

param(
    [string]$PackRoot = "",
    [int]$Year = 0,
    [string]$Province = "",
    [string]$Category = "",
    [string]$Batch = "",
    [string]$OutputPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Utf8BomText([string]$Path, [string[]]$Lines) {
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $enc = New-Object System.Text.UTF8Encoding($true)
    $sw = New-Object System.IO.StreamWriter($Path, $false, $enc)
    foreach ($line in $Lines) { $sw.WriteLine($line) }
    $sw.Close()
}

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if (-not $text.Trim()) { return $null }
    return $text | ConvertFrom-Json
}

function Import-DataCsv([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    return @(Import-Csv -LiteralPath $Path -Encoding UTF8)
}

function Get-RowValue($Row, [string[]]$Aliases) {
    foreach ($alias in $Aliases) {
        $prop = $Row.PSObject.Properties | Where-Object { $_.Name -ieq $alias } | Select-Object -First 1
        if ($prop -and $null -ne $prop.Value) {
            $value = [string]$prop.Value
            if ($value.Trim() -ne "") { return $value.Trim() }
        }
    }
    return ""
}

function Test-TextMatch([string]$Value, [string]$Target) {
    if (-not $Target -or $Target.Trim() -eq "") { return $true }
    if (-not $Value -or $Value.Trim() -eq "") { return $true }
    $v = $Value.Trim()
    $t = $Target.Trim()
    return ($v -eq $t -or $v.Contains($t) -or $t.Contains($v))
}

function Find-PackRoot([string]$ExplicitRoot) {
    if ($ExplicitRoot -and $ExplicitRoot.Trim() -ne "") {
        return (Resolve-Path -LiteralPath $ExplicitRoot).Path
    }
    $candidate = (Get-Location).Path
    if ((Test-Path (Join-Path $candidate "manifest.json")) -or (Test-Path (Join-Path $candidate "extracted"))) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
    throw "Cannot auto-detect PackRoot. Specify -PackRoot."
}

function Find-DataCsv([string]$Root, [string]$ClassName) {
    $searchDirs = @()
    foreach ($relative in @("extracted", "normalized")) {
        $dir = Join-Path $Root $relative
        if (Test-Path $dir) { $searchDirs += $dir }
    }
    $patterns = switch ($ClassName) {
        "plans" { @("*plans*.csv", "*plan*.csv", "*admission-plan*.csv", "*招生计划*.csv") }
        "admission_lines" { @("*admission_lines*.csv", "*admission-lines*.csv", "*admission*.cleaned.csv", "*admission*.csv", "*投档线*.csv", "*录取*.csv") }
        default { @("*$ClassName*.csv") }
    }
    foreach ($dir in $searchDirs) {
        foreach ($pattern in $patterns) {
            $match = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) { return $match.FullName }
        }
    }
    return ""
}

function Find-ExistingTrendFile([string]$Root) {
    foreach ($relative in @("", "extracted", "normalized", "raw", "raw\industry-trends", "raw\trends", "references")) {
        $dir = if ($relative) { Join-Path $Root $relative } else { $Root }
        if (-not (Test-Path $dir)) { continue }
        foreach ($pattern in @("*industry_trends*.csv", "*industry-trends*.csv", "*trends*.csv", "*行业趋势*.csv", "*trends*.md", "*行业趋势*.md")) {
            $match = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) { return $match.FullName }
        }
    }
    return ""
}

function ConvertTo-CsvCell([string]$Value) {
    if ($null -eq $Value) { $Value = "" }
    return '"' + ([string]$Value).Replace('"', '""') + '"'
}

$PackRoot = Find-PackRoot $PackRoot
$manifestPath = Join-Path $PackRoot "manifest.json"
$manifest = Read-JsonFile $manifestPath

if ($manifest) {
    if (-not $Province -and $manifest.province) { $Province = [string]$manifest.province }
    if ($Year -eq 0 -and $manifest.year) { $Year = [int]$manifest.year }
    if (-not $Category -and $manifest.category) { $Category = [string]$manifest.category }
    if (-not $Batch -and $manifest.batch) { $Batch = [string]$manifest.batch }
}

if (-not $Force) {
    $existing = Find-ExistingTrendFile $PackRoot
    if ($existing) {
        Write-Host "Industry trends file already exists: $existing"
        return
    }
}

$monthStamp = Get-Date -Format "yyyy-MM"
$checkedDate = Get-Date -Format "yyyy-MM-dd"
if (-not $OutputPath -or $OutputPath.Trim() -eq "") {
    $OutputPath = Join-Path (Join-Path $PackRoot "extracted") ("industry_trends-$monthStamp.csv")
}

$plansFile = Find-DataCsv $PackRoot "plans"
$admissionFile = Find-DataCsv $PackRoot "admission_lines"
$sourceFile = if ($plansFile) { $plansFile } else { $admissionFile }
if (-not $sourceFile) {
    throw "No plans/admission_lines CSV found; cannot infer trend keywords from the data pack."
}

$rows = Import-DataCsv $sourceFile
$corpusParts = New-Object System.Collections.Generic.List[string]
foreach ($row in $rows) {
    $rowProvince = Get-RowValue $row @("province", "省份")
    $rowCategory = Get-RowValue $row @("category", "科类", "选科")
    $rowBatch = Get-RowValue $row @("batch", "批次")
    if (-not (Test-TextMatch $rowProvince $Province)) { continue }
    if (-not (Test-TextMatch $rowCategory $Category)) { continue }
    if (-not (Test-TextMatch $rowBatch $Batch)) { continue }

    foreach ($value in @(
        (Get-RowValue $row @("major_name", "专业名称", "group_name", "专业组名称", "院校专业组名称")),
        (Get-RowValue $row @("school_group_clean", "school_group_raw", "专业组", "院校专业组")),
        (Get-RowValue $row @("remarks", "备注", "说明"))
    )) {
        if ($value) { [void]$corpusParts.Add($value) }
    }
}

$corpus = (($corpusParts | Select-Object -Unique) -join " ")
$corpusCompact = ($corpus -replace "\s+", "")

$trendSeeds = @(
    [pscustomobject]@{ keyword="人工智能/智能科学与技术/机器人工程/数据科学/大数据/软件工程/计算机/网络空间安全/信息安全"; trend="升"; reason="AI、数字化和安全需求仍强，但需关注学校平台、数学基础和实践能力" },
    [pscustomobject]@{ keyword="电子信息/集成电路/微电子/通信工程/光电信息/自动化"; trend="升"; reason="国产替代、智能制造和新型基础设施带动需求，头部院校优势更明显" },
    [pscustomobject]@{ keyword="电气工程/新能源/储能/智能电网/能源与动力"; trend="升"; reason="新能源、电网升级和储能方向景气度较高，需核对具体专业方向" },
    [pscustomobject]@{ keyword="临床医学/口腔医学/医学影像/麻醉学/护理学"; trend="稳"; reason="医疗需求长期存在，培养周期长且准入要求高，需结合院校层次和城市" },
    [pscustomobject]@{ keyword="药学/制药工程/生物医药/生物技术"; trend="稳"; reason="医药健康方向长期需求稳定，但岗位分化明显，继续深造价值较高" },
    [pscustomobject]@{ keyword="数学/统计学/应用统计/金融科技"; trend="稳"; reason="数理基础适配数据、金融和AI相关方向，发展依赖个人能力和深造路径" },
    [pscustomobject]@{ keyword="会计学/审计学/财务管理/法学"; trend="稳"; reason="职业通道清晰但竞争充分，更依赖学校层次、证书和实习经历" },
    [pscustomobject]@{ keyword="机械设计/机械工程/车辆工程/智能制造/航空航天"; trend="稳"; reason="制造业升级支撑需求，方向选择和工程实践能力影响较大" },
    [pscustomobject]@{ keyword="材料科学/材料工程/化学工程/环境工程"; trend="中性"; reason="行业分化较强，需重点看学校平台、科研方向和升学/就业城市" },
    [pscustomobject]@{ keyword="土木工程/建筑学/城乡规划/房地产"; trend="降"; reason="地产链条承压，传统岗位收缩，需谨慎核对细分方向和转型空间" },
    [pscustomobject]@{ keyword="工商管理/市场营销/旅游管理/酒店管理"; trend="中性"; reason="通用管理类供给较多，优势更多来自学校平台、城市和复合能力" },
    [pscustomobject]@{ keyword="新闻传播/广播电视/广告学/网络与新媒体"; trend="中性"; reason="内容行业变化快，实践作品、平台资源和复合技能更关键" },
    [pscustomobject]@{ keyword="师范/教育学/汉语言文学/英语"; trend="稳"; reason="教育和语言类需求相对稳定，但编制和地区竞争需提前评估" },
    [pscustomobject]@{ keyword="农学/林学/食品科学/动物医学"; trend="稳"; reason="民生和农业科技方向有长期需求，需结合兴趣、地域和深造意愿" }
)

$selected = New-Object System.Collections.Generic.List[object]
foreach ($seed in $trendSeeds) {
    $aliases = @($seed.keyword -split "[/／、,，;；|]")
    $hit = $false
    foreach ($alias in $aliases) {
        $key = $alias.Trim()
        if ($key.Length -ge 2 -and $corpusCompact.Contains($key)) {
            $hit = $true
            break
        }
    }
    if ($hit) { [void]$selected.Add($seed) }
}

$sourceId = "auto-generated from data-pack keywords; source=$([System.IO.Path]::GetFileName($sourceFile))"
$csv = New-Object System.Collections.Generic.List[string]
[void]$csv.Add("keyword,trend,reason,checked_date,source_id")
foreach ($entry in $selected | Sort-Object keyword -Unique) {
    [void]$csv.Add(@(
        (ConvertTo-CsvCell $entry.keyword),
        (ConvertTo-CsvCell $entry.trend),
        (ConvertTo-CsvCell $entry.reason),
        (ConvertTo-CsvCell $checkedDate),
        (ConvertTo-CsvCell $sourceId)
    ) -join ",")
}

Write-Utf8BomText $OutputPath $csv
Write-Host "Generated industry trends dictionary: $OutputPath"
Write-Host "Trend rows: $($selected.Count)"
