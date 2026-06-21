# gaokao-zhiyuan-advisor pipeline v4 - generic cleaned data-pack pipeline
#
# Reads the generic data-pack layout documented in references/data-pack-standard.md:
#   manifest.json
#   extracted/score_rank*.csv or normalized/score_rank*.csv
#   extracted/plans*.csv or normalized/plans*.csv
#   extracted/admission_lines*.csv or normalized/admission_lines*.csv
#   extracted/charters*.csv or normalized/charters*.csv
#
# The pipeline no longer hard-codes a province, year, category, or filename.

param(
    [Parameter(Mandatory=$false)]
    [int]$CandidateScore = 0,
    [int]$CandidateRank = 0,
    [int]$ScoreWindow = 15,
    [int]$PerTierDraft = 12,
    [string[]]$AllowedReselect = @(),
    [string[]]$AllowedSubjects = @(),
    [string[]]$CitiesAllowed = @(),
    [string]$SinoForeignMode = "include", # include|exclude|only
    [int]$MaxPerSchool = 3,
    [int]$TotalSlots = 0,
    [string]$Province = "",
    [int]$Year = 0,
    [string]$Category = "",
    [string]$Batch = "",
    [string]$PackRoot = "",
    [string]$ScoreRankPath = "",
    [string]$PlansPath = "",
    [string]$AdmissionLinesPath = "",
    [string]$ChartersPath = "",
    [string]$IndustryTrendsPath = "",
    [switch]$HistoricalScreeningOnly,
    [switch]$AllowPreliminary,
    [switch]$NoAutoIndustryTrends
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
    if (-not (Test-Path $Path)) {
        throw "CSV not found: $Path"
    }
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

function Convert-ToIntOrNull($Value) {
    if ($null -eq $Value) { return $null }
    $text = ([string]$Value).Trim()
    if ($text -eq "") { return $null }
    $text = $text -replace ",", ""
    $text = $text -replace "，", ""
    $text = $text -replace "\s", ""
    $m = [regex]::Match($text, "-?\d+")
    if (-not $m.Success) { return $null }
    $n = 0
    if ([int]::TryParse($m.Value, [ref]$n)) { return $n }
    return $null
}

function Get-YearFromText([string]$Text) {
    if (-not $Text) { return $null }
    $m = [regex]::Match($Text, "(20\d{2})")
    if (-not $m.Success) { return $null }
    $yearValue = 0
    if ([int]::TryParse($m.Groups[1].Value, [ref]$yearValue)) { return $yearValue }
    return $null
}

function Test-TextMatch([string]$Value, [string]$Target) {
    if (-not $Target -or $Target.Trim() -eq "") { return $true }
    if (-not $Value -or $Value.Trim() -eq "") { return $true }
    $v = $Value.Trim()
    $t = $Target.Trim()
    return ($v -eq $t -or $v.Contains($t) -or $t.Contains($v))
}

function Escape-Md([string]$Text) {
    if ($null -eq $Text) { return "" }
    return ([string]$Text).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ").Trim()
}

function New-Slug([string]$Text) {
    if (-not $Text) { return "unknown" }
    $slug = $Text.ToLowerInvariant() -replace "\s+", "-"
    $slug = $slug -replace "[^a-z0-9\-\u4e00-\u9fff]", ""
    if (-not $slug) { return "unknown" }
    return $slug
}

function Find-PackRoot([string]$ExplicitRoot) {
    if ($ExplicitRoot -and $ExplicitRoot.Trim() -ne "") {
        return (Resolve-Path -LiteralPath $ExplicitRoot).Path
    }
    $candidates = New-Object System.Collections.Generic.List[string]
    [void]$candidates.Add((Get-Location).Path)
    if ($PSScriptRoot) {
        [void]$candidates.Add($PSScriptRoot)
        $p = Split-Path $PSScriptRoot -Parent
        if ($p) { [void]$candidates.Add($p) }
        $pp = Split-Path $p -Parent
        if ($pp) { [void]$candidates.Add($pp) }
    }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not $candidate) { continue }
        if ((Test-Path (Join-Path $candidate "manifest.json")) -or (Test-Path (Join-Path $candidate "extracted")) -or (Test-Path (Join-Path $candidate "normalized"))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Cannot auto-detect PackRoot. Specify -PackRoot pointing to a data pack folder containing manifest.json plus extracted/ or normalized/."
}

function Find-DataCsv([string]$Root, [string]$ClassName, [string]$ExplicitPath) {
    if ($ExplicitPath -and $ExplicitPath.Trim() -ne "") {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $searchDirs = @()
    $extracted = Join-Path $Root "extracted"
    $normalized = Join-Path $Root "normalized"
    if (Test-Path $extracted) { $searchDirs += $extracted }
    if (Test-Path $normalized) { $searchDirs += $normalized }
    if ($searchDirs.Count -eq 0) { throw "Neither extracted/ nor normalized/ folder found under PackRoot: $Root" }
    $patterns = switch ($ClassName) {
        "score_rank" { @("*score_rank*.csv", "*score-rank*.csv", "*scorerank*.csv", "*一分一段*.csv", "*逐分段*.csv") }
        "plans" { @("*plans*.csv", "*plan*.csv", "*admission-plan*.csv", "*招生计划*.csv") }
        "admission_lines" { @("*admission_lines*.csv", "*admission-lines*.csv", "*admission*.cleaned.csv", "*admission*.csv", "*投档线*.csv", "*录取*.csv") }
        "charters" { @("*charters*.csv", "*charter*.csv", "*restrictions*.csv", "*章程*.csv", "*限制*.csv") }
        default { @("*$ClassName*.csv") }
    }
    foreach ($dir in $searchDirs) {
        foreach ($pattern in $patterns) {
            $match = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter $pattern | Select-Object -First 1
            if ($match) { return $match.FullName }
        }
    }
    return ""
}

function Find-OptionalDataFile([string]$Root, [string]$ExplicitPath, [string[]]$Patterns) {
    if ($ExplicitPath -and $ExplicitPath.Trim() -ne "") {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $searchDirs = New-Object System.Collections.Generic.List[string]
    foreach ($relative in @("", "extracted", "normalized", "raw", "raw\industry-trends", "raw\trends", "references")) {
        $dir = if ($relative) { Join-Path $Root $relative } else { $Root }
        if (Test-Path $dir) { [void]$searchDirs.Add($dir) }
    }
    foreach ($dir in $searchDirs | Select-Object -Unique) {
        foreach ($pattern in $Patterns) {
            $match = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) { return $match.FullName }
        }
    }
    return ""
}

function Normalize-TrendLevel([string]$Trend) {
    if (-not $Trend) { return "" }
    $value = $Trend.Trim()
    if ($value -in @("升", "稳", "降", "中性")) { return $value }
    if ($value -match "上升|高景气|向上") { return "升" }
    if ($value -match "稳定|稳健") { return "稳" }
    if ($value -match "下降|谨慎|承压") { return "降" }
    return $value
}

function Remove-KeywordQualifier([string]$Text) {
    if (-not $Text) { return "" }
    $value = $Text.Trim()
    $value = $value -replace "（[^）]*）", ""
    $value = $value -replace "\([^)]*\)", ""
    $value = $value -replace "\s+", ""
    return $value.Trim()
}

function Add-TrendEntry($Entries, [string]$Keyword, [string]$Trend, [string]$Reason) {
    if (-not $Keyword -or -not $Trend) { return }
    $keywordText = $Keyword.Trim()
    $matchKey = Remove-KeywordQualifier $keywordText
    if (-not $matchKey -or $matchKey.Length -lt 2) { return }
    $matchKeys = New-Object System.Collections.Generic.List[string]
    [void]$matchKeys.Add($matchKey)
    foreach ($alias in @("计算机", "电气", "能源", "新能源", "土木", "建筑", "临床医学", "口腔医学", "电子信息", "通信", "自动化", "机器人", "人工智能", "软件工程", "会计", "审计", "机械", "数学", "统计", "材料", "药学", "制药")) {
        if ($matchKey.Contains($alias)) { [void]$matchKeys.Add($alias) }
    }
    foreach ($key in $matchKeys | Select-Object -Unique) {
        if (-not $key -or $key.Length -lt 2) { continue }
        [void]$Entries.Add([pscustomobject]@{
            keyword=$keywordText
            match_key=$key
            trend=(Normalize-TrendLevel $Trend)
            reason=([string]$Reason).Trim()
        })
    }
}

function Import-IndustryTrends([string]$Path) {
    $entries = New-Object System.Collections.Generic.List[object]
    if (-not $Path -or -not (Test-Path $Path)) { return @() }
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -eq ".csv") {
        $rows = Import-DataCsv $Path
        foreach ($row in $rows) {
            $keywordText = Get-RowValue $row @("keyword", "keywords", "key", "关键词", "词条")
            $trend = Get-RowValue $row @("trend", "level", "趋势", "分级", "趋势分级")
            $reason = Get-RowValue $row @("reason", "note", "notes", "理由", "一句话理由", "说明")
            foreach ($keyword in ($keywordText -split "[/／、,，;；|]")) {
                Add-TrendEntry $entries $keyword $trend $reason
            }
        }
    } else {
        $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
        foreach ($line in $lines) {
            $m = [regex]::Match($line, "^\s*-\s*(.+?)\s*(?:→|->|=>)\s*([^：:]+)\s*[：:]\s*(.+?)\s*$")
            if (-not $m.Success) { continue }
            $keywordText = $m.Groups[1].Value
            $trend = $m.Groups[2].Value
            $reason = $m.Groups[3].Value
            foreach ($keyword in ($keywordText -split "[/／、,，;；|]")) {
                Add-TrendEntry $entries $keyword $trend $reason
            }
        }
    }
    return @($entries | Sort-Object @{Expression={ $_.match_key.Length }; Descending=$true}, keyword -Unique)
}

function Get-IndustryTrendForPlan($Plan, $TrendEntries) {
    if (-not $TrendEntries -or $TrendEntries.Count -eq 0) {
        return [pscustomobject]@{ trend=""; keyword=""; reason="" }
    }
    $text = "$($Plan.school_name) $($Plan.major_name) $($Plan.remarks)"
    $text = $text -replace "[\(（][^\)）]*(不限|化学|生物|思想政治|政治|地理|物理|历史|技术)[^\)）]*[\)）]", ""
    $compact = ($text -replace "\s+", "").ToLowerInvariant()
    foreach ($entry in $TrendEntries) {
        $matchKey = ([string]$entry.match_key).ToLowerInvariant()
        if ($matchKey -and $compact.Contains($matchKey)) {
            return [pscustomobject]@{
                trend=$entry.trend
                keyword=$entry.keyword
                reason=$entry.reason
            }
        }
    }
    return [pscustomobject]@{
        trend="中性"
        keyword=""
        reason="词典未覆盖，需结合组内专业再判断"
    }
}

function Test-SubjectEligible([string]$Requirement, [string[]]$Subjects, [string]$CategoryText) {
    if (-not $Requirement -or $Requirement.Trim() -eq "") { return $true }
    $req = $Requirement -replace "\s", ""
    if ($req -match "不限|不提科目要求|无选考科目要求") { return $true }
    if (-not $Subjects -or $Subjects.Count -eq 0) { return $true }
    $known = @("物理", "历史", "化学", "生物", "思想政治", "政治", "地理", "技术")
    foreach ($s in $known) {
        if ($req.Contains($s)) {
            $coveredByCategory = ($CategoryText -and $CategoryText.Contains($s))
            $coveredBySubjects = $false
            foreach ($chosen in $Subjects) {
                if ($chosen -and ($chosen.Contains($s) -or $s.Contains($chosen))) {
                    $coveredBySubjects = $true
                    break
                }
            }
            if (-not $coveredByCategory -and -not $coveredBySubjects) { return $false }
        }
    }
    return $true
}

function Get-Tier([int]$CandidateRankValue, [double]$WorstMargin, [int]$EvidenceYears) {
    $edge = [Math]::Max(3000, [int]($CandidateRankValue * 0.04))
    $stable = [Math]::Max(12000, [int]($CandidateRankValue * 0.15))
    $safe = [Math]::Max(30000, [int]($CandidateRankValue * 0.35))

    if ($WorstMargin -lt (-1 * $edge)) { return "冲" }
    if ($WorstMargin -lt $edge) { return "冲稳边界" }
    if ($WorstMargin -lt $stable) { return "稳" }
    if ($WorstMargin -lt $safe) { return "保" }
    return "垫"
}

function Add-AdmissionKey($Map, [string]$Key, $Row) {
    if (-not $Key -or $Key.Trim() -eq "") { return }
    if (-not $Map.ContainsKey($Key)) {
        $Map[$Key] = New-Object System.Collections.Generic.List[object]
    }
    [void]$Map[$Key].Add($Row)
}

function Build-Keys([string]$SchoolCode, [string]$SchoolName, [string]$GroupCode, [string]$MajorCode, [string]$MajorName) {
    $keys = @()
    if ($SchoolCode -and $GroupCode -and $MajorCode) { $keys += "scgm|$SchoolCode|$GroupCode|$MajorCode" }
    if ($SchoolCode -and $GroupCode) { $keys += "scg|$SchoolCode|$GroupCode" }
    if ($SchoolCode -and $MajorCode) { $keys += "scm|$SchoolCode|$MajorCode" }
    if ($SchoolName -and $GroupCode -and $MajorCode) { $keys += "sngm|$SchoolName|$GroupCode|$MajorCode" }
    if ($SchoolName -and $GroupCode) { $keys += "sng|$SchoolName|$GroupCode" }
    if ($SchoolName -and $MajorName) { $keys += "snmn|$SchoolName|$MajorName" }
    if ($SchoolCode) { $keys += "sc|$SchoolCode" }
    if ($SchoolName) { $keys += "sn|$SchoolName" }
    return [string[]]$keys
}

function Split-SchoolGroupText([string]$Text) {
    $result = [pscustomobject]@{ school_name=""; group_code=""; group_name="" }
    if (-not $Text) { return $result }
    $value = $Text.Trim()
    $result.group_name = $value
    $m = [regex]::Match($value, "^(?<school>.+?)(?<group>\d{2,3})\s*专业组")
    if ($m.Success) {
        $result.school_name = $m.Groups["school"].Value.Trim()
        $result.group_code = $m.Groups["group"].Value.Trim()
    }
    return $result
}

function Get-SubjectRequirementFromGroupText([string]$Text) {
    if (-not $Text) { return "" }
    if ($Text -match "不限") { return "不限" }
    $subjects = New-Object System.Collections.Generic.List[string]
    foreach ($s in @("物理", "历史", "化学", "生物", "思想政治", "政治", "地理", "技术")) {
        if ($Text.Contains($s)) { [void]$subjects.Add($s) }
    }
    return (($subjects | Select-Object -Unique) -join "+")
}

$PackRoot = Find-PackRoot $PackRoot
$manifestPath = Join-Path $PackRoot "manifest.json"
$manifest = Read-JsonFile $manifestPath
$warnings = New-Object System.Collections.Generic.List[string]

if ($manifest) {
    if (-not $Province -and $manifest.province) { $Province = [string]$manifest.province }
    if ($Year -eq 0 -and $manifest.year) { $Year = [int]$manifest.year }
    if (-not $Category -and $manifest.category) { $Category = [string]$manifest.category }
    if (-not $Batch -and $manifest.batch) { $Batch = [string]$manifest.batch }
    if ($TotalSlots -eq 0 -and $manifest.total_slots) { $TotalSlots = [int]$manifest.total_slots }
} else {
    [void]$warnings.Add("manifest.json not found; running from cleaned CSV files only. Formal readiness cannot be proven.")
}

if ($TotalSlots -le 0) { $TotalSlots = 40 }

$subjects = New-Object System.Collections.Generic.List[string]
foreach ($s in $AllowedSubjects) { if ($s -and $s.Trim() -ne "") { [void]$subjects.Add($s.Trim()) } }
foreach ($s in $AllowedReselect) { if ($s -and $s.Trim() -ne "") { [void]$subjects.Add($s.Trim()) } }
$CandidateSubjects = @($subjects | Select-Object -Unique)

if ($manifest -and $manifest.readiness) {
    $required = if ($HistoricalScreeningOnly) {
        @("policy", "score_rank", "control_lines", "admission_lines")
    } else {
        @("policy", "score_rank", "control_lines", "plans", "admission_lines", "charters")
    }
    $notReady = New-Object System.Collections.Generic.List[string]
    foreach ($r in $required) {
        $prop = $manifest.readiness.PSObject.Properties | Where-Object { $_.Name -ieq $r } | Select-Object -First 1
        $status = ""
        if ($prop) { $status = [string]$prop.Value }
        if ($status -notin @("confirmed", "not applicable")) {
            [void]$notReady.Add("$r=$status")
        }
    }
    if ($notReady.Count -gt 0) {
        $msg = "Data-pack readiness gate is not fully confirmed: " + ($notReady -join "; ")
        if (-not $AllowPreliminary) {
            throw "$msg. Re-run with -AllowPreliminary only for a clearly labeled draft."
        }
        [void]$warnings.Add($msg + " Output is preliminary.")
    }
}

$scoreRankFile = Find-DataCsv $PackRoot "score_rank" $ScoreRankPath
$plansFile = Find-DataCsv $PackRoot "plans" $PlansPath
$admissionFile = Find-DataCsv $PackRoot "admission_lines" $AdmissionLinesPath
$chartersFile = Find-DataCsv $PackRoot "charters" $ChartersPath
$industryTrendPatterns = @("*industry_trends*.csv", "*industry-trends*.csv", "*trends*.csv", "*行业趋势*.csv", "*trends*.md", "*行业趋势*.md")
$industryTrendsFile = Find-OptionalDataFile $PackRoot $IndustryTrendsPath $industryTrendPatterns

if (-not $industryTrendsFile -and -not $NoAutoIndustryTrends -and -not $IndustryTrendsPath) {
    $generatorPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "generate-industry-trends.ps1" } else { "" }
    if ($generatorPath -and (Test-Path $generatorPath)) {
        try {
            $trendArgs = @{
                PackRoot = $PackRoot
                Province = $Province
                Year = $Year
                Category = $Category
                Batch = $Batch
            }
            & $generatorPath @trendArgs | Out-Null
            $industryTrendsFile = Find-OptionalDataFile $PackRoot "" $industryTrendPatterns
            if ($industryTrendsFile) {
                [void]$warnings.Add("Generated industry trends dictionary from data-pack keywords: $industryTrendsFile")
            }
        } catch {
            [void]$warnings.Add("Industry trends auto-generation skipped: $($_.Exception.Message)")
        }
    }
}

