# gaokao-zhiyuan-advisor 使用说明

`gaokao-zhiyuan-advisor` 是一个 Codex Skill，用于辅助中国高考志愿填报场景。它可以按考生省份自动构建或修复省份数据包，整理官方数据，生成冲稳保/垫志愿建议初稿；当当年招生计划只能通过纸质计划书、登录系统、验证码或考生端获取时，也可以自动切换为“历史投档线初筛模式”。

> 重要说明：本 Skill 是志愿填报辅助工具，不替代考生和家庭的最终决策。所有正式提交前，必须以省考试院、官方志愿系统、招生计划专刊和高校招生章程为准。

## 适用场景

- 高考志愿填报咨询
- 冲稳保方案初稿生成
- 院校专业组筛选
- 根据分数/位次匹配历史投档线
- 自动整理省份数据包
- 当前招生计划无法自动下载时，生成历史投档线初筛表
- 给建议表补充“行业趋势”软参考字段

## 功能概览

- 自动识别考生省份、年份、科类/选科、批次、分数、位次等关键信息
- 优先从省教育考试院等官方来源构建数据包
- 支持官网 PDF、扫描 PDF、图片、网页表格、Excel/CSV、ZIP 等来源的下载、抽取、OCR 和清洗
- 按标准目录保存：
  - `raw/`：官网原始文件或页面证据
  - `extracted/`：清洗后的 CSV 表格
  - `outputs/`：最终输出结果
- 正式建议模式要求六类数据齐全
- 当年招生计划无法自动获取时，自动降级为“历史投档线初筛模式”
- 自动生成或读取行业趋势词典，并输出：
  - `industry_trend`
  - `industry_trend_keyword`
  - `industry_trend_reason`

## 安装方式

把整个 skill 文件夹放到 Codex 的 skills 目录下。

Windows:

```text
C:\Users\<你的用户名>\.codex\skills\gaokao-zhiyuan-advisor
```

macOS / Linux:

```text
~/.codex/skills/gaokao-zhiyuan-advisor
```

目录结构应类似：

```text
gaokao-zhiyuan-advisor/
  SKILL.md
  agents/
    openai.yaml
  references/
    data-pack-standard.md
    advising-framework.md
  scripts/
    run-pipeline-v4.ps1
    pipeline-v4.ps1
    generate-industry-trends.ps1
    README.md
```

安装后重启 Codex 或开启新会话。之后只要用户提到“高考志愿、冲稳保、院校专业组、位次、投档线、招生计划”等相关任务，Codex 会自动触发这个 Skill。

## 推荐使用方式

直接用自然语言让 Codex 运行即可，不需要用户手动调用脚本。

示例：

```text
我想填高考志愿。江苏省，2026 年，物理类，本科批，589 分，位次 45000，选科物理化学地理，想优先南京/苏州，能接受少量冲刺，不想要中外合作。
```

Codex 会按下面顺序处理：

1. 确认考生信息是否完整
2. 查找或创建该省份/年份/科类的数据包
3. 自动补齐官方数据
4. 下载官网原件到 `raw/`
5. 抽取并清洗为 `extracted/*.csv`
6. 检查 readiness gate
7. 能走正式建议就生成正式初稿
8. 当年招生计划拿不到时，自动走历史投档线初筛
9. 输出 Markdown 和 CSV 结果表

## 用户需要提供的信息

正式建议前，尽量提供：

| 信息 | 是否重要 | 示例 |
| --- | --- | --- |
| 省份 | 必须 | 江苏、浙江、山东 |
| 年份 | 必须 | 2026 |
| 科类/选科 | 必须 | 物理类，物理+化学+地理 |
| 分数 | 推荐 | 589 |
| 省排名/位次 | 强烈推荐 | 45000 |
| 批次 | 必须 | 本科批、专科批、提前批 |
| 志愿模式 | 如已知则提供 | 院校专业组、专业+院校 |
| 地域偏好 | 可选 | 南京、苏州、上海周边 |
| 专业偏好 | 可选 | 计算机、电气、医学 |
| 风险偏好 | 可选 | 稳一点、可以冲、保守 |
| 限制条件 | 可选 | 不要中外合作、不接受高学费 |

