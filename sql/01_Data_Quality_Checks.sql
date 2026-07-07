-- ============================================================
-- Data Integrity Checks
-- ============================================================

-- Check for null values
SELECT
    COUNTIF(User_ID IS NULL)           AS User_ID_nulls,
    COUNTIF(Age IS NULL)               AS Age_nulls,
    COUNTIF(Gender IS NULL)            AS Gender_nulls,
    COUNTIF(EmploymentStatus IS NULL)  AS EmploymentStatus_nulls,
    COUNTIF(IncomeBracket IS NULL)     AS IncomeBracket_nulls,
    COUNTIF(Region IS NULL)            AS Region_nulls,
    COUNTIF(City IS NULL)              AS City_nulls,
    COUNTIF(HouseholdSize IS NULL)     AS HouseholdSize_nulls
FROM `CareConnect_Users`;

SELECT
    COUNTIF(User_ID IS NULL)           AS User_ID_nulls,
    COUNTIF(Service_ID IS NULL)        AS Service_ID_nulls,
    COUNTIF(ServiceStartDate IS NULL)  AS ServiceStartDate_nulls,
    COUNTIF(ServiceEndDate IS NULL)    AS ServiceEndDate_nulls,
    COUNTIF(ServiceFee IS NULL)        AS ServiceFee_nulls,
    COUNTIF(ServiceType IS NULL)       AS ServiceType_nulls,
    COUNTIF(AccessChannel IS NULL)     AS AccessChannel_nulls
FROM `Service_Records`;

SELECT
    COUNTIF(Campaign_ID IS NULL)       AS Campaign_ID_nulls,
    COUNTIF(OutreachType IS NULL)      AS OutreachType_nulls,
    COUNTIF(OutreachDate IS NULL)      AS OutreachDate_nulls,
    COUNTIF(OutreachBudget IS NULL)    AS OutreachBudget_nulls,
    COUNTIF(TargetSegment IS NULL)     AS TargetSegment_nulls
FROM `Outreach_Campaigns`;

SELECT
    COUNTIF(User_ID IS NULL)           AS User_ID_nulls,
    COUNTIF(AvgSessionMinutes IS NULL) AS AvgSessionMinutes_nulls,
    COUNTIF(SpendingSegment IS NULL)   AS SpendingSegment_nulls,
    COUNTIF(TelehealthSpend IS NULL)   AS TelehealthSpend_nulls,
    COUNTIF(FirstPurchaseDaysAfterInstall IS NULL)   AS FirstPurchaseDaysAfterInstall_nulls,
    COUNTIF(PaymentMethod IS NULL)     AS PaymentMethod_nulls,
    COUNTIF(LastServiceDate IS NULL)   AS LastServiceDate_nulls
FROM `App_Usage`;

SELECT
    COUNTIF(User_ID IS NULL)           AS User_ID_nulls,
    COUNTIF(Campaign_ID IS NULL)       AS Campaign_ID_nulls,
    COUNTIF(ResponseFlag IS NULL)      AS ResponseFlag_nulls,
    COUNTIF(CTR IS NULL)   	      AS CTR_nulls,	
    COUNTIF(EngagementCount IS NULL)   AS EngagementCount_nulls
FROM `Campaign_Response`

-- Checking for duplicate users.
SELECT
  COUNT (User_ID) AS All_Users,
  COUNT (DISTINCT User_ID) AS Distinct_Users
FROM `CareConnect_Users`;
-- All 3,598 User IDs are unique. OK.

-- Checking for duplicate Service IDs.
SELECT
  COUNT (Service_ID) AS All_Service_IDs,
  COUNT (DISTINCT Service_ID) AS Distinct_Service_IDs
FROM `Service_Records`;
-- All 5,003 Service IDs are unique. OK.