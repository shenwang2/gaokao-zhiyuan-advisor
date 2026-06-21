# 自动化管道 (Pipeline)

本 skill 附带 PowerShell 通用管道脚本，用于读取已下载、已清洗的省份数据包并生成志愿建议初稿。

数据包主流程是：官网原件放到 `raw/`，清洗后的 CSV 放到 `extracted/`。`normalized/` 只是可选兼容目录，不是必需层。

下载、PDF/图片/OCR/网页表格/Excel 抽取与清洗属于 skill 的数据包构建流程，由 Codex 在运行管道前自动完成：保存官网原件到 `raw/`，抽取并核验后写入 `extracted/`。本管道只负责读取已经清洗好的 CSV 并生成建议初稿。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `pipeline-v4.ps1` | 核心通用管道：读取 `manifest.json` 与 `extracted/*.csv`，输出 Markdown 与 CSV 志愿建议表 |
| `run-pipeline-v4.ps1` | 便捷入口：包装 `pipeline-v4.ps1` 并透传常用参数 |
| `generate-industry-trends.ps1` | 当数据包没有趋势词典时，按标准 CSV schema 自动生成 `extracted/industry_trends-YYYY-MM.csv` |

## 数据包要求

数据包根目录建议包含：

```text
manifest.json
raw/
extracted/
  score_rank*.csv
  plans*.csv  # formal mode; optional for historical screening mode
  admission_lines*.csv
  charters*.csv
normalized/  # optional fallback
references/  # optional, e.g. trends-2026-06.md
outputs/
```

正式输出要求 `manifest.json` 的 readiness gate 通过，并且六类数据齐全：

1. current policy
2. current score-rank / 一分一段
3. current control lines
4. current plans / 招生计划
5. previous two years of admission lines / 投档线
6. current charters / 招生章程与限制

行业趋势词典是可选软参考，不属于 readiness gate 的六类硬数据。若数据包没有 `trends*.md` 或 `industry_trends*.csv`，管道默认会自动生成 `extracted/industry_trends-YYYY-MM.csv`；已有趋势文件优先，不会被覆盖。

如果数据包未完全齐备，只能用 `-AllowPreliminary` 生成明确标注的预备初稿。

如果当前招生计划只能通过纸质招生计划专刊、考生登录系统、验证码、app-only 或权限接口获取，可以使用历史投档线初筛模式。该模式不要求 `plans*.csv`，但输出不是最终可提交志愿表。

## 使用方法

```powershell
# 推荐：指定数据包根目录与考生位次
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 79711

# 用分数输入；管道会用 extracted/score_rank*.csv 换算位次
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateScore 560

# 带选科、城市与中外合作过滤
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -AllowedSubjects "化学","地理" `
  -CitiesAllowed "南京","苏州" `
  -SinoForeignMode exclude

# 指定行业趋势词典；也可把 trends*.md 或 industry_trends*.csv 放在数据包根目录/references/raw/extracted 下自动匹配
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -IndustryTrendsPath "C:\path\to\trends-2026-06.md"

# 手动生成行业趋势词典；通常无需手动运行，pipeline 找不到趋势文件时会自动调用
powershell -ExecutionPolicy Bypass -File scripts\generate-industry-trends.ps1 `
  -PackRoot "C:\path\to\data-pack"

