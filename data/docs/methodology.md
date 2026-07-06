# Methodology

Detailed phase-by-phase breakdown of the analytical approach. See the main [README](../README.md) for business context, findings, and recommendations — this file is the technical deep-dive for anyone verifying the approach.

---

## Phase 1: Data Quality Checks

Before any analysis, all five source tables (`CareConnect_Users`, `Service_Records`, `App_Usage`, `Outreach_Campaigns`, `Campaign_Response`) were checked for null values across every column using `COUNTIF`. This established which fields could be trusted for direct aggregation versus which needed explicit null-handling logic downstream (e.g. `ServiceEndDate` being null for ongoing subscriptions is expected and meaningful, not missing data).

*See: `sql/01_Data_Quality_Checks.sql`*

## Phase 2: Regional & Age-Based Engagement Analysis

Before building any composite metrics, engagement, service usage, and churn indicators were profiled across region, income bracket, and age bracket independently. This step surfaced two things that shaped every later modeling decision:

- Remote users and high-income earners were underrepresented in the raw data, which meant patterns for those subgroups needed to be treated cautiously rather than generalized with confidence.
- Median days between services varied meaningfully by region and income (61–127 days), which directly informed why churn couldn't be defined with a single fixed cutoff (see Phase 4).

*See: `sql/02_Regional_Engagement_Analysis.sql`, `sql/03_Age_Segment_Analysis.sql`*

## Phase 3: RFM Segmentation — Two Parallel Models

Rather than building one blended RFM score, two independent models were built: one from service records, one from app usage. This decision was deliberate — service engagement and app engagement measure different behaviors, and blending them into a single score would have obscured more than it revealed (e.g. a user could be highly engaged on the app but rarely use billable services, or vice versa).

| RFM Dimension | Service-Based | App-Based |
|---|---|---|
| Recency | Most recent service | Most recent app activity |
| Frequency | Number of services | Average session minutes |
| Monetary | Total service fee | Telehealth spend |

Each dimension was scored into quintiles using `NTILE(5)`, ranking users 1 (lowest) to 5 (highest) independently on each axis. `SAFE_DIVIDE` was used throughout to avoid division-by-zero errors for users with no recorded activity in a given dimension, rather than allowing the query to fail or silently return nulls.

*See: `sql/04_RFM_Model.sql`*

## Phase 4: Churn Risk — Behavior-Based, Not Fixed-Threshold

Rather than flagging churn based on a single arbitrary "days since last activity" number, churn was defined **relative to each user's own historical cadence**:

1. `LAG()` and `LEAD()` window functions sequenced each user's service history chronologically, calculating the actual gap between consecutive services per user.
2. `APPROX_QUANTILES()` calculated the 75th percentile of each user's historical inter-service gaps, establishing a personalized "expected next service" window rather than a blanket rule.
3. A user whose current gap exceeded their own 75th-percentile threshold was flagged as at-risk — meaning a user who naturally visits every 90 days is judged against their own 90-day pattern, not against someone else's 30-day pattern.
4. `FIRST_VALUE()` and `NTH_VALUE()` identified each user's first and second service types, since journey-stage churn (e.g. drop-off between the second and third service) was a distinct finding worth isolating.
5. `ARRAY_AGG()` with `STRUCT` and `ORDER BY` compiled each user's full ordered service history into a single array per user, enabling journey-level analysis (e.g. "what service typically follows a telehealth consultation?") without repeated self-joins.

App-based churn used a simpler fixed 180-day inactivity threshold, since app usage data lacked a frequency field to support the same cadence-based approach used for services — a genuine data limitation, not a modeling shortcut.

*See: `sql/05_Churn_Model.sql`*

## Phase 5: Campaign Attribution

Conversion was defined as a user completing their first service within 30 days of an outreach touchpoint. Window functions were used to prevent duplicate attribution — ensuring a single conversion wasn't counted against multiple overlapping campaigns — before aggregating conversion counts and rates by outreach type, and cross-referencing against access channel and service type to surface channel/service misalignment.

*See: `sql/06_Outreach_Attribution.sql`*

---

## Advanced SQL Techniques Reference

| Technique | Where Used | Purpose |
|---|---|---|
| CTEs (multi-stage) | Throughout | Breaking complex transformations into readable, testable stages |
| `NTILE(5)` | RFM Model | Quintile scoring for Recency, Frequency, and Monetary dimensions |
| `LAG()` / `LEAD()` | Churn Model | Sequencing each user's service history to calculate inter-service gaps |
| `FIRST_VALUE()` / `NTH_VALUE()` | Churn Model | Isolating a user's first and second service types for journey-stage analysis |
| `ROW_NUMBER()` | Churn Model | Sequential numbering of each user's services in chronological order |
| `ARRAY_AGG()` + `STRUCT` | Churn Model | Compiling each user's ordered service history into a single queryable array |
| `APPROX_QUANTILES()` | Churn Model | Calculating percentile-based, user-specific churn thresholds |
| `SAFE_DIVIDE()` | RFM Model, Outreach Attribution | Preventing division-by-zero errors in rate/ratio calculations |
| `CASE` (multi-condition) | Throughout | Encoding business logic (user status, churn flags, RFM buckets) directly in SQL |
