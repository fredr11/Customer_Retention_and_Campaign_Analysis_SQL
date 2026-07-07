-- =========================================================
--  SERVICE AND APP CHURN ANALYSIS
--  USER-LEVEL BEHAVIOR AND CHURN FLAGS
-- =========================================================

-- ---------------------------------------------------------
-- STEP 1: Prepare row-level service information per user
-- ---------------------------------------------------------

CREATE TABLE `ChurnTable` AS

WITH User_Info AS (

  SELECT
    User_ID,
    ServiceStartDate,
    ServiceEndDate,
    ServiceType,
    AccessChannel,

    -- Monetary and frequency metrics
    SUM (ServiceFee) AS Service_Fee_Sum,
    COUNT (ServiceType) AS Services,

    -- First service date per user
    MIN (ServiceStartDate) AS First_Service

  FROM `Service_Records`

  GROUP BY
    User_ID,
    ServiceStartDate,
    ServiceEndDate,
    ServiceType,
    AccessChannel
),

-- ---------------------------------------------------------
-- STEP 2: Derive sequential service attributes per user
-- ---------------------------------------------------------

User_Services AS (

  SELECT
    ui.*,

    -- First service attributes
    FIRST_VALUE (ServiceType)
      OVER (PARTITION BY User_ID ORDER BY ServiceStartDate ASC)
      AS First_Service_Type,

    FIRST_VALUE (AccessChannel)
      OVER (PARTITION BY User_ID ORDER BY ServiceStartDate ASC)
      AS First_Access_Channel,

    -- Second service type
    NTH_VALUE (ServiceType, 2)
      OVER (PARTITION BY User_ID ORDER BY ServiceStartDate ASC)
      AS Second_Service_Type,

    -- Next service attributes
    LEAD (ServiceType)
      OVER (PARTITION BY User_ID ORDER BY ServiceStartDate ASC)
      AS Next_Service_Type,

    LEAD (ServiceStartDate)
      OVER (PARTITION BY User_ID ORDER BY ServiceStartDate ASC)
      AS Next_Service_Start_Date,

    -- Days between consecutive services
    DATE_DIFF (
      ServiceStartDate,
      LAG (ServiceStartDate, 1)
        OVER (PARTITION BY User_ID ORDER BY ServiceStartDate),
      DAY
    ) AS Days_Since_Last_Service,

    -- Sequential service count
    ROW_NUMBER ()
      OVER (PARTITION BY User_ID ORDER BY ServiceStartDate ASC)
      AS Service_Quantity

  FROM User_Info ui
),

-- ---------------------------------------------------------
-- STEP 3: Define churn cutoff thresholds (75th percentile)
-- ---------------------------------------------------------

Cutoff AS (

  SELECT
    Service_Quantity,

    APPROX_QUANTILES (
      Days_Since_Last_Service,
      4
    )[OFFSET (3)] AS P75_Gap

  FROM User_Services

  GROUP BY Service_Quantity
),

-- ---------------------------------------------------------
-- STEP 4: Determine service churn risk per user
-- ---------------------------------------------------------

Service_Churn AS (

  SELECT
    us.User_ID,

    -- Binary churn flag
    CASE
      WHEN DATE_DIFF (
        '2025-08-31',
        us.ServiceStartDate,
        DAY
      ) > co.P75_Gap
      THEN 1
      ELSE 0
    END AS Service_Churn_Flag,

    -- Tiered churn risk level
    CASE
      WHEN DATE_DIFF (
        '2025-08-31',
        us.ServiceStartDate,
        DAY
      ) <= COALESCE (co.P75_Gap, overall.Avg_P75)
        THEN 'Low'

      WHEN DATE_DIFF (
        '2025-08-31',
        us.ServiceStartDate,
        DAY
      ) <= COALESCE (co.P75_Gap, overall.Avg_P75) * 1.25
        THEN 'Medium'

      ELSE 'High'
    END AS Service_Churn_Level

  FROM User_Services us

  CROSS JOIN (
    SELECT AVG (P75_Gap) AS Avg_P75 FROM Cutoff
  ) overall

  INNER JOIN (
    SELECT
      User_ID,
      MAX (Service_Quantity) AS Last_Service_Quantity
    FROM User_Services
    GROUP BY User_ID
  ) last_svc
    ON us.User_ID = last_svc.User_ID
   AND us.Service_Quantity = last_svc.Last_Service_Quantity

  LEFT JOIN Cutoff co
    ON us.Service_Quantity = co.Service_Quantity - 1
),

-- ---------------------------------------------------------
-- STEP 5: Prepare app activity metrics
-- ---------------------------------------------------------

App_Summary AS (

  SELECT
    *,

    DATE_DIFF (
      '2025-08-31',
      LastServiceDate,
      DAY
    ) AS Days_Since_App_Activity

  FROM `App_Usage`
),

-- ---------------------------------------------------------
-- STEP 6: Determine app churn risk per user
-- ---------------------------------------------------------