# 历史投档线初筛：当前招生计划不可自动获取时使用
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -HistoricalScreeningOnly
```

## 参数速查

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-PackRoot` | 自动检测 | 数据包根目录；推荐显式指定 |
| `-CandidateScore` | 0 | 考生分数；与 `CandidateRank` 至少提供一个 |
| `-CandidateRank` | 0 | 考生省排名/位次；优先使用 |
| `-AllowedSubjects` | 空 | 考生选科，用于过滤 `subject_requirement` |
| `-AllowedReselect` | 空 | 兼容旧参数；会合并进选科过滤 |
| `-CitiesAllowed` | 空 | 城市过滤，空表示不限 |
| `-SinoForeignMode` | include | include/exclude/only |
| `-MaxPerSchool` | 3 | 同一所学校最多进入多少个候选位 |
| `-TotalSlots` | manifest 或 40 | 志愿位数量；可由 `manifest.total_slots` 指定 |
| `-Province` / `-Year` / `-Category` / `-Batch` | manifest 值 | 覆盖 manifest 中的筛选条件 |
| `-ScoreRankPath` | 自动匹配 | 手动指定一分一段 CSV |
| `-PlansPath` | 自动匹配 | 手动指定招生计划 CSV |
| `-AdmissionLinesPath` | 自动匹配 | 手动指定历史投档线 CSV |
| `-ChartersPath` | 自动匹配 | 手动指定招生章程/限制 CSV |
| `-IndustryTrendsPath` | 自动匹配 | 可选行业趋势词典，支持 `trends*.md`、`行业趋势*.md`、`industry_trends*.csv`、`行业趋势*.csv` |
| `-NoAutoIndustryTrends` | false | 禁用缺失趋势词典时的自动生成 |
| `-HistoricalScreeningOnly` | false | 不要求当前招生计划，从历史投档线直接生成学校+专业组初筛表 |
| `-AllowPreliminary` | false | 允许在 readiness 未完全通过时生成预备初稿 |

## 输出

输出写入数据包的 `outputs/` 目录：

- `advising-<province>-<year>-rank<rank>-score<score>-v4.md`
- `advising-<province>-<year>-rank<rank>-score<score>-v4-table.csv`

CSV 使用 UTF-8 with BOM，便于 Windows Excel 打开。

`-HistoricalScreeningOnly` 输出会标注为“历史投档线初筛”，当前计划数显示为 `待查`，并提醒用户去招生计划专刊/官方志愿系统核对今年是否招生、计划人数、组内专业、选科、学费、校区和章程限制。

如果提供行业趋势词典，CSV 会额外包含：

- `industry_trend`: 升/稳/降/中性
- `industry_trend_keyword`: 命中的关键词
- `industry_trend_reason`: 一句话理由或风险提示

自动生成的趋势文件固定使用 UTF-8 with BOM CSV，表头为：

```csv
keyword,trend,reason,checked_date,source_id
```

`trend` 只允许 `升`、`稳`、`降`、`中性`。生成器会优先扫描 `plans*.csv` 的专业/专业组/备注；没有当前计划时扫描 `admission_lines*.csv`，只输出在数据包文本中出现过的专业方向关键词。

## 前置抽取要求

- PDF、扫描 PDF、图片、网页表格、Excel/CSV、ZIP 或查询结果页，都应先保留官网原件或页面证据到 `raw/`。
- 能结构化解析的优先结构化解析；扫描件/图片再走 OCR；抽取后需要抽样核验表头、首中尾行、行数和错列情况。
- 通过核验的结果写入 `extracted/*.csv`，CSV 使用 UTF-8 with BOM。
- 只有遇到登录、验证码、未发布、纸质/付费书籍、app-only、或抽取质量无法核验时，才把该数据类标为缺口。

## 注意事项

- 管道只处理已经下载并清洗好的数据包，不负责联网下载官网数据；联网下载与抽取由 skill 工作流在管道前完成。
- 管道不会替代人工核验招生章程、专业组内专业、调剂、校区、学费和体检限制。
- `extracted/` 里的 CSV 只要字段接近标准 schema 即可，不必额外复制到 `normalized/`。
- 如果历史投档线只有最低分没有最低位次，管道会尝试用一分一段表估算位次，并在建议中保留风险提醒。
- 行业趋势只是软标签，不代表就业承诺，也不改变冲稳保录取风险分层。
- 历史投档线初筛只回答“历史上哪些学校/专业组接近这个位次”，不能确认当前年份招生计划。
