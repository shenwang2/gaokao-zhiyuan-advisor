# 高考省份数据包标准

Use this reference whenever creating, repairing, or validating a province data pack.

## Goal

Build a province/year/category data pack from official sources before producing formal志愿建议. The pack must let Codex trace every recommendation back to current招生计划, current province rules, rank data, and recent admission evidence.

Do not treat the data pack as complete just because some third-party spreadsheet exists. Official provincial and university sources have priority.

## Required Inputs

Before building a pack, resolve:

- Province, not city.
- Application year.
- Batch, such as本科批,专科批,提前批.
- Category/科类/选科 track, such as物理类,历史类,理科,文科,艺术类,体育类.
- Candidate score and province rank when the user wants final advising.
- Preferences and constraints when ranking choices.

If the user gives only a city, map it to a province only when unambiguous, then state the province used.

## Required Six Data Classes

Formal advising requires all six classes below.

| Class | Required content | Preferred source | Completeness rule |
| --- | --- | --- | --- |
| `policy` | 志愿模式,批次设置,志愿数量,平行志愿/顺序志愿规则,投档规则,调剂/退档 rules, deadlines | Provincial education examination authority | Current application year or current official notice |
| `score_rank` | Current-year一分一段表/逐分段统计表 by category | Provincial education examination authority | Same province, year, and category as candidate |
| `control_lines` | Current-year批次线,特殊类型控制线,专科线 where relevant | Provincial education examination authority | Same province, year, and category |
| `plans` | Current-year招生计划 with school code, school name, group/major code, major name, plan count, subject requirements, tuition,学制, campus, remarks | Provincial plan book/query system, official plan PDF, or official query page | Same province, year, batch, and category; must be current-year |
| `admission_lines` | Previous two years of投档线/录取最低分/最低位次, preferably by专业组 or专业 | Provincial education examination authority; university official admission data as supplement | Two most recent available years before application year; same province, category, batch/admission model |
| `charters` | Current招生章程 and special restrictions:体检限报,单科成绩,外语语种,男女比例,校区,学费,中外合作,转专业,专业分流,专项资格 | University本科招生网, Ministry/阳光高考 official pages | Must cover all recommended schools before final delivery |

If one of the two historical years is not released or the province changed admission model, mark the limitation and use a wider risk margin. Do not silently downgrade the standard.

## Historical Screening Mode

Some provinces distribute current-year院校专业组招生计划 mainly through a paper招生计划专刊, candidate-only service platform, captcha-protected query, or login-gated志愿系统. When Codex cannot legally or technically download current plans, do not fabricate them and do not block all usefulness.

In that case, mark `plans` as `book-only` or `needs download/login`, fail `formal_readiness`, and allow `screening_readiness` if the pack has enough evidence for a clearly labeled historical初筛:

- current policy / 志愿填报 rules
- current or most relevant一分一段表 for rank conversion
- current control lines
- previous two years of historical投档线/录取最低分/最低位次, or the most recent available year with a wider caveat
- optional industry trends
- optional招生章程/通用限制 notes

Historical screening output must be titled as `历史投档线初筛` or equivalent. It must not be called a final志愿表. Each row should remind the user to verify in the official plan book/system:

- current-year whether the school/group still招生
- current plan count
- group code changes, split/merge, or renamed groups
- group-internal majors
- subject requirement
- tuition, campus,中外合作,体检/语种/单科 limits

## Optional Soft Reference Data

`industry_trends` is optional. It can add an行业趋势 soft label to each推荐行, but it is not part of the six required official admission-data classes and must not affect the readiness gate.

Use it only as a major-direction reference, not as an employment promise or admission probability. A trend dictionary may be Markdown or CSV:

- Markdown: `trends*.md` or `行业趋势*.md`, using rows such as `- 关键词 / 同义词 → 升：一句话理由`.
- CSV: `industry_trends*.csv` or `行业趋势*.csv`, with fields such as `keyword`, `trend`, `reason`.

Expected trend values are `升`, `稳`, `降`, and `中性`. The pipeline matches keywords against school name, group/major name, and remarks, while ignoring subject-only parentheses such as `(化学)` or `(不限)`, then outputs `industry_trend`, `industry_trend_keyword`, and `industry_trend_reason`.

When no trend dictionary is already present, generate one automatically during data-pack build or pipeline startup. Prefer `extracted/industry_trends-YYYY-MM.csv` because it is the most deterministic format for the pipeline. The generator must:

- read current `plans*.csv` first, otherwise read `admission_lines*.csv`
- select only keyword families that appear in the data pack's group/major/remarks text
- write UTF-8 with BOM CSV with the exact header `keyword,trend,reason,checked_date,source_id`
- use only `升`, `稳`, `降`, or `中性` in `trend`
- keep `reason` as a short caveat, not an employment promise
- leave existing `trends*.md` or `industry_trends*.csv` untouched unless the user asks to regenerate

