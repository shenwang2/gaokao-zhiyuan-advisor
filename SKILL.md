---
name: gaokao-zhiyuan-advisor
description: Province-aware Gaokao志愿填报 support for Chinese college entrance exam candidates and parents, including official-source data-pack creation, missing-data repair, and final志愿建议. Use when Codex needs to help with 高考志愿, 志愿填报, 冲稳保方案, 院校专业组, 专业加院校, 平行志愿, 位次换算, 招生计划, 录取风险, 院校专业对比, 自动补齐省份数据包, or preparing an application consultation plan.
---

# 高考志愿填报顾问

## Core Rules

- Treat this as high-impact educational planning. Be careful, explicit, and source-bound.
- Never invent province policies, admission plans, historical cutoff ranks, major requirements, tuition, campus locations, or admission probabilities.
- Ask for missing essentials before making a concrete plan: province, application year, 科类/选科, score, province rank, batch,志愿模式, priorities, constraints, and tolerance for risk. City alone is not enough; admissions are province-specific.
- Prefer 位次 over raw score. Raw scores across years are not comparable without the province's 一分一段表.
- Use current, province-specific official sources when the user asks for the latest year, current rules, current招生计划, or precise recommendations. Cite source names and access dates.
- If a data pack is missing or incomplete, automatically enter data-pack build/repair mode before final advising. Do not ask the user to manually collect data unless official data is login-only, not released, paid/book-only, or technically inaccessible.
- Data extraction is part of the skill workflow. When official data is published as PDF, scanned PDF, image, HTML table, Excel/CSV, ZIP, or mixed webpage content, Codex should download/save the raw source, extract/OCR/parse it, clean it into tabular CSV under `extracted/`, and verify sample rows before treating it as usable.
- Formal志愿建议 requires the six required data classes: current policy, current一分一段表, current批次控制线, current招生计划, previous two years of historical投档线/录取最低位次, and招生章程/特殊限制. If any required class is missing, output a "待补充信息/数据缺口" list and give only qualitative next steps.
- When current-year院校专业组招生计划 is book-only, login-only, app-only, captcha-protected, or otherwise unavailable to Codex, do not block all work. Mark `plans` as `book-only` or `needs download/login`, fail formal readiness, then switch to historical admission-line screening mode if the screening data is sufficient.
- Historical admission-line screening mode may output学校+专业组初筛建议 from historical投档线,一分一段,批次线,政策, and optional行业趋势. It is not a final志愿表; every row must tell the user to verify current-year招生计划,计划人数,组内专业,选科,学费,校区, and章程限制 in the official plan book/system.
- Industry trends are optional soft-reference data. They may enrich the recommendation table, but they must not replace official admission data, change readiness-gate status, or be presented as an employment promise.
- If no industry trend dictionary exists in the data pack, generate one automatically during data-pack build or pipeline startup from the pack's current plans or historical admission-line keywords. Write it as `extracted/industry_trends-YYYY-MM.csv` with fields `keyword,trend,reason,checked_date,source_id`; never overwrite a user-provided trend file unless explicitly asked.
- Separate analysis from decision. Final choices belong to the candidate and family.

## Workflow

Choose the mode first:

- **Province data pack mode**: Use when the user wants to prepare official reference data before a candidate profile is available, or when a province/year/category data pack is missing or incomplete.
- **Candidate advising mode**: Use when the user provides score/rank/subjects and wants a concrete志愿方案.
- **Historical screening mode**: Use when current-year招生计划 cannot be automatically obtained, but historical投档线 and rank data are available and the user accepts an initial学校+专业组筛选表.

For province data pack mode:

1. Confirm province, target year, batch, category/选科, and whether the pack is for testing or real advising.
2. Read `references/data-pack-standard.md`.
3. Search the provincial education examination authority first, then official招生/阳光高考/university sources only as needed.
4. Download the official raw files/pages for the six required data classes into `raw/`; then extract/OCR/parse and clean them into `extracted/` CSV tables. Record source URLs, titles, checked dates, and status in `sources.json` or `manifest.json`.
5. Clean extracted tables into the standard schema before using them for recommendations. Use `normalized/` only as an optional compatibility/canonical-copy directory.
6. If no `trends*.md` or `industry_trends*.csv` exists, create `extracted/industry_trends-YYYY-MM.csv` with `scripts/generate-industry-trends.ps1` or the same CSV schema. This file is optional soft reference data and must not be counted as official admissions evidence.
7. Mark each source as `confirmed`, `needs extraction`, `needs download/login`, `not yet released`, `book-only`, or `secondary only`. If `plans` is book-only/login-only, record the attempted source and prepare historical screening instead of asking the user to collect all data manually.
8. Summarize both `formal_readiness` and `screening_readiness`: formal requires current plans; screening can proceed without current plans if historical rank evidence is sufficient.
9. Do not produce school recommendations without a candidate rank and preferences.

For candidate advising mode:

1. Intake the student profile and constraints.
2. Locate or create the province/year/category data pack. If it is missing or incomplete, switch to province data pack mode automatically, then resume advising only after the readiness gate passes.
3. Verify province-year rules and data requirements. If formal readiness fails only because current招生计划 is book-only/login-only, offer or run historical screening mode and label the result clearly.
4. Normalize candidate schools and majors by province, category, batch,志愿模式,选科, and rank.
5. Build risk tiers: 冲, 稳, 保, 垫, with reasons and caveats.
6. Assemble an ordered志愿表 that fills all usable slots, avoids invalid options, and preserves a clear梯度.
7. Flag non-score risks:专业调剂,体检限报,单科成绩,外语语种,学费,校区,转专业政策,中外合作,民族/专项 eligibility, and graduation/career fit.
8. Provide a final checklist for the candidate to verify before submission.

## Data Standard

Use this source priority:

1. Provincial education examination authority and official志愿填报 handbook.
2. University本科招生网, official招生章程, and current招生计划.
3. Ministry or official admission platforms where applicable.
4. Reputable third-party databases only as secondary aids, clearly labeled as non-official.

For each concrete recommendation, track:

- Source name and date checked.
- Year, province, 科类/选科, batch, and志愿模式.
- Historical录取最低分/最低位次, preferably by专业组 or专业.
- Current计划人数,选科要求,学费,校区, and special restrictions.
- Any assumptions or missing fields.

For a province data pack, track:

- `policy`: current志愿填报 notice,录取办法, batch settings,志愿数量.
- `score_rank`: current-year一分一段表 by category/科类.
- `control_lines`: current-year批次线/特殊类型控制线.
- `plans`: current招生计划 and access path.
- `admission_lines`: previous two years of historical投档线/录取最低位次 by category, batch, school, group, and major where available.
- `charters`: current招生章程 and special restrictions such as体检限报,单科要求,语种,学费,校区,转专业,中外合作.
- `industry_trends` optional: keyword-level trend dictionary for school/group/major text, such as `升/稳/降/中性` plus a short reason. Use it only as a soft major-direction reference.
- `gaps`: unavailable, not yet released, login-only, book-only, technically inaccessible, or extraction/OCR sources that could not be verified after attempted processing.
- `formal_readiness`: complete only when current招生计划 is usable.
- `screening_readiness`: complete when policy, score-rank, control lines, and historical admission lines are usable enough for a labeled初筛.

## Data Pack Auto-Build

When the user gives a candidate province/year/category and asks for志愿建议, assume Codex should build or repair the matching data pack automatically unless the user explicitly says not to.