if (-not $scoreRankFile) { [void]$warnings.Add("No score_rank CSV found in extracted/ or normalized/.") }
if (-not $plansFile) {
    if ($HistoricalScreeningOnly) {
        [void]$warnings.Add("No current-year plans CSV found; running historical admission-line screening only. Current-year招生计划、计划人数、组内专业 must be checked in the official plan book/system.")
    } else {
        throw "No plans CSV found in extracted/ or normalized/. Cannot produce advising table. Use -HistoricalScreeningOnly only for a clearly labeled historical screening draft."
    }
}
if (-not $admissionFile) { throw "No admission_lines CSV found in extracted/ or normalized/. Cannot produce rank-based risk tiers." }
if (-not $chartersFile) {
    $msg = "No charters/restrictions CSV found in extracted/ or normalized/; final school restrictions must be verified manually."
    if (-not $AllowPreliminary -and -not $HistoricalScreeningOnly) {
        throw "$msg Re-run with -AllowPreliminary only for a clearly labeled draft."
    }
    [void]$warnings.Add($msg)
}
if (-not $industryTrendsFile) {
    [void]$warnings.Add("No industry trends dictionary found; industry_trend fields will be left neutral.")
}

$scoreRows = @()
if ($scoreRankFile) { $scoreRows = Import-DataCsv $scoreRankFile }
$planRowsRaw = @()
if ($plansFile) { $planRowsRaw = Import-DataCsv $plansFile }
$admissionRowsRaw = Import-DataCsv $admissionFile
$charterRowsRaw = @()
if ($chartersFile) { $charterRowsRaw = Import-DataCsv $chartersFile }
$industryTrendEntries = Import-IndustryTrends $industryTrendsFile
if ($industryTrendsFile -and (-not $industryTrendEntries -or $industryTrendEntries.Count -eq 0)) {
    [void]$warnings.Add("Industry trends file found but contains no usable keyword rows; industry_trend fields will be left neutral.")
}