App_Churn AS (

  SELECT
    User_ID,
    Days_Since_App_Activity,

    CASE
      WHEN Days_Since_App_Activity > 180 THEN 1
      ELSE 0
    END AS App_Churn_Flag,

    CASE
      WHEN Days_Since_App_Activity > 180 THEN 'High'
      WHEN Days_Since_App_Activity > 90 THEN 'Medium'
      ELSE 'Low'
    END AS App_Churn_Level

  FROM App_Summary
),

-- ---------------------------------------------------------
-- STEP 7: Aggregate service history to user level
-- ---------------------------------------------------------

Service_Summary AS (

  SELECT
    User_ID,

    SUM (Service_Fee_Sum) AS Total_Service_Fee,
    SUM (Services) AS Total_Number_of_Services,

    MIN (First_Service) AS First_Service_Date,
    MAX (ServiceStartDate) AS Last_Service_Start_Date,
    MAX (ServiceEndDate) AS Last_Service_End_Date,

    ANY_VALUE (First_Service_Type) AS First_Service_Type,
    ANY_VALUE (Second_Service_Type) AS Second_Service_Type,
    ANY_VALUE (First_Access_Channel) AS First_Access_Channel,

    APPROX_QUANTILES (
      Days_Since_Last_Service,
      2
    )[OFFSET (1)] AS Median_Days_Between_Services,

    ARRAY_AGG (
      STRUCT (ServiceType, ServiceStartDate)
      ORDER BY ServiceStartDate ASC
    ) AS All_Service_Types,

    ARRAY_AGG (
      IF (
        ServiceType = 'Telehealth Consultation',
        Next_Service_Type,
        NULL
      )
      IGNORE NULLS
      ORDER BY ServiceStartDate ASC
      LIMIT 1
    )[SAFE_OFFSET (0)] AS Post_Telehealth_Service,

    ARRAY_AGG (
      IF (
        ServiceType = 'Telehealth Consultation',
        DATE_DIFF (
          Next_Service_Start_Date,
          ServiceStartDate,
          DAY
        ),
        NULL
      )
      IGNORE NULLS
      ORDER BY ServiceStartDate ASC
      LIMIT 1
    )[SAFE_OFFSET (0)] AS Days_After_Telehealth

  FROM User_Services

  GROUP BY User_ID
),

-- ---------------------------------------------------------
-- STEP 8: Aggregate campaign engagement per user
-- ---------------------------------------------------------

Campaign_Response AS (

  SELECT
    User_ID,
    SUM (ResponseFlag) AS Campaign_Responses,
    SUM (EngagementCount) AS Campaign_Engagements

  FROM `Campaign_Response`

  GROUP BY User_ID
),

-- ---------------------------------------------------------
-- STEP 9: Combine all user-level metrics
-- ---------------------------------------------------------

Combined_Tables AS (

  SELECT
    cu.*
      EXCEPT (
        Age,
        Gender,
        EmploymentStatus,
        IncomeBracket,
        Region,
        City,
        HouseholdSize
      ),

    CASE
      WHEN ss.User_ID IS NOT NULL
       AND app.User_ID IS NOT NULL
        THEN 'Service and App'
      WHEN ss.User_ID IS NOT NULL
        THEN 'Services Only'
      WHEN app.User_ID IS NOT NULL
        THEN 'App Only'
      ELSE 'Inactive'
    END AS UserStatus,

    sc.* EXCEPT (User_ID),
    ac.* EXCEPT (User_ID),
    cr.* EXCEPT (User_ID),
    ss.* EXCEPT (User_ID),
    app.* EXCEPT (User_ID, Days_Since_App_Activity)

  FROM `CareConnect_Users` cu

  LEFT JOIN Campaign_Response cr
    ON cu.User_ID = cr.User_ID

  LEFT JOIN Service_Churn sc
    ON cu.User_ID = sc.User_ID

  LEFT JOIN App_Churn ac
    ON cu.User_ID = ac.User_ID

  LEFT JOIN Service_Summary ss
    ON cu.User_ID = ss.User_ID

  LEFT JOIN App_Summary app
    ON cu.User_ID = app.User_ID
)

-- ---------------------------------------------------------
-- STEP 10: Final churn flag assignment
-- ---------------------------------------------------------

SELECT
  User_ID,

  CASE
    WHEN UserStatus = 'Inactive'
      THEN 1

    WHEN UserStatus = 'Service and App'
     AND Service_Churn_Flag = 1
     AND App_Churn_Flag = 1
      THEN 1

    WHEN UserStatus = 'Services Only'
     AND Service_Churn_Flag = 1
      THEN 1

    WHEN UserStatus = 'App Only'
     AND App_Churn_Flag = 1
      THEN 1

    ELSE 0
  END AS Final_Churn_Flag,
  *
    EXCEPT (User_ID)

FROM Combined_Tables
ORDER BY User_ID;