1. Resolve province from the user's input. If they give only a city, infer only when unambiguous and still confirm the province.
2. Create or locate `data-packs/<province-slug>/<year>/`.
3. Search official sources for the six required data classes. Use official provincial sources first; use university招生网 or national official platforms for章程/限制 and cross-checking.
4. Save raw official files/pages under `raw/`, cleaned/extracted tables under `extracted/`, optional secondary normalized tables under `normalized/`, and final deliverables under `outputs/`.
5. For PDF/image/OCR/HTML/Excel sources, choose the appropriate extraction path automatically: structured table parser first, spreadsheet parser for workbooks, OCR for scans/images, and manual row-sample verification for messy layouts. Write verified CSV files to `extracted/` with UTF-8 BOM.
6. Maintain `sources.json` or `manifest.json` with source title, URL/path, publisher, year, data class, checked date, status, local raw path, extracted CSV path, and extraction notes.
7. If no trend dictionary is present, auto-generate `extracted/industry_trends-YYYY-MM.csv` from data-pack keywords using `scripts/generate-industry-trends.ps1`; if online/current industry research was used, summarize the source basis in `source_id` or adjacent notes.
8. If current招生计划 is only available through a paper plan book, login system, captcha, or candidate-only portal, mark `plans` as `book-only` or `needs download/login`; do not treat this as a tooling failure.
9. Run readiness gates before advising. `formal_readiness` passes only when all six required data classes are confirmed. `screening_readiness` may pass without current plans, but only for historical admission-line screening.
10. If formal readiness fails but screening readiness passes, produce a clearly labeled historical初筛 and report exactly what the user must verify in the official招生计划专刊/system. Do not fabricate substitute current-year plan data.

Read `references/data-pack-standard.md` before creating, repairing, or validating a data pack.

## Encoding Standard

- Any CSV, TSV, or plain-text table containing Chinese must be written as UTF-8 with BOM (`utf-8-sig`) so Excel and Windows default tools do not display mojibake.
- Prefer `.xlsx` for user-facing spreadsheet deliverables when practical; otherwise use CSV with BOM.
- Before final delivery, verify Chinese table files by checking the first three bytes are `EF BB BF` and by reopening a sample row.
- Never ship files containing mojibake such as `姹熻嫃`, `楂樿€`, `�`, or replacement-character artifacts.

## Output Shape

For a full plan, include:

- `考生画像`: province, year, score/rank, subjects/category, priorities, constraints.
- `数据依据`: sources used, years compared, missing data.
- `策略摘要`: risk preference and overall梯度.
- `志愿建议表` or `历史投档线初筛表`: ordered rows with tier, school, group/major, current plan if available or `待查`, optional industry trend, historical rank band, risk reason, and warnings.
- `不可填或慎填项`: invalid choices and why.
- `提交前核验清单`: official-code check,招生章程 check, adjustment/campus/tuition check, and family confirmation.


## 自动化管道 (Pipeline)

当数据包通过 readiness gate 且存在清洗后的 `extracted/` CSV 表时，优先使用通用自动化管道生成初稿，再人工调整。`normalized/` 是可选兼容目录，不是必需。

- 管道入口：`scripts/run-pipeline-v4.ps1`（便捷包装）或直接调用 `scripts/pipeline-v4.ps1`.
- 管道读取 `manifest.json`，并优先从 `extracted/` 查找 `score_rank*.csv`, `plans*.csv`, `admission_lines*.csv`, `charters*.csv`；如果没有再兼容读取 `normalized/`.
- 管道可选读取行业趋势词典：自动查找 `trends*.md`, `行业趋势*.md`, `industry_trends*.csv`, `行业趋势*.csv`，或通过 `-IndustryTrendsPath` 指定。输出字段为 `industry_trend`, `industry_trend_keyword`, `industry_trend_reason`.
- 如果未找到趋势词典，管道默认调用 `scripts/generate-industry-trends.ps1`，从数据包里的当前计划或历史投档线关键词生成 `extracted/industry_trends-YYYY-MM.csv`，再继续读取；已有趋势文件优先，不自动覆盖。
- 当前招生计划不可自动获取时，可使用 `-HistoricalScreeningOnly` 从历史投档线直接生成学校+专业组初筛表；该结果不是最终可提交志愿表。
- 使用方式：`powershell -ExecutionPolicy Bypass -File scripts/run-pipeline-v4.ps1 -PackRoot <data-pack-root> -CandidateRank <rank>`
- 如果只提供分数，管道会用 `score_rank` 表换算位次；正式建议仍优先要求考生提供省排名/位次。
- 管道输出 Markdown 初稿和 BOM CSV 表格，仍需结合考生偏好、当前招生计划、招生章程做最终确认。
- 如果 readiness gate 不完整，只能在明确标注为预备初稿时使用 `-AllowPreliminary`.
- 详细说明见 `scripts/README.md`
Read `references/advising-framework.md` when preparing a province data pack, building a detailed plan, evaluating a candidate list, or explaining risk tiers.