如果只提供城市，Codex 会先映射到省份，因为高考录取数据按省份组织。

## 数据包要求

正式建议模式需要六类数据：

| 数据类 | 内容 | 来源优先级 |
| --- | --- | --- |
| `policy` | 志愿规则、批次设置、投档规则、志愿数量 | 省教育考试院 |
| `score_rank` | 当年一分一段表 | 省教育考试院 |
| `control_lines` | 当年批次线、特殊类型控制线 | 省教育考试院 |
| `plans` | 当年招生计划、计划人数、专业组/专业、选科、学费、校区 | 官方计划书/官方系统/高校官网 |
| `admission_lines` | 近两年历史投档线/录取最低位次 | 省教育考试院优先 |
| `charters` | 招生章程、体检、语种、单科、转专业、中外合作等限制 | 高校本科招生网/阳光高考 |

其中 `plans` 是正式建议的关键数据。如果当年招生计划只能从纸质招生计划专刊、考生登录系统、验证码页面或 app-only 系统获取，Skill 不会伪造数据，会转为历史投档线初筛。

## 数据包目录结构

推荐结构：

```text
data-packs/
  <province-slug>/
    <year>/
      manifest.json
      sources.json
      raw/
        policy/
        score-rank/
        control-lines/
        plans/
        admission-lines/
        charters/
        industry-trends/
      extracted/
        score_rank*.csv
        control_lines*.csv
        plans*.csv
        admission_lines*.csv
        charters*.csv
        industry_trends*.csv
      normalized/
      references/
      outputs/
```

`normalized/` 是兼容目录，不是必需。只要 `extracted/` 里的 CSV 字段符合标准，pipeline 会优先读取 `extracted/`。

## CSV 编码要求

所有包含中文的 CSV/TSV/文本表格都应使用 UTF-8 with BOM。

原因：Windows Excel 和部分中文 Windows 环境默认编码容易导致乱码。

如果看到类似 `姹熻嫃`、`楂樿€`、`锟斤拷`、`�` 的内容，说明文件可能已经乱码，需要重新导出。

## 正式建议模式

当六类数据齐全时，Skill 会输出正式建议初稿。

正式建议会包含：

- 考生画像
- 数据依据
- 策略摘要
- 冲/稳/保/垫分层
- 志愿建议表
- 行业趋势软参考
- 风险提醒
- 不可填或慎填项
- 提交前核验清单

注意：即使进入正式建议模式，最终提交前仍需逐项核验：

- 院校代码
- 专业组代码
- 专业代码
- 当前年份是否招生
- 计划人数
- 组内专业
- 选科要求
- 学费
- 校区
- 体检/语种/单科要求
- 是否中外合作
- 是否接受专业调剂

## 历史投档线初筛模式

当年招生计划拿不到时，Skill 会在条件满足时自动切换到历史投档线初筛模式。

触发条件通常是：

- 招生计划只在纸质计划书中
- 需要考生登录才能查看
- 有验证码或权限限制
- 只能在志愿填报系统中查询
- app-only 或接口不可公开访问

历史初筛依赖：

- 当前政策/规则
- 当前或可用的一分一段表
- 当前批次线
- 近两年历史投档线/最低位次
- 可选招生章程限制
- 可选行业趋势

输出结果会明确标注：

```text
历史投档线初筛，非最终可提交志愿表
```

表格里的当前计划人数会显示为 `待查`。用户需要拿着结果回到招生计划专刊或官方志愿系统中核对：

- 今年是否仍招生
- 计划人数
- 专业组代码是否变化
- 组内专业
- 选科要求
- 学费/校区
- 章程限制

## 行业趋势字段

行业趋势是软参考，不属于官方录取数据，不影响 readiness gate，也不代表就业承诺。

结果表可能包含：

| 字段 | 含义 |
| --- | --- |
| `industry_trend` | 升、稳、降、中性 |
| `industry_trend_keyword` | 命中的专业方向关键词 |
| `industry_trend_reason` | 一句话解释或风险提示 |