The bundled script `scripts/generate-industry-trends.ps1` implements this default behavior. If Codex performs current online research while building the data pack, it may enrich the generated reasons, but must still keep the same CSV header and trend values.

## Source Search Order

1. Provincial education examination authority official website.
2. Official provincial admissions plan system,志愿填报 handbook, or PDF plan book.
3. Ministry/阳光高考 official pages where applicable.
4. University本科招生网 for招生章程, plan details, and restrictions.
5. Reputable third-party databases only for cross-checking or discovery. Label them `secondary only`; never use them as the only source for final advice.

Search terms should combine province, year, category, and data class, for example:

- `<省份> 2026 普通高校招生 一分一段表 物理类`
- `<省份> 2026 普通高校招生 本科批 招生计划 物理类`
- `<省份> 2025 本科批 投档线 物理类 最低位次`
- `<省份> 2024 本科批 投档线 物理类 最低位次`
- `<省份> 2026 普通高校招生 录取办法 志愿填报`

## Folder Layout

Use this layout for new packs:

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
        industry-trends/  # optional soft-reference dictionary
      extracted/
        industry_trends*.csv  # optional CSV version of the trend dictionary
      normalized/   # optional secondary canonical copies; do not require this if extracted CSVs already use the standard fields
      references/   # optional local notes such as trends*.md
      outputs/