$scoreBands = @()
if ($scoreRows.Count -gt 0) {
    $scoreBands = @(foreach ($row in $scoreRows) {
        $score = Convert-ToIntOrNull (Get-RowValue $row @("score", "score_band", "分数", "分数段"))
        $rank = Convert-ToIntOrNull (Get-RowValue $row @("cumulative_rank", "cumulative_count", "rank", "累计人数", "累计"))
        if ($null -ne $score -and $null -ne $rank) {
            [pscustomobject]@{ score=$score; rank=$rank }
        }
    })
}

function Resolve-RankFromScore([int]$Score, $ScoreBands) {
    if ($Score -le 0 -or -not $ScoreBands -or $ScoreBands.Count -eq 0) { return $null }
    $exact = $ScoreBands | Where-Object { $_.score -eq $Score } | Select-Object -First 1
    if ($exact) { return [int]$exact.rank }
    $nearest = $ScoreBands | Where-Object { $_.score -le $Score } | Sort-Object score -Descending | Select-Object -First 1
    if ($nearest) { return [int]$nearest.rank }
    return $null
}

$resolvedRank = $CandidateRank
$resolvedScore = $CandidateScore
$resolvedFloorRank = $null

if ($resolvedRank -le 0 -and $CandidateScore -gt 0) {
    $exact = $scoreBands | Where-Object { $_.score -eq $CandidateScore } | Select-Object -First 1
    if ($exact) {
        $resolvedRank = [int]$exact.rank
        $resolvedScore = [int]$exact.score
    } else {
        $nearest = $scoreBands | Where-Object { $_.score -le $CandidateScore } | Sort-Object score -Descending | Select-Object -First 1
        if ($nearest) {
            $resolvedRank = [int]$nearest.rank
            $resolvedScore = [int]$nearest.score
            [void]$warnings.Add("Candidate score not found exactly in score_rank; used nearest lower score band $resolvedScore.")
        }
    }
}

