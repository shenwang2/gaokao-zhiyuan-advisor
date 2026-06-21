# gaokao-zhiyuan-advisor generic pipeline launcher (v4)
# Examples:
#   .\run-pipeline-v4.ps1 -PackRoot "C:\path\to\data-pack" -CandidateRank 79711
#   .\run-pipeline-v4.ps1 -PackRoot "C:\path\to\data-pack" -CandidateScore 560 -AllowedSubjects "化学","地理"
#   .\run-pipeline-v4.ps1 -PackRoot "C:\path\to\data-pack" -CandidateRank 45000 -SinoForeignMode exclude -CitiesAllowed "南京","苏州"

param(
    [int]$CandidateScore = 0,
    [int]$CandidateRank = 0,
    [int]$ScoreWindow = 15,
    [int]$PerTierDraft = 12,
    [string[]]$AllowedReselect = @(),
    [string[]]$AllowedSubjects = @(),
    [string[]]$CitiesAllowed = @(),
    [string]$SinoForeignMode = "include",
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

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$PipelinePath = Join-Path $ScriptDir "pipeline-v4.ps1"

if (-not (Test-Path $PipelinePath)) {
    Write-Error "pipeline-v4.ps1 not found at $PipelinePath"
    Write-Host "请确保 pipeline-v4.ps1 位于同一 scripts/ 目录。"
    exit 1
}

$pipeArgs = @{
    CandidateScore      = $CandidateScore
    CandidateRank       = $CandidateRank
    ScoreWindow         = $ScoreWindow
    PerTierDraft        = $PerTierDraft
    AllowedReselect     = $AllowedReselect
    AllowedSubjects     = $AllowedSubjects
    CitiesAllowed       = $CitiesAllowed
    SinoForeignMode     = $SinoForeignMode
    MaxPerSchool        = $MaxPerSchool
    TotalSlots          = $TotalSlots
    Province            = $Province
    Year                = $Year
    Category            = $Category
    Batch               = $Batch
    ScoreRankPath       = $ScoreRankPath
    PlansPath           = $PlansPath
    AdmissionLinesPath  = $AdmissionLinesPath
    ChartersPath        = $ChartersPath
    IndustryTrendsPath  = $IndustryTrendsPath
}

if ($PackRoot) { $pipeArgs.PackRoot = $PackRoot }
if ($HistoricalScreeningOnly) { $pipeArgs.HistoricalScreeningOnly = $true }
if ($AllowPreliminary) { $pipeArgs.AllowPreliminary = $true }
if ($NoAutoIndustryTrends) { $pipeArgs.NoAutoIndustryTrends = $true }

& $PipelinePath @pipeArgs