Skill 会按以下优先级处理行业趋势：

1. 数据包已有 `trends*.md` 或 `industry_trends*.csv`，优先使用已有文件
2. 如果没有，自动生成 `extracted/industry_trends-YYYY-MM.csv`
3. 自动生成时优先扫描 `plans*.csv`
4. 如果没有当前招生计划，则扫描 `admission_lines*.csv`
5. 只输出数据包文本中实际出现过的专业方向关键词

自动生成的 CSV 表头固定为：

```csv
keyword,trend,reason,checked_date,source_id
```

`trend` 只能使用：

```text
升
稳
降
中性
```

## 手动运行 pipeline

通常不需要手动运行，直接让 Codex 执行即可。若要调试或复现，可以使用 PowerShell。

### 用位次生成建议

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000
```

### 只提供分数

pipeline 会尝试用 `score_rank*.csv` 换算位次。

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateScore 589
```

仍建议优先提供省排名/位次，因为跨年份分数不可直接比较。

### 带选科和城市过滤

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -AllowedSubjects "化学","地理" `
  -CitiesAllowed "南京","苏州"
```

### 排除中外合作

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -SinoForeignMode exclude
```

`-SinoForeignMode` 支持：

| 值 | 含义 |
| --- | --- |
| `include` | 默认，包含中外合作 |
| `exclude` | 排除中外合作 |
| `only` | 只看中外合作 |

### 历史投档线初筛

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -HistoricalScreeningOnly
```

### 指定行业趋势文件

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -IndustryTrendsPath "C:\path\to\trends-2026-06.md"
```

### 手动生成行业趋势文件

一般不需要手动运行，pipeline 找不到趋势文件时会自动调用。

```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-industry-trends.ps1 `
  -PackRoot "C:\path\to\data-pack"
```

### 禁用自动生成趋势文件

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-pipeline-v4.ps1 `
  -PackRoot "C:\path\to\data-pack" `
  -CandidateRank 45000 `
  -NoAutoIndustryTrends
```

## pipeline 参数说明

| 参数 | 说明 |
| --- | --- |
| `-PackRoot` | 数据包根目录 |
| `-CandidateScore` | 考生分数 |
| `-CandidateRank` | 考生省排名/位次，优先使用 |
| `-AllowedSubjects` | 考生选科，用于过滤选科要求 |
| `-AllowedReselect` | 兼容旧参数，会合并到选科过滤 |
| `-CitiesAllowed` | 城市过滤 |
| `-SinoForeignMode` | `include` / `exclude` / `only` |
| `-MaxPerSchool` | 同一学校最多进入多少项 |
| `-TotalSlots` | 输出志愿位数量 |
| `-Province` | 覆盖 manifest 中的省份 |
| `-Year` | 覆盖 manifest 中的年份 |
| `-Category` | 覆盖 manifest 中的科类 |
| `-Batch` | 覆盖 manifest 中的批次 |
| `-ScoreRankPath` | 手动指定一分一段 CSV |
| `-PlansPath` | 手动指定招生计划 CSV |
| `-AdmissionLinesPath` | 手动指定历史投档线 CSV |
| `-ChartersPath` | 手动指定招生章程/限制 CSV |
| `-IndustryTrendsPath` | 手动指定行业趋势文件 |
| `-HistoricalScreeningOnly` | 不要求当前招生计划，生成历史投档线初筛 |
| `-NoAutoIndustryTrends` | 禁止自动生成行业趋势文件 |
| `-AllowPreliminary` | readiness 未完全通过时允许生成预备初稿 |

## 输出文件

输出写入数据包的 `outputs/` 目录。

正式建议模式：

```text
outputs/advising-<province>-<year>-rank<rank>-score<score>-v4.md
outputs/advising-<province>-<year>-rank<rank>-score<score>-v4-table.csv
```

历史初筛模式：

```text
outputs/screening-<province>-<year>-rank<rank>-score<score>-v4.md
outputs/screening-<province>-<year>-rank<rank>-score<score>-v4-table.csv
```