if ($resolvedRank -le 0) {
    throw "Either CandidateRank must be > 0, or CandidateScore must be resolvable from score_rank."
}

if ($resolvedScore -le 0 -and $scoreRows.Count -gt 0) {
    $rankBand = $scoreBands | Sort-Object score -Descending | Where-Object { $_.rank -ge $resolvedRank } | Select-Object -First 1
    if ($rankBand) {
        $resolvedScore = [int]$rankBand.score
        $resolvedFloorRank = [int]$rankBand.rank
    }
}

$targetHistoricalYears = @()
if ($Year -gt 0) { $targetHistoricalYears = @(([int]$Year - 1), ([int]$Year - 2)) }

$plans = @()
if (-not $HistoricalScreeningOnly) {
    $plans = foreach ($row in $planRowsRaw) {
        $rowYear = Convert-ToIntOrNull (Get-RowValue $row @("year", "年份"))
        $rowProvince = Get-RowValue $row @("province", "省份")
        $rowCategory = Get-RowValue $row @("category", "科类", "选科")
        $rowBatch = Get-RowValue $row @("batch", "批次")
        if ($Year -gt 0 -and $rowYear -and $rowYear -ne $Year) { continue }
        if (-not (Test-TextMatch $rowProvince $Province)) { continue }
        if (-not (Test-TextMatch $rowCategory $Category)) { continue }
        if (-not (Test-TextMatch $rowBatch $Batch)) { continue }

        $schoolCode = Get-RowValue $row @("school_code", "院校代码", "学校代码")
        $schoolName = Get-RowValue $row @("school_name", "院校名称", "学校名称")
        $groupCode = Get-RowValue $row @("group_code", "专业组代码", "院校专业组代码")
        $majorCode = Get-RowValue $row @("major_code", "专业代码")
        $majorName = Get-RowValue $row @("major_name", "专业名称", "group_name", "专业组名称")
        $planCount = Convert-ToIntOrNull (Get-RowValue $row @("plan_count", "计划数", "招生人数"))
        $subjectReq = Get-RowValue $row @("subject_requirement", "选科要求", "科目要求", "再选科目要求")
        $city = Get-RowValue $row @("city", "城市", "所在地")
        $campus = Get-RowValue $row @("campus", "校区")
        $tuition = Get-RowValue $row @("tuition", "学费")
        $remarks = Get-RowValue $row @("remarks", "备注")
        $allText = "$schoolName $majorName $subjectReq $city $campus $tuition $remarks"

        if (-not (Test-SubjectEligible $subjectReq $CandidateSubjects $Category)) { continue }
        if ($CitiesAllowed -and $CitiesAllowed.Count -gt 0) {
            $okCity = $false
            foreach ($cityFilter in $CitiesAllowed) {
                if ($cityFilter -and $allText.Contains($cityFilter)) { $okCity = $true; break }
            }
            if (-not $okCity) { continue }
        }
        $isSino = ($allText -match "中外|合作办学|联合培养")
        if ($SinoForeignMode -eq "exclude" -and $isSino) { continue }
        if ($SinoForeignMode -eq "only" -and -not $isSino) { continue }

        [pscustomobject]@{
            raw=$row
            year=$rowYear
            province=$rowProvince
            category=$rowCategory
            batch=$rowBatch
            school_code=$schoolCode
            school_name=$schoolName
            group_code=$groupCode
            major_code=$majorCode
            major_name=$majorName
            plan_count=$planCount
            subject_requirement=$subjectReq
            city=$city
            campus=$campus
            tuition=$tuition
            remarks=$remarks
            is_sino=$isSino
        }
    }

    if (-not $plans -or @($plans).Count -eq 0) {
        throw "No current-year plan rows match the requested province/category/batch filters."
    }
}

