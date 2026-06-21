# 高考志愿填报框架

## Intake Checklist

Collect these fields before concrete recommendations:

| Field | Required details |
| --- | --- |
| Candidate | province, application year, 科类 or 首选/再选科目, score, province rank, batch |
| Policy context | 志愿模式, number of slots, whether 院校专业组 or 专业加院校, whether parallel志愿 |
| Preferences | school priority, major priority, city/region, public/private, tuition ceiling, campus preference |
| Constraints | do-not-choose majors/cities, health limitations, single-subject weaknesses, foreign-language limits |
| Risk appetite | conservative, balanced, aggressive, must-keep major, must-keep city, must-avoid调剂 |
| Materials available | 一分一段表,招生计划, historical admission data,招生章程, candidate's current draft list |

If any required field is absent, ask focused follow-up questions or produce a "待补充信息" block.

## Source Priority

Use official, province-specific, current-year materials first:

1. Provincial education examination authority: rules, batch settings,志愿数量,一分一段表, official plan book.
2. University本科招生网:招生章程,招生计划,选科要求,学费,校区,录取规则.
3. Official national platforms where relevant.
4. Third-party apps or databases: use only for cross-checking, never as the only source for final advice.

Record data freshness. If current-year招生计划 is not released or not provided, say so and treat the output as a preliminary model.

## Province Data Pack Mode

Use this mode before the candidate has provided score/rank, or when validating that official sources are available for a province.

Encoding requirement: write all CSV outputs that contain Chinese as UTF-8 with BOM (`utf-8-sig`). Verify the BOM bytes `EF BB BF` before delivery. If a file will be opened in Excel by families or counselors, prefer `.xlsx` or BOM CSV.

Before building or validating a pack, also read `data-pack-standard.md`. Formal advising requires the six data classes below:

| Section | What to collect | Status labels |
| --- | --- | --- |
| Policy | Current-year志愿填报通知,录取办法, batch schedule,志愿数量,志愿模式 | confirmed, not yet released |
| Score-rank | Current-year一分一段/逐分段统计表 by category | confirmed, image needs extraction, not yet released |
| Control lines | Current-year批次线 and special-type control lines | confirmed, not yet released |
| Plans | Current-year招生计划, official plan book, plan query path | confirmed, login/book only, not yet released |
| Admission evidence | Previous two years of投档线/录取最低位次 by school-group or major | confirmed, needs extraction, secondary only |
| Charters/restrictions | Current-year招生章程 and restrictions:体检,单科,语种,学费,校区,中外合作,转专业 | confirmed, needs extraction, not yet released |
| Gaps | Missing, login-only, paid, or unofficial-only data | list explicitly |

If the user asks for a final志愿建议 and the relevant data pack is missing or incomplete, automatically build or repair the data pack from official province sources before recommending schools. Only stop for user help when data is login-only, book-only, not released, or technically inaccessible.

Recommended output:

```markdown
## 省份数据包

- Province/year:
- Category/batch:
- Use case:
- Checked date:

### Official Sources
| Data item | Source | Year | Status | Notes |
| --- | --- | --- | --- | --- |

### Advising Readiness
- Ready:
- Missing:
- Cannot be inferred:

### Next Step
```

Do not recommend schools in province data pack mode. End by asking for candidate rank, subjects, batch, and preferences if the user wants advising.

## Risk Tier Heuristics

Use rank comparison, not score comparison, as the main signal. Compare only within the same province, category/subject track, batch, and preferably the same group or major.

| Tier | Typical use | Signals |
| --- | --- | --- |
| 冲 | Aspirational options | Candidate rank is weaker than or close to recent cutoff rank, or major is very hot |
| 稳 | Main target options | Candidate rank is comfortably stronger than recent cutoff rank, with stable plan size |
| 保 | Safety options | Candidate rank is clearly stronger than recent cutoff rank across multiple years |
| 垫 | Last-line protection | Strong margin, acceptable school/major/city, low invalid-entry risk |

Do not present exact probabilities unless a transparent model and data are supplied. Prefer language like "风险偏高", "相对稳妥", "仍需核验计划变化".

Adjust risk upward when:

- Current计划人数 decreases.
- A major or city is newly popular.
- Professional group contains highly uneven majors.
- The candidate refuses专业调剂 where that affects outcome.
- Historical data is missing, inconsistent, or from a changed admission model.
- The option has special restrictions:体检,单科,语种,政治面貌,面试,艺术/体育统考,专项资格.

Adjust risk downward only with explicit evidence:

- Multiple years of stable lower cutoff rank.
- Current计划人数 increases.
- Less popular location or acceptable major mix.
- Candidate rank has a meaningful margin and no hidden restrictions.

## Plan Construction

For each option, validate:

1. It is eligible under the student's科类/选科 and batch.
2. The school code, professional group code, and major code match the official current-year plan.
3. The group or major contains acceptable outcomes if adjustment is selected.
4. Tuition, campus,合作办学 label, and degree type are acceptable.
5. The option's risk tier fits its position in the ordered list.

Build a梯度:

- Put high-upside冲 options first if the mode is parallel志愿 and the user accepts risk.
- Use enough稳 options to carry the main expected outcome.
- Use保 and垫 options that the candidate truly accepts, not throwaway choices.
- Avoid wasting slots on invalid, disliked, or unaffordable options.

## Output Template

Use this table for a detailed recommendation:

| Order | Tier | School | Group/Major | Plan | Historical rank evidence | Key reason | Risk and warning | Action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 冲/稳/保/垫 | official name + code | group or major code | current-year count | year/rank/score | why it fits | restrictions and uncertainty | keep, verify, replace |

Then add:

- `不可填/慎填`: options that violate requirements or carry unacceptable hidden risks.
- `替换池`: backup choices by tier when the user needs more slots.
- `家长沟通版摘要`: plain-language explanation of the tradeoff.
- `提交前核验`: confirm official codes,招生章程, adjustment rules, campus, tuition, and deadline.

## Guardrails

- Do not guarantee admission.
- Do not recommend a major the student explicitly rejects as a safety choice unless the user asks to consider it.
- Do not hide assumptions. Put assumptions next to the recommendation they affect.
- Do not rely on old score lines when the province changed exam model, admission batch, subject grouping, or志愿模式.
- When browsing or using external data, cite concise links or source names and dates.
