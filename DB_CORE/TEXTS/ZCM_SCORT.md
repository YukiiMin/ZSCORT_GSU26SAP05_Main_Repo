# Message Class: ZCM_SCORT

> **Package**: `$TMP` / `ZSCORT`  
> **Master Language**: `E` (English)  
> **Short Text**: `SCORT Toolkit - Enterprise Multi-Language Message Class`  
> **Source XML**: [`ZCM_SCORT.msag.xml`](file:///d:/Minh/For_myself/ZSCORT_GSU26_SAP05/DB_CORE/TEXTS/ZCM_SCORT.msag.xml)

---

## 1. Quick Copy (Tab-Separated for SAP GUI SE91 / ADT)

```tsv
001	Transport Request/Task &1 does not exist.
002	Transport Request &1 is already in Released status.
003	Transport Request &1 released successfully.
004	Release failed for &1: &2
010	Target Apply started for TR &1.
011	Target Apply completed: &1 objects saved to snapshot, &2 skipped.
020	Object &1 &2: Source code not found on system &3.
030	AI Assistant: Syntax and quality audit completed for &1 &2.
031	AI Assistant: Transport recommendation evaluated with impact &1.
032	All Gemini API keys in pool exhausted or network unreachable.
033	SAP AI Core Destination &1 is unavailable.
034	Invalid AI Action &1 requested. Expected SYNTAX or TRANSPORT.
040	HTTP &1 Method not allowed. Only POST is supported.
041	Request payload body is empty.
050	Internal processing error: &1
060	Object type &1 is not supported.
061	Object &1 &2: Source code not found on local system.
062	Object &1 &2: Initial apply to Target repository.
063	Object &1 &2: Invalid or corrupted hex snapshot on Target.
064	Object &1 &2: Source and Target code hashes are identical.
065	Object &1 &2: Source and Target code hashes are different.
066	Transport Request &1 not found in E070.
067	Transport Request &1 status &2 is not released.
068	Transport Request &1 contains no comparable development objects.
069	Missing Transport Request parameter for action &1.
070	Task &1 released successfully. Merged to Request &2.
071	&1 is a subtask of &2. Specify the parent request.
072	Transport Request &1 is not a Workbench Request (type &2).
073	Release for &1 is incomplete (status &2, code &3).
074	Release dependent task &1 first.
075	Request &1 has &2 inactive object(s). Please activate before release.
076	Inactive object: &1 &2 (User: &3).
077	Release check failed for &1: Inactive objects exist (&2).
078	Object check error for &1: &2
079	CTS initialization failed.
080	Object is locked in another request.
081	No authorization to release request &1.
082	Invalid request &1.
083	Object check error for &1: check syntax, locks, or active state.
084	Release for &1 started in background (status O).
```

---

## 2. Concise Format (<= 39 Characters for Compact UI / Dialogs)

```tsv
001	TR/Task &1 does not exist.
002	TR &1 is already in Released status.
003	TR &1 released successfully.
004	Release failed for &1: &2
010	Target Apply started for TR &1.
011	Apply done: &1 saved, &2 skipped.
020	Object &1 &2: Not found on system &3.
030	AI audit completed for &1 &2.
031	AI recommendation evaluated: impact &1.
032	All AI keys exhausted/unreachable.
033	SAP AI Core Destination &1 unavailable.
034	Invalid AI Action &1 requested.
040	HTTP &1 Method not allowed.
041	Request payload body is empty.
050	Internal processing error: &1
060	Object type &1 is not supported.
061	Object &1 &2: Not found on local system.
062	Object &1 &2: Initial apply to Target.
063	Object &1 &2: Corrupted Target snapshot.
064	Object &1 &2: Source & Target identical.
065	Object &1 &2: Source & Target differ.
066	TR &1 not found in E070.
067	TR &1 status &2 is not released.
068	TR &1 has no comparable objects.
069	Missing TR parameter for action &1.
070	Task &1 merged to Request &2.
071	&1 is subtask of &2. Use parent TR.
072	TR &1 is not Workbench TR (type &2).
073	Release for &1 incomplete (&2, &3).
074	Release dependent task &1 first.
075	TR &1 has &2 inactive object(s).
076	Inactive object: &1 &2 (User: &3).
077	Release check failed: Inactive objects &2
078	Object check error for &1: &2
079	CTS initialization failed.
080	Object locked in another request.
081	No auth to release request &1.
082	Invalid request &1.
083	Object check error for &1: &2
084	Release &1 started in background (O).
```

---

## 3. Detailed Message Catalog Table

| Number | Short Text (Full) | Concise Text (<= 39 chars) | Length (Full / Concise) | Placeholders |
|:---:|---|---|:---:|:---:|
| **001** | `Transport Request/Task &1 does not exist.` | `TR/Task &1 does not exist.` | 42 / 26 | `&1`: TR/Task Number |
| **002** | `Transport Request &1 is already in Released status.` | `TR &1 is already in Released status.` | 50 / 36 | `&1`: TR Number |
| **003** | `Transport Request &1 released successfully.` | `TR &1 released successfully.` | 41 / 28 | `&1`: TR Number |
| **004** | `Release failed for &1: &2` | `Release failed for &1: &2` | 25 / 25 | `&1`: TR, `&2`: Error reason |
| **010** | `Target Apply started for TR &1.` | `Target Apply started for TR &1.` | 31 / 31 | `&1`: TR Number |
| **011** | `Target Apply completed: &1 objects saved to snapshot, &2 skipped.` | `Apply done: &1 saved, &2 skipped.` | 64 / 33 | `&1`: Saved count, `&2`: Skipped count |
| **020** | `Object &1 &2: Source code not found on system &3.` | `Object &1 &2: Not found on system &3.` | 48 / 37 | `&1`: Type, `&2`: Name, `&3`: System |
| **030** | `AI Assistant: Syntax and quality audit completed for &1 &2.` | `AI audit completed for &1 &2.` | 61 / 30 | `&1`: Type, `&2`: Name |
| **031** | `AI Assistant: Transport recommendation evaluated with impact &1.` | `AI recommendation evaluated: impact &1.` | 64 / 39 | `&1`: Impact level |
| **032** | `All Gemini API keys in pool exhausted or network unreachable.` | `All AI keys exhausted/unreachable.` | 60 / 35 | None |
| **033** | `SAP AI Core Destination &1 is unavailable.` | `SAP AI Core Destination &1 unavailable.` | 41 / 39 | `&1`: Destination name |
| **034** | `Invalid AI Action &1 requested. Expected SYNTAX or TRANSPORT.` | `Invalid AI Action &1 requested.` | 62 / 31 | `&1`: Action name |
| **040** | `HTTP &1 Method not allowed. Only POST is supported.` | `HTTP &1 Method not allowed.` | 49 / 28 | `&1`: Method |
| **041** | `Request payload body is empty.` | `Request payload body is empty.` | 30 / 30 | None |
| **050** | `Internal processing error: &1` | `Internal processing error: &1` | 30 / 30 | `&1`: Detail error |
| **060** | `Object type &1 is not supported.` | `Object type &1 is not supported.` | 32 / 32 | `&1`: Object type |
| **061** | `Object &1 &2: Source code not found on local system.` | `Object &1 &2: Not found on local system.` | 53 / 39 | `&1`: Type, `&2`: Name |
| **062** | `Object &1 &2: Initial apply to Target repository.` | `Object &1 &2: Initial apply to Target.` | 48 / 39 | `&1`: Type, `&2`: Name |
| **063** | `Object &1 &2: Invalid or corrupted hex snapshot on Target.` | `Object &1 &2: Corrupted Target snapshot.` | 56 / 39 | `&1`: Type, `&2`: Name |
| **064** | `Object &1 &2: Source and Target code hashes are identical.` | `Object &1 &2: Source & Target identical.` | 54 / 39 | `&1`: Type, `&2`: Name |
| **065** | `Object &1 &2: Source and Target code hashes are different.` | `Object &1 &2: Source & Target differ.` | 54 / 36 | `&1`: Type, `&2`: Name |
| **066** | `Transport Request &1 not found in E070.` | `TR &1 not found in E070.` | 39 / 24 | `&1`: TR Number |
| **067** | `Transport Request &1 status &2 is not released.` | `TR &1 status &2 is not released.` | 47 / 33 | `&1`: TR, `&2`: Status |
| **068** | `Transport Request &1 contains no comparable development objects.` | `TR &1 has no comparable objects.` | 67 / 32 | `&1`: TR Number |
| **069** | `Missing Transport Request parameter for action &1.` | `Missing TR parameter for action &1.` | 51 / 35 | `&1`: Action name |
| **070** | `Task &1 released successfully. Merged to Request &2.` | `Task &1 merged to Request &2.` | 53 / 29 | `&1`: Task, `&2`: Parent TR |
| **071** | `&1 is a subtask of &2. Specify the parent request.` | `&1 is subtask of &2. Use parent TR.` | 51 / 36 | `&1`: Task, `&2`: Parent TR |
| **072** | `Transport Request &1 is not a Workbench Request (type &2).` | `TR &1 is not Workbench TR (type &2).` | 59 / 36 | `&1`: TR, `&2`: Type |
| **073** | `Release for &1 is incomplete (status &2, code &3).` | `Release for &1 incomplete (&2, &3).` | 48 / 36 | `&1`: TR, `&2`: Status, `&3`: Code |
| **074** | `Release dependent task &1 first.` | `Release dependent task &1 first.` | 32 / 32 | `&1`: Task Number |
| **075** | `Request &1 has &2 inactive object(s). Please activate before release.` | `TR &1 has &2 inactive object(s).` | 70 / 33 | `&1`: TR, `&2`: Count |
| **076** | `Inactive object: &1 &2 (User: &3).` | `Inactive object: &1 &2 (User: &3).` | 33 / 33 | `&1`: Type, `&2`: Name, `&3`: User |
| **077** | `Release check failed for &1: Inactive objects exist (&2).` | `Release check failed: Inactive objects &2` | 57 / 39 | `&1`: TR, `&2`: Summary |
| **078** | `Object check error for &1: &2` | `Object check error for &1: &2` | 29 / 29 | `&1`: TR, `&2`: Error |
| **079** | `CTS initialization failed.` | `CTS initialization failed.` | 26 / 26 | None |
| **080** | `Object is locked in another request.` | `Object locked in another request.` | 36 / 34 | None |
| **081** | `No authorization to release request &1.` | `No auth to release request &1.` | 40 / 31 | `&1`: TR Number |
| **082** | `Invalid request &1.` | `Invalid request &1.` | 19 / 19 | `&1`: TR Number |
| **083** | `Object check error for &1: check syntax, locks, or active state.` | `Object check error for &1: &2` | 65 / 29 | `&1`: TR |
| **084** | `Release for &1 started in background (status O).` | `Release &1 started in background (O).` | 47 / 37 | `&1`: TR Number |
