# Data Dictionary

CareConnect Health's data spans 3,598 users across five linked tables:

### 1. CareConnect_Users.csv
| Variable | Description |
|---|---|
| User_ID | Unique identifier for each user (primary key across all tables) |
| Age | User age |
| Gender | Self-reported gender |
| EmploymentStatus | Employment or occupation category |
| IncomeBracket | Income level classification |
| Region | Broad geographic region |
| City | City of residence |
| HouseholdSize | Number of people in the household |

### 2. Service_Records.csv
| Variable | Description |
|---|---|
| User_ID | Unique user identifier |
| Service_ID | Unique service interaction ID |
| ServiceStartDate | Start date of the service or subscription |
| ServiceEndDate | End date (if applicable) |
| ServiceFee | Monetary value of the service |
| ServiceType | Type of service (e.g. subscription, screening, consultation) |
| AccessChannel | Access mode (partner, direct digital, community program) |

### 3. App_Usage.csv
| Variable | Description |
|---|---|
| User_ID | Unique user identifier |
| AvgSessionMinutes | Average app or telehealth session duration |
| SpendingSegment | Spending-based user classification |
| TelehealthSpend | Total telehealth-related expenditure |
| FirstPurchaseDaysAfterInstall | Days between app install and first paid service |
| PaymentMethod | Payment method used |
| LastServiceDate | Most recent service interaction date |

### 4. Outreach_Campaigns.csv
| Variable | Description |
|---|---|
| Campaign_ID | Unique outreach campaign identifier |
| OutreachType | Type of outreach (email, SMS, app notification, community, etc.) |
| OutreachDate | Campaign launch date |
| OutreachBudget | Allocated campaign budget |
| TargetSegment | Intended audience segment |

### 5. Campaign_Response.csv
| Variable | Description |
|---|---|
| User_ID | Unique user identifier |
| Campaign_ID | Associated outreach campaign |
| ResponseFlag | Binary indicator of response |
| CTR | Click-through rate |
| EngagementCount | Number of engagement interactions |

## Notes

- `User_ID` is the primary key joining all five tables.
- `ServiceStartDate`, `OutreachDate`, and `LastServiceDate` are the basis for all time-based analysis in this project (RFM recency, churn windows, campaign conversion attribution).
- The absence of a user in the service or response tables is meaningful and was interpreted carefully throughout this analysis (e.g. no service needed vs. inactivity within the observation window) rather than treated as missing data.