```

For projectless Codex sessions, place user-facing outputs under the current thread's `outputs/` folder and keep intermediate data under `work/` unless the user chose another root.

## Source Status Labels

Use these labels consistently:

- `confirmed`: official source found and usable.
- `needs extraction`: official file found but table extraction/cleanup remains.
- `needs download/login`: source exists but requires manual download, account, captcha, app, or志愿系统 login.
- `not yet released`: official current-year source is not published as of checked date.
- `book-only`: official data is only in paid/printed plan book or protected system.
- `secondary only`: only non-official data found.
- `not applicable`: data class does not apply to this batch/category, with reason.

## Manifest Fields

`manifest.json` should include at least:

```json
{
  "province": "江苏",
  "province_slug": "jiangsu",
  "year": 2026,
  "category": "物理类",
  "batch": "本科批",
  "admission_model": "院校专业组",
  "created_at": "YYYY-MM-DD",
  "updated_at": "YYYY-MM-DD",
  "readiness": {
    "policy": "confirmed",
    "score_rank": "confirmed",
    "control_lines": "confirmed",
    "plans": "confirmed",
    "admission_lines": "confirmed",
    "charters": "needs extraction"
  },
  "formal_readiness": {
    "status": "blocked",
    "blocked_by": ["plans"],
    "reason": "current-year plans are book-only or login-only"
  },
  "screening_readiness": {
    "status": "ready",
    "mode": "historical_admission_line_screening"
  },
  "gaps": []
}
```

`sources.json` should list each source with:

- `data_class`
- `title`
- `publisher`
- `url`
- `year`
- `category`
- `batch`
- `checked_date`
- `status`
- `local_path`
- `notes`

## Extracted Table Minimum Fields

Prefer `.xlsx` for final human-facing files. CSV/TSV containing Chinese must be UTF-8 with BOM.

Store cleaned tables in `extracted/`. Use `normalized/` only when a second canonical copy is helpful. The pipeline accepts either directory and prefers `extracted/`.

The expected conversion is:

```text
official source page/file -> raw/<data-class>/ -> extracted/<data-class>*.csv
```

Codex should perform this conversion automatically when feasible. Raw sources may be PDFs, scanned PDFs, images, HTML pages, HTML tables, Excel/CSV downloads, ZIP archives, or query-result pages. Do not ask the user to hand-clean tables unless the source is blocked by login/captcha/app-only access, not released, paid/book-only, or extraction quality cannot be verified.

### `extracted/score_rank`

| Field | Meaning |
| --- | --- |
| `year` | Application year |
| `province` | Province |
| `category` | 科类/选科 track |
| `score` | Score band |
| `same_score_count` | Number of candidates at this score, if available |
| `cumulative_rank` | Cumulative rank / lowest rank boundary |

### `extracted/control_lines`

| Field | Meaning |
| --- | --- |
| `year` | Year |
| `province` | Province |
| `category` | Category |
| `batch` | Batch/control-line type |
| `score_line` | Control score |
| `source_id` | Link to source record |

### `extracted/plans`

| Field | Meaning |
| --- | --- |
| `year` | Current application year |
| `province` | Candidate province |
| `category` | Category |
| `batch` | Batch |
| `school_code` | Official school code |
| `school_name` | Official school name |
| `group_code` | 院校专业组 code where applicable |
| `major_code` | Major code where applicable |
| `major_name` | Major or group/major name |
| `plan_count` | Current-year plan count |
| `subject_requirement` | 首选/再选/选考 requirements |
| `tuition` | Tuition |
| `duration` | 学制 |
| `campus` | Campus |
| `remarks` | Official notes |
| `source_id` | Link to source record |

### `extracted/admission_lines`

| Field | Meaning |
| --- | --- |
| `year` | Historical year |
| `province` | Province |
| `category` | Category |
| `batch` | Batch |
| `school_code` | Official code if available |
| `school_name` | School |
| `group_code` | Group code if applicable |
| `major_code` | Major code if applicable |
| `major_name` | Major/group name if available |
| `plan_count` | Historical plan count if available |
| `min_score` | Lowest score |
| `min_rank` | Lowest rank/位次; if the official source only gives score, the pipeline may estimate this from score-rank and must mark it as estimated |
| `remarks` | Notes |
| `source_id` | Link to source record |

### `extracted/charters`

| Field | Meaning |
| --- | --- |
| `year` | Current application year |
| `school_code` | School code if available |
| `school_name` | School |
| `restriction_type` | 体检/单科/语种/校区/学费/转专业/中外合作/other |
| `restriction_text` | Official text or concise extraction |
| `applies_to` | Major/group/batch scope |
| `source_id` | Link to source record |

### Optional `extracted/industry_trends`

This table is optional. It should never be used as a substitute for official admissions evidence.

| Field | Meaning |
| --- | --- |
| `keyword` | Keyword matched against school/group/major/remarks text |
| `trend` | `升`, `稳`, `降`, or `中性` |
| `reason` | Short reason, caveat, or source note |
| `checked_date` | Date the trend dictionary was prepared or reviewed |
| `source_id` | Link to trend source or local note, if available |

Generated files should use the exact header:

```csv
keyword,trend,reason,checked_date,source_id
```

Example row:

```csv
"人工智能/智能科学与技术/数据科学","升","AI和数字化需求较强，但需关注学校平台、数学基础和实践能力","YYYY-MM-DD","auto-generated from data-pack keywords"
```

## Readiness Gate

Before final志愿建议 (`formal_readiness`):

1. Confirm all six data classes are present and official.
2. Confirm current招生计划 matches candidate province/year/category/batch.
3. Confirm historical admission evidence covers the previous two years or explicitly records why a year cannot be used.
4. Confirm candidate rank is known or can be derived from current one-score-one-rank data.
5. Confirm subject eligibility can be checked against current plan requirements.
6. Confirm each final recommended school has a current招生章程 source or a clearly marked pending verification.

Optional industry-trend data may be included after the readiness gate passes, but it cannot make an incomplete official data pack complete.

Before historical投档线初筛 (`screening_readiness`):

1. Confirm current policy/rules are available or explicitly note any pending current-year policy.
2. Confirm score-rank data can resolve candidate rank or score.
3. Confirm control lines are available for context.
4. Confirm historical admission lines cover the same province/category/batch/admission model as closely as possible.
5. Confirm current plans are either unavailable for a recorded reason or deliberately excluded by the user.
6. Add a mandatory warning that the user must verify current招生计划,计划人数,组内专业,选科要求,学费,校区, and章程限制 before submission.

If the gate fails, produce:

- `数据缺口清单`: missing class, attempted official source, status, why it blocks final advice.
- `可先做的定性分析`: qualitative range or next steps only.
- `下一步`: exact data to fetch or user action needed.

## Extraction Rules

- Prefer official structured downloads when available.
- For Excel/CSV downloads, preserve the original workbook/file under `raw/`, then export the relevant sheets as UTF-8 with BOM CSV under `extracted/`.
- For PDFs, preserve the original file under `raw/` and extract tables into `extracted/`; inspect header rows, first/middle/last rows, row counts, and shifted columns before marking `confirmed`.
- For images/scanned PDFs, run OCR/table extraction, save intermediate OCR text or table output when useful, then write verified CSV under `extracted/`. Keep status as `needs extraction` until OCR output has been sample-checked.
- For HTML tables, save the source URL/page evidence and extract with a structured parser where possible.
- For webpage query systems, save the query parameters, screenshots or downloaded result files when available, and export result rows into `extracted/` with source notes.
- Never merge different categories, batches, or admission models into one normalized table without fields that distinguish them.
- Keep original official names and codes; add normalized helper columns only after preserving official values.
- Every cleaned CSV must keep enough source linkage to audit it: `source_id` where practical, plus local raw file path or source record in `sources.json`.
- If extraction is uncertain, write a `*_needs_review.csv` or note the uncertain rows in `sources.json`; do not let uncertain data silently feed final recommendations.

## Advising After Pack Completion

Once the gate passes, run the bundled pipeline against the cleaned `extracted/` tables. Use `normalized/` only as a compatible fallback or when the project deliberately keeps canonical copies there.

When only `screening_readiness` passes, run the pipeline with `-HistoricalScreeningOnly`. Use historical admission rows as the candidate pool and leave current plan fields as `待查`.

The final output should prefer an Excel workbook for user-facing志愿建议, with sheets such as:

- `考生画像`
- `数据依据`
- `志愿建议表`
- `风险与限制`
- `行业趋势`
- `替换池`
- `提交前核验清单`