$admissionMap = @{}
$admissionFileYear = Get-YearFromText ([System.IO.Path]::GetFileName($admissionFile))
$admissions = foreach ($row in $admissionRowsRaw) {
    $rowYear = Convert-ToIntOrNull (Get-RowValue $row @("year", "年份"))
    if ($null -eq $rowYear -and $admissionFileYear) { $rowYear = $admissionFileYear }
    $rowProvince = Get-RowValue $row @("province", "省份")
    $rowCategory = Get-RowValue $row @("category", "科类", "选科")
    $rowBatch = Get-RowValue $row @("batch", "批次")
    if ($targetHistoricalYears.Count -gt 0 -and $rowYear -and ($targetHistoricalYears -notcontains $rowYear)) { continue }
    if (-not (Test-TextMatch $rowProvince $Province)) { continue }
    if (-not (Test-TextMatch $rowCategory $Category)) { continue }
    if (-not (Test-TextMatch $rowBatch $Batch)) { continue }

    $schoolCode = Get-RowValue $row @("school_code", "院校代码", "学校代码")
    $schoolName = Get-RowValue $row @("school_name", "院校名称", "学校名称")
    $groupCode = Get-RowValue $row @("group_code", "专业组代码", "院校专业组代码")
    $majorCode = Get-RowValue $row @("major_code", "专业代码")
    $majorName = Get-RowValue $row @("major_name", "专业名称", "group_name", "专业组名称", "school_group_clean", "school_group_raw")
    $groupText = Get-RowValue $row @("school_group_clean", "school_group_raw", "group_name", "专业组名称")
    if ($groupText) {
        $parsed = Split-SchoolGroupText $groupText
        if (-not $schoolName -and $parsed.school_name) { $schoolName = $parsed.school_name }
        if (-not $groupCode -and $parsed.group_code) { $groupCode = $parsed.group_code }
        if (-not $majorName -and $parsed.group_name) { $majorName = $parsed.group_name }
    }
    $minScore = Convert-ToIntOrNull (Get-RowValue $row @("min_score", "最低分", "投档最低分"))
    $minRank = Convert-ToIntOrNull (Get-RowValue $row @("min_rank", "lowest_rank", "estimated_rank", "estimated_cutoff_rank_2025_from_score_band", "最低位次", "投档最低位次", "最低排名", "位次"))
    $planCount = Convert-ToIntOrNull (Get-RowValue $row @("plan_count", "计划数", "招生人数"))
    $rankEstimated = $false
    if ($null -eq $minRank -and $null -ne $minScore) {
        $minRank = Resolve-RankFromScore $minScore $scoreBands
        if ($null -ne $minRank) { $rankEstimated = $true }
    }
    if ($null -eq $minRank) { continue }

    $obj = [pscustomobject]@{
        raw=$row
        year=$rowYear
        school_code=$schoolCode
        school_name=$schoolName
        group_code=$groupCode
        major_code=$majorCode
        major_name=$majorName
        min_score=$minScore
        min_rank=$minRank
        rank_estimated=$rankEstimated
        plan_count=$planCount
        group_text=$groupText
    }
    $keys = Build-Keys $schoolCode $schoolName $groupCode $majorCode $majorName
    foreach ($k in $keys) { Add-AdmissionKey $admissionMap $k $obj }
    $obj
}

if (-not $admissions -or @($admissions).Count -eq 0) {
    throw "No historical admission rows with min_rank match the requested province/category/batch filters."
}