CSV 使用 UTF-8 with BOM，方便 Windows Excel 打开。

## 典型使用流程

### 流程 A：新用户从零开始

用户输入：

```text
帮我做高考志愿建议。江苏省，2026 年，物理类，本科批，589 分，位次 45000，选科物理化学地理，想优先南京和苏州，风险适中。
```

Codex 会：

1. 确认信息是否完整
2. 创建或定位 `data-packs/jiangsu/2026/`
3. 搜索省考试院与官方来源
4. 下载原始资料到 `raw/`
5. 抽取/清洗到 `extracted/`
6. 生成或读取行业趋势文件
7. 检查正式建议是否可行
8. 如果招生计划拿不到，则进入历史初筛
9. 输出建议表和核验清单

### 流程 B：已有数据包

用户输入：

```text
我已经有江苏数据包了，路径是 C:\path\to\data-pack。请基于这个数据包，给位次 45000 的物理类考生生成建议。
```

Codex 会先检查数据包格式和 readiness，再决定正式建议或历史初筛。

### 流程 C：只有历史投档线，先做快速初筛

用户输入：

```text
当前招生计划先不放进来，基于近两年历史投档线、一分一段、批次线和政策，先给我做学校+专业组初筛。
```

Codex 会使用 `-HistoricalScreeningOnly`，并在结果中明确标注“非最终可提交志愿表”。

## 常见问题

### 1. 没有当年招生计划还能出建议吗？

可以，但只能出“历史投档线初筛”，不是最终志愿表。

适合先筛出学校和专业组，再由用户去招生计划专刊或官方志愿系统里核对计划人数、组内专业、选科要求和代码。

### 2. 为什么优先用位次，不优先用分数？

不同年份试卷难度和分数分布不同，分数不能直接跨年比较。位次更接近真实录取竞争位置。

### 3. 行业趋势会影响冲稳保吗？

不会。行业趋势只是软标签，帮助理解专业方向，不改变录取风险分层。

### 4. 第三方数据能不能用？

可以作为发现线索或交叉检查，但正式建议必须优先依据官方来源。不能只用第三方数据生成最终建议。

### 5. PDF、图片、扫描件怎么办？

Skill 工作流要求 Codex 先保存官网原件到 `raw/`，再用表格抽取或 OCR 清洗到 `extracted/`，并抽样核验表头、行数和错列情况。

### 6. 为什么结果里有“待查”？

通常表示当前年份招生计划、计划人数、组内专业、选科、学费、校区或招生章程还没有可自动核验的数据。提交前必须人工核对。

## 建议给用户的提示词

完整建议：

```text
我想做高考志愿填报。省份是【省份】，年份是【年份】，科类/选科是【科类/选科】，分数是【分数】，位次是【位次】，批次是【批次】。偏好【城市/专业/学校层次】，限制是【不接受项】，风险偏好是【保守/适中/可冲】。请自动补齐数据包并生成建议。
```

已有数据包：

```text
请使用这个数据包：【数据包路径】。考生信息是【省份、年份、科类、分数、位次、批次、选科、偏好】。先检查数据包是否符合格式，再生成结果。
```

历史初筛：

```text
当年招生计划先不纳入，请基于近两年历史投档线、一分一段、批次线和政策，生成历史投档线初筛表，并标注需要回招生计划书核验的项目。
```

## 维护建议

- 每年更新或重新构建省份数据包
- 历史投档线建议保留最近两年
- 当年一分一段、批次线、政策必须使用当前年份
- 招生章程应使用当前年份
- 行业趋势文件可以自动生成，也可以按当期趋势人工补充
- 不要把某个省份的真实数据长期写死在 Skill 内部，真实数据应放在数据包里

## 免责声明

本 Skill 仅用于辅助整理公开信息、构建数据包、生成志愿建议初稿或历史投档线初筛。高考志愿填报具有高影响性，任何输出都必须经过考生和家庭复核，并以省教育考试院、官方志愿系统、招生计划专刊和高校招生章程为最终依据。

