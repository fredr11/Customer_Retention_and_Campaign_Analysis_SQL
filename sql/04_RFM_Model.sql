-- ============================================================
-- RFM (Recency, Frequency, Monetary) Segmentation
-- ============================================================

-- =========================================================
--  SPLITTING RFM CALCULATIONS
--  SERVICE RFM AND APP RFM
-- =========================================================

-- ---------------------------------------------------------
-- STEP 1: Aggregate service records to one row per user
-- ---------------------------------------------------------

CREATE TABLE `CareConnect_User_RFM` AS

WITH Service_Summary AS (

  SELECT
    User_ID,

    -- Monetary value from services
    SUM (ServiceFee) AS Total_Service_Fee,

    -- Frequency of services
    COUNT (ServiceType) AS Total_Number_of_Services,

    -- Most recent service activity date
    MAX (
      GREATEST (
        COALESCE (ServiceStartDate, '1900-01-01'),
        COALESCE (ServiceEndDate, '1900-01-01')
      )
    ) AS Last_Service_Activity

  FROM `Service_Records`

  GROUP BY User_ID
),

-- ---------------------------------------------------------
-- STEP 2: Prepare app usage summary per user
-- ---------------------------------------------------------

App_Summary AS (

  SELECT
    User_ID,

    -- App engagement metrics
    AvgSessionMinutes,
    TelehealthSpend,

    -- Most recent app activity date
    LastServiceDate AS Last_App_Activity

  FROM `App_Usage`
),

-- ---------------------------------------------------------
-- STEP 3: Calculate Service RFM metrics
-- ---------------------------------------------------------

Service_RFM AS (

  SELECT
    User_ID,

    Last_Service_Activity,
    Total_Number_of_Services,
    Total_Service_Fee,

    -- Recency (days since last service)
    DATE_DIFF (
      '2025-08-31',
      Last_Service_Activity,
      DAY
    ) AS Days_Since_Last_Service,

    -- RFM quintiles for services
    NTILE (5) OVER (ORDER BY Last_Service_Activity ASC) AS R_Service,
    NTILE (5) OVER (ORDER BY Total_Number_of_Services ASC) AS F_Service,
    NTILE (5) OVER (ORDER BY Total_Service_Fee ASC) AS M_Service

  FROM Service_Summary
),

-- ---------------------------------------------------------
-- STEP 4: Calculate App RFM metrics
-- ---------------------------------------------------------

App_RFM AS (

  SELECT
    User_ID,

    Last_App_Activity,
    AvgSessionMinutes,
    TelehealthSpend,

    -- Recency (days since last app activity)
    DATE_DIFF (
      '2025-08-31',
      Last_App_Activity,
      DAY
    ) AS Days_Since_Last_App,

    -- RFM quintiles for app usage
    NTILE (5) OVER (ORDER BY Last_App_Activity ASC) AS R_App,
    NTILE (5) OVER (ORDER BY AvgSessionMinutes ASC) AS F_App,
    NTILE (5) OVER (ORDER BY TelehealthSpend ASC) AS M_App

  FROM App_Summary
)

-- ---------------------------------------------------------
-- STEP 5: Combine Service RFM, App RFM, and user attributes
-- ---------------------------------------------------------

SELECT
  U.*
    EXCEPT (
      Age,
      EmploymentStatus,
      Gender,
      IncomeBracket,
      Region,
      City,
      HouseholdSize
    ),

  -- -----------------------------
  -- User Activity Status Flag
  -- -----------------------------

  CASE
    WHEN SR.User_ID IS NOT NULL
     AND AR.User_ID IS NOT NULL
      THEN 'Service and App'

    WHEN SR.User_ID IS NOT NULL
      THEN 'Services Only'

    WHEN AR.User_ID IS NOT NULL
      THEN 'App Only'

    ELSE 'Inactive'
  END AS UserStatus,

  -- -----------------------------
  -- Service RFM Outputs
  -- -----------------------------

  SR.R_Service,
  SR.F_Service,
  SR.M_Service,

  CONCAT (
    SR.R_Service,
    SR.F_Service,
    SR.M_Service
  ) AS RFM_Service,

  (SR.R_Service + SR.F_Service + SR.M_Service)
    AS RFM_Score_Service,

  SR.Days_Since_Last_Service,
  SR.Total_Number_of_Services,
  SR.Total_Service_Fee,

  -- -----------------------------
  -- App RFM Outputs
  -- -----------------------------

  AR.R_App,
  AR.F_App,
  AR.M_App,

  CONCAT (
    AR.R_App,
    AR.F_App,
    AR.M_App
  ) AS RFM_App,

  (AR.R_App + AR.F_App + AR.M_App)
    AS RFM_Score_App,

  AR.Days_Since_Last_App,
  AR.AvgSessionMinutes,
  AR.TelehealthSpend

FROM `CareConnect_Users` U

LEFT JOIN Service_RFM SR
  ON U.User_ID = SR.User_ID

LEFT JOIN App_RFM AR
  ON U.User_ID = AR.User_ID

ORDER BY
  U.User_ID;