if ($HistoricalScreeningOnly) {
    $planByKey = @{}
    foreach ($a in $admissions) {
        $key = "$($a.school_code)|$($a.school_name)|$($a.group_code)|$($a.major_code)|$($a.major_name)"
        if ($planByKey.ContainsKey($key)) { continue }
        $subjectReq = Get-SubjectRequirementFromGroupText "$($a.group_text) $($a.major_name)"
        $remarks = "历史投档线初筛；当前年份招生计划、计划人数、组内专业、学费、校区须查招生计划专刊/官方志愿系统"
        $allText = "$($a.school_name) $($a.major_name) $subjectReq $remarks"
        if (-not (Test-SubjectEligible $subjectReq $CandidateSubjects $Category)) { continue }
        if ($CitiesAllowed -and $CitiesAllowed.Count -gt 0) {
            $okCity = $false
            foreach ($cityFilter in $CitiesAllowed) {
                if ($cityFilter -and $allText.Contains($cityFilter)) { $okCity = $true; break }
            }
            if (-not $okCity) { continue }
        }
        $isSino = ($allText -match "中外|合作办学|联合培养")
        if ($SinoForeignMode -eq "exclude" -and $isSino) { continue }
        if ($SinoForeignMode -eq "only" -and -not $isSino) { continue }

        $planByKey[$key] = [pscustomobject]@{
            raw=$a.raw
            year=$Year
            province=$Province
            category=$Category
            batch=$Batch
            school_code=$a.school_code
            school_name=$a.school_name
            group_code=$a.group_code
            major_code=$a.major_code
            major_name=$a.major_name
            plan_count=$null
            subject_requirement=$subjectReq
            city=""
            campus=""
            tuition=""
            remarks=$remarks
            is_sino=$isSino
        }
    }
    $plans = @($planByKey.Values)
    if (-not $plans -or $plans.Count -eq 0) {
        throw "No historical admission rows remain after screening filters."
    }
}

$charterSchoolSet = @{}
foreach ($row in $charterRowsRaw) {
    $schoolCode = Get-RowValue $row @("school_code", "院校代码", "学校代码")
    $schoolName = Get-RowValue $row @("school_name", "院校名称", "学校名称")
    if ($schoolCode) { $charterSchoolSet["code|$schoolCode"] = $true }
    if ($schoolName) { $charterSchoolSet["name|$schoolName"] = $true }
}

$candidates = New-Object System.Collections.Generic.List[object]
foreach ($p in $plans) {
    $keys = Build-Keys $p.school_code $p.school_name $p.group_code $p.major_code $p.major_name
    $matchedEvidence = $null
    $matchedKey = ""
    foreach ($key in $keys) {
        $keyText = [string]$key
        if ($admissionMap.ContainsKey($keyText)) {
            $evidenceList = $admissionMap.Item($keyText)
            $matchedEvidence = @($evidenceList | ForEach-Object { $_ })
            $matchedKey = $keyText
            break
        }
    }
    if (-not $matchedEvidence -or $matchedEvidence.Count -eq 0) { continue }

    $years = @($matchedEvidence | Where-Object { $_.year } | Select-Object -ExpandProperty year -Unique | Sort-Object)
    $ranks = @($matchedEvidence | Where-Object { $null -ne $_.min_rank } | Select-Object -ExpandProperty min_rank)
    if ($ranks.Count -eq 0) { continue }
    $margins = @($ranks | ForEach-Object { [int]$_ - $resolvedRank })
    $avgMargin = [Math]::Round((($margins | Measure-Object -Average).Average), 0)
    $worstMargin = ($margins | Measure-Object -Minimum).Minimum
    $bestMargin = ($margins | Measure-Object -Maximum).Maximum
    $latestEvidence = $matchedEvidence | Sort-Object year -Descending | Select-Object -First 1
    $latestMargin = [int]$latestEvidence.min_rank - $resolvedRank
    $tier = Get-Tier $resolvedRank ([double]$worstMargin) $years.Count

    $historicalPlanCounts = @($matchedEvidence | Where-Object { $null -ne $_.plan_count } | Select-Object -ExpandProperty plan_count)
    $hasEstimatedRank = @($matchedEvidence | Where-Object { $_.rank_estimated }).Count -gt 0
    $planWarning = ""
    if ($null -ne $p.plan_count -and $historicalPlanCounts.Count -gt 0) {
        $avgPlan = [Math]::Round((($historicalPlanCounts | Measure-Object -Average).Average), 0)
        if ($p.plan_count -lt $avgPlan) { $planWarning = "当前计划数低于历史均值，风险上调核验" }
    }

    $charterOk = $false
    if ($p.school_code -and $charterSchoolSet.ContainsKey("code|$($p.school_code)")) { $charterOk = $true }
    if ($p.school_name -and $charterSchoolSet.ContainsKey("name|$($p.school_name)")) { $charterOk = $true }

    $warn = New-Object System.Collections.Generic.List[string]
    if ($years.Count -lt 2) { [void]$warn.Add("历史证据不足两年") }
    if (-not $p.subject_requirement) { [void]$warn.Add("选科要求待核验") }
    if ($null -eq $p.plan_count) { [void]$warn.Add("当前计划数待查") }
    if ($matchedKey -match "^(sc|sn)\|") { [void]$warn.Add("仅学校层级历史线") }
    if (-not $charterOk) { [void]$warn.Add("招生章程/限制待核验") }
    if ($hasEstimatedRank) { [void]$warn.Add("历史最低位次由最低分+一分一段估算") }
    if ($planWarning) { [void]$warn.Add($planWarning) }
    if ($HistoricalScreeningOnly) { [void]$warn.Add("须查招生计划专刊确认今年是否招生/计划人数/组内专业") }

    $reason = "历史最低位次: " + (($matchedEvidence | Sort-Object year | ForEach-Object { "$($_.year):$($_.min_rank)" }) -join "; ")
    $action = "保留并核验代码/章程"
    if ($tier -eq "冲") { $action = "仅作冲刺，放前段" }
    elseif ($tier -eq "冲稳边界") { $action = "谨慎保留，需补稳保" }
    elseif ($tier -eq "稳") { $action = "主力稳妥候选" }
    elseif ($tier -eq "保") { $action = "保底候选" }
    elseif ($tier -eq "垫") { $action = "最后防守候选" }

    $industryTrend = Get-IndustryTrendForPlan $p $industryTrendEntries

    [void]$candidates.Add([pscustomobject]@{
        tier=$tier
        school_code=$p.school_code
        school_name=$p.school_name
        group_code=$p.group_code
        major_code=$p.major_code
        major_name=$p.major_name
        plan_count=$p.plan_count
        subject_requirement=$p.subject_requirement
        city=$p.city
        campus=$p.campus
        tuition=$p.tuition
        historical_years=($years -join "/")
        historical_min_ranks=(($matchedEvidence | Sort-Object year | ForEach-Object { "$($_.year):$($_.min_rank)" }) -join "; ")
        latest_min_rank=$latestEvidence.min_rank
        latest_margin=$latestMargin
        worst_margin=[int]$worstMargin
        best_margin=[int]$bestMargin
        avg_margin=[int]$avgMargin
        industry_trend=$industryTrend.trend
        industry_trend_keyword=$industryTrend.keyword
        industry_trend_reason=$industryTrend.reason
        evidence_key=$matchedKey
        risk_reason=$reason
        warnings=($warn -join "；")
        action=$action
    })
}

if ($candidates.Count -eq 0) {
    throw "No recommendation candidates could be matched between current plans and historical admission lines."
}

$targetCounts = @{
    "冲" = [Math]::Max(1, [int][Math]::Round($TotalSlots * 0.20))
    "冲稳边界" = [Math]::Max(1, [int][Math]::Round($TotalSlots * 0.20))
    "稳" = [Math]::Max(1, [int][Math]::Round($TotalSlots * 0.30))
    "保" = [Math]::Max(1, [int][Math]::Round($TotalSlots * 0.20))
}
$usedTargetSlots = [int]($targetCounts["冲"]) + [int]($targetCounts["冲稳边界"]) + [int]($targetCounts["稳"]) + [int]($targetCounts["保"])
$targetCounts["垫"] = [Math]::Max(0, [int]$TotalSlots - $usedTargetSlots)
$tierOrder = @("冲", "冲稳边界", "稳", "保", "垫")

$selected = New-Object System.Collections.Generic.List[object]
$schoolCounts = @{}
$selectedKeys = @{}

function Try-AddCandidate($Selected, $SchoolCounts, $SelectedKeys, $Candidate, [int]$MaxPerSchoolValue) {
    $key = "$($Candidate.school_code)|$($Candidate.group_code)|$($Candidate.major_code)|$($Candidate.major_name)"
    if ($SelectedKeys.ContainsKey($key)) { return $false }
    $schoolKey = if ($Candidate.school_code) { $Candidate.school_code } else { $Candidate.school_name }
    if (-not $schoolKey) { $schoolKey = $Candidate.school_name + $Candidate.group_code + $Candidate.major_name }
    if (-not $SchoolCounts.ContainsKey($schoolKey)) { $SchoolCounts[$schoolKey] = 0 }
    if ($SchoolCounts[$schoolKey] -ge $MaxPerSchoolValue) { return $false }
    $SelectedKeys[$key] = $true
    $SchoolCounts[$schoolKey] = $SchoolCounts[$schoolKey] + 1
    [void]$Selected.Add($Candidate)
    return $true
}

foreach ($tier in $tierOrder) {
    $needed = $targetCounts[$tier]
    if ($needed -le 0) { continue }
    if ($tier -eq "冲") {
        $pool = @($candidates | Where-Object { $_.tier -eq $tier } | Sort-Object @{Expression={ $_.worst_margin }; Descending=$true}, @{Expression={ $_.avg_margin }; Descending=$true}, school_name, major_name)
    } else {
        $pool = @($candidates | Where-Object { $_.tier -eq $tier } | Sort-Object @{Expression={ $_.worst_margin }}, @{Expression={ $_.avg_margin }}, school_name, major_name)
    }
    $added = 0
    foreach ($c in $pool) {
        if ($added -ge $needed) { break }
        if (Try-AddCandidate $selected $schoolCounts $selectedKeys $c $MaxPerSchool) { $added++ }
    }
}

if ($selected.Count -lt $TotalSlots) {
    $remainingPool = @($candidates | Sort-Object @{Expression={ [array]::IndexOf($tierOrder, $_.tier) }}, @{Expression={ [Math]::Abs([int]$_.worst_margin) }}, school_name, major_name)
    foreach ($c in $remainingPool) {
        if ($selected.Count -ge $TotalSlots) { break }
        [void](Try-AddCandidate $selected $schoolCounts $selectedKeys $c $MaxPerSchool)
    }
}

$provinceSlug = New-Slug $Province
$yearPart = if ($Year -gt 0) { [string]$Year } else { "year" }
$scorePart = if ($resolvedScore -gt 0) { "score$resolvedScore" } else { "scoreNA" }
$rankPart = "rank$resolvedRank"
$outputDir = Join-Path $PackRoot "outputs"
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
$basePrefix = if ($HistoricalScreeningOnly) { "screening" } else { "advising" }
$baseName = "$basePrefix-$provinceSlug-$yearPart-$rankPart-$scorePart-v4"
$mdPath = Join-Path $outputDir ($baseName + ".md")
$csvPath = Join-Path $outputDir ($baseName + "-table.csv")

$table = New-Object System.Collections.Generic.List[object]
$i = 1
foreach ($s in $selected) {
    $planDisplay = if ($null -eq $s.plan_count -and $HistoricalScreeningOnly) { "待查" } else { $s.plan_count }
    [void]$table.Add([pscustomobject]@{
        order=$i
        tier=$s.tier
        school_code=$s.school_code
        school_name=$s.school_name
        group_code=$s.group_code
        major_code=$s.major_code
        major_name=$s.major_name
        plan_count=$planDisplay
        subject_requirement=$s.subject_requirement
        historical_years=$s.historical_years
        historical_min_ranks=$s.historical_min_ranks
        latest_margin=$s.latest_margin
        worst_margin=$s.worst_margin
        avg_margin=$s.avg_margin
        industry_trend=$s.industry_trend
        industry_trend_keyword=$s.industry_trend_keyword
        industry_trend_reason=$s.industry_trend_reason
        warnings=$s.warnings
        action=$s.action
    })
    $i++
}

$csvLines = @($table | ConvertTo-Csv -NoTypeInformation)
Write-Utf8BomText $csvPath $csvLines

$md = New-Object System.Collections.Generic.List[string]
if ($HistoricalScreeningOnly) {
    [void]$md.Add("# 高考志愿历史投档线初筛 v4")
} else {
    [void]$md.Add("# 高考志愿建议初稿 v4")
}
[void]$md.Add("")
[void]$md.Add("## 考生画像")
[void]$md.Add("")
[void]$md.Add("- 省份/年份/批次/科类：$Province / $yearPart / $Batch / $Category")
[void]$md.Add("- 分数/位次：$resolvedScore / $resolvedRank")
if ($CandidateSubjects.Count -gt 0) { [void]$md.Add("- 选科：$($CandidateSubjects -join '+')") }
$outputNature = if ($HistoricalScreeningOnly) { "历史投档线初筛，非最终可提交志愿表" } elseif ($AllowPreliminary) { "预备初稿" } else { "正式数据包初稿" }
[void]$md.Add("- 输出性质：" + $outputNature)
[void]$md.Add("")
[void]$md.Add("## 数据依据")
[void]$md.Add("")
[void]$md.Add("- 数据包：" + $PackRoot)
[void]$md.Add("- manifest：" + $manifestPath)
if ($scoreRankFile) { [void]$md.Add("- 一分一段：" + $scoreRankFile) }
if ($plansFile -and -not $HistoricalScreeningOnly) {
    [void]$md.Add("- 当年招生计划：" + $plansFile)
} elseif ($plansFile -and $HistoricalScreeningOnly) {
    [void]$md.Add("- 当年招生计划：未纳入初筛；检测到的计划相关文件仅作背景，不作为当前院校专业组计划明细：" + $plansFile)
} elseif ($HistoricalScreeningOnly) {
    [void]$md.Add("- 当年招生计划：未纳入；须由考生/家长在招生计划专刊或官方志愿系统核对")
}
[void]$md.Add("- 近两年历史投档/录取线：" + $admissionFile)
if ($chartersFile) { [void]$md.Add("- 招生章程/限制：" + $chartersFile) }
if ($industryTrendsFile) { [void]$md.Add("- 行业趋势词典：" + $industryTrendsFile) }
if ($warnings.Count -gt 0) {
    [void]$md.Add("")
    [void]$md.Add("## 数据缺口/警告")
    [void]$md.Add("")
    foreach ($w in $warnings) { [void]$md.Add("- $w") }
}
[void]$md.Add("")
[void]$md.Add("## 策略摘要")
[void]$md.Add("")
[void]$md.Add("- 分层逻辑基于考生位次与历史最低位次的 margin：历史最低位次 - 考生位次。正数越大，历史上越安全。")
[void]$md.Add("- 使用近两年历史证据时，按更保守的 worst margin 分层。")
if ($HistoricalScreeningOnly) {
    [void]$md.Add("- 本表只回答历史上哪些院校专业组接近该位次，不确认当前年份是否招生。")
    [void]$md.Add("- 当前招生计划、计划人数、组内专业、选科要求、校区、学费、章程限制必须回查招生计划专刊/官方志愿系统。")
} else {
    [void]$md.Add("- 当前计划数、选科要求、校区、学费、章程限制仍需在提交前逐项核验。")
}
if ($industryTrendsFile) { [void]$md.Add("- 行业趋势为软标签，只作专业方向参考，不代表就业承诺或录取概率。") }
[void]$md.Add("")
[void]$md.Add("## 志愿建议表")
[void]$md.Add("")
[void]$md.Add("| 序号 | 层级 | 院校 | 专业组/专业 | 计划 | 选科要求 | 行业趋势 | 历史位次证据 | worst margin | 风险提醒 | 动作 |")
[void]$md.Add("| --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- | --- |")
foreach ($row in $table) {
    $school = Escape-Md ("$($row.school_name) $($row.school_code)")
    $major = Escape-Md ("$($row.group_code) $($row.major_code) $($row.major_name)")
    $trend = Escape-Md ("$($row.industry_trend) $($row.industry_trend_keyword)")
    [void]$md.Add("| $($row.order) | $(Escape-Md $row.tier) | $school | $major | $($row.plan_count) | $(Escape-Md $row.subject_requirement) | $trend | $(Escape-Md $row.historical_min_ranks) | $($row.worst_margin) | $(Escape-Md $row.warnings) | $(Escape-Md $row.action) |")
}
[void]$md.Add("")
[void]$md.Add("## 不可替代核验")
[void]$md.Add("")
[void]$md.Add("- [ ] 用省考试院/官方计划书核对院校代码、专业组代码、专业代码。")
[void]$md.Add("- [ ] 核对该院校专业组当前年份是否仍招生，以及招生计划人数。")
[void]$md.Add("- [ ] 核对每个院校的招生章程：体检、单科、语种、校区、学费、中外合作、转专业。")
[void]$md.Add("- [ ] 核对是否服从专业调剂，以及专业组内所有专业是否能接受。")
[void]$md.Add("- [ ] 若当前招生计划相比历史计划数减少，风险上调。")
[void]$md.Add("")
[void]$md.Add("CSV 表格：" + $csvPath)

Write-Utf8BomText $mdPath $md

Write-Host "Pipeline completed."
Write-Host "Markdown: $mdPath"
Write-Host "CSV: $csvPath"
Write-Host "Matched candidates: $($candidates.Count); selected: $($selected.Count)"
