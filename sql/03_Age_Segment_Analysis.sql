-- =========================================================
-- SERVICES, ENGAGEMENT, AND CHURN RISK BY AGE
-- =========================================================

-- ---------------------------------------------------------
-- STEP 1: Calculate service-to-service gaps per user
--         (row-level, one row per service per user)
-- ---------------------------------------------------------
WITH Service_Cadence AS (
  SELECT
    User_ID,
    Service_ID,
    ServiceStartDate,

    -- Days since the previous service for the same user
    DATE_DIFF (
      ServiceStartDate,
      LAG (ServiceStartDate, 1) OVER (
        PARTITION BY User_ID
        ORDER BY ServiceStartDate
      ),
      DAY
    ) AS Days_Since_Last_Service,

    -- Sequential service number per user
    ROW_NUMBER () OVER (
      PARTITION BY User_ID
      ORDER BY ServiceStartDate ASC
    ) AS Service_Quantity

  FROM `Service_Records`
),

-- ---------------------------------------------------------
-- STEP 2: Median cadence per user
--         (user-level, repeat users only)
-- ---------------------------------------------------------
Median_Cadance_Per_User AS (
  SELECT
    User_ID,

    -- Median gap between services for each user
    APPROX_QUANTILES (Days_Since_Last_Service, 2)[OFFSET (1)]
      AS Median_Days_Between_Services

  FROM Service_Cadence
  GROUP BY User_ID
),

-- ---------------------------------------------------------
-- STEP 3: Define churn cutoff thresholds
--         (75th percentile gap by service count)
-- ---------------------------------------------------------
Cutoff AS (
  SELECT
    Service_Quantity,

    -- 75th percentile gap for users reaching this service number
    APPROX_QUANTILES (Days_Since_Last_Service, 4)[OFFSET (3)]
      AS P75_Gap

  FROM Service_Cadence
  GROUP BY Service_Quantity
),

-- ---------------------------------------------------------
-- STEP 4: Apply churn risk logic at the service level
-- ---------------------------------------------------------
Churn_Risk_Criteria AS (
  SELECT
    sc.User_ID,
    sc.Service_ID,
    sc.ServiceStartDate,
    sc.Service_Quantity,

    -- Expected window (in days) for the next service
    co.P75_Gap AS Next_Service_Within_Days,

    -- Days elapsed since the most recent service
    DATE_DIFF (
      '2025-08-31',
      sc.ServiceStartDate,
      DAY
    ) AS Days_Since_Service,

    -- Churn flag: exceeded expected gap
    CASE
      WHEN co.P75_Gap > DATE_DIFF (
        '2025-08-31',
        sc.ServiceStartDate,
        DAY
      )
      THEN 0
      ELSE 1
    END AS Churn_Risk

  FROM Service_Cadence sc
  LEFT JOIN Cutoff co
    -- Match service N to the cutoff for service N+1
    ON sc.Service_Quantity = co.Service_Quantity - 1
),

-- ---------------------------------------------------------
-- STEP 5: Total number of services per customer
-- ---------------------------------------------------------
Total_Services_per_Customer AS (
  SELECT
    sr.User_ID,
    COUNT (sr.Service_ID) AS Total_Services

  FROM `Service_Records` sr
  GROUP BY sr.User_ID
),

-- ---------------------------------------------------------
-- STEP 6: Assign churn risk at the customer level
-- ---------------------------------------------------------
Churn_Risk_by_Customer AS (
  SELECT
    ts.User_ID,
    ts.Total_Services,
    cr.Churn_Risk

  FROM Total_Services_per_Customer ts
  LEFT JOIN Churn_Risk_Criteria cr
    ON ts.User_ID = cr.User_ID
   AND ts.Total_Services = cr.Service_Quantity
),

-- ---------------------------------------------------------
-- STEP 7: Campaign engagement totals per user
-- ---------------------------------------------------------
Campaign_Engagement_Totals AS (
  SELECT
    User_ID,
    SUM (EngagementCount) AS Total_Engagements

  FROM `Campaign_Response`
  GROUP BY User_ID
),

-- ---------------------------------------------------------
-- STEP 8: Determine user activity status
-- ---------------------------------------------------------
Activity AS (
  SELECT
    User_ID,
      CASE
    WHEN Age BETWEEN 18 AND 25 THEN '18-25'
    WHEN Age BETWEEN 26 AND 33 THEN '26-33'
    WHEN Age BETWEEN 34 AND 41 THEN '34-41'
    WHEN Age BETWEEN 42 AND 49 THEN '42-49'
    WHEN Age BETWEEN 50 AND 57 THEN '50-57'
    WHEN Age BETWEEN 58 AND 65 THEN '58-65'
    WHEN Age > 65 THEN '65+'
  END AS Age_Bracket,
    CASE
      WHEN
        User_ID NOT IN (
          SELECT User_ID
          FROM `App_Usage`
        )
        AND User_ID NOT IN (
          SELECT User_ID
          FROM `Service_Records`
        )
      THEN 'Inactive'

      WHEN
        User_ID NOT IN (
          SELECT User_ID
          FROM `App_Usage`
        )
        AND User_ID IN (
          SELECT User_ID
          FROM `Service_Records`
        )
      THEN 'Services only'

      WHEN
        User_ID NOT IN (
          SELECT User_ID
          FROM `Service_Records`
        )
        AND User_ID IN (
          SELECT User_ID
          FROM `App_Usage`
        )
      THEN 'App only'

      ELSE 'Service and App'
    END AS UserStatus

  FROM `CareConnect_Users`
),

-- ---------------------------------------------------------
-- STEP 9: Convert activity status into binary flags
-- ---------------------------------------------------------
Activity_Flags AS (
  SELECT
    User_ID,
    Age_Bracket,
    1 AS Total_User,
    IF (UserStatus IN ('Service and App', 'Services only', 'App only'), 1, 0)
      AS Active_User,
    IF (UserStatus = 'Inactive', 1, 0)
      AS Inactive_User,
    IF (UserStatus = 'Services only', 1, 0)
      AS No_App_User,
    IF (UserStatus = 'App only', 1, 0)
      AS App_Only_User,
    IF (UserStatus = 'Service and App', 1, 0)
      AS App_And_Services

  FROM Activity
),

-- ---------------------------------------------------------
-- STEP 10: Aggregate engagement and service metrics per user
-- ---------------------------------------------------------
Engaged_Users AS (
  SELECT
    U.User_ID,
    U.Region,
    U.IncomeBracket,
    cr.Churn_Risk,

    COALESCE (cet.Total_Engagements, 0)
      AS Total_Campaign_Engagements,

    mc.Median_Days_Between_Services,

    COUNT (S.Service_ID) AS Service_Count,

    COUNTIF (S.ServiceType = 'Follow-up Appointment')
      AS Follow_up_Appointments,
    COUNTIF (S.ServiceType = 'Medication Support')
      AS Medication_Support,
    COUNTIF (S.ServiceType = 'Preventive Screening')
      AS Preventative_Screenings,
    COUNTIF (S.ServiceType = 'Subscription Benefit')
      AS Subscription_Benefits,
    COUNTIF (S.ServiceType = 'Telehealth Consultation')
      AS Telehealth_Consultations,
    COUNTIF (S.ServiceType = 'Vaccination')
      AS Vaccinations

  FROM `CareConnect_Users` U

  INNER JOIN `Service_Records` S
    ON U.User_ID = S.User_ID

  LEFT JOIN Campaign_Engagement_Totals cet
    ON U.User_ID = cet.User_ID

  LEFT JOIN Median_Cadance_Per_User mc
    ON U.User_ID = mc.User_ID

  LEFT JOIN Churn_Risk_by_Customer cr
    ON U.User_ID = cr.User_ID

  GROUP BY
    U.User_ID,
    U.Region,
    U.IncomeBracket,
    cr.Churn_Risk,
    Total_Campaign_Engagements,
    mc.Median_Days_Between_Services
)

-- ---------------------------------------------------------
-- STEP 11: Final aggregation by age bracket
-- ---------------------------------------------------------
SELECT
  AF.Age_Bracket,
  SUM (AF.Total_User) AS Total_Users,
  SUM (AF.Active_User) AS Active_Users,
  ROUND (SAFE_DIVIDE (
    SUM (AF.Active_User),
    SUM (AF.Total_User)), 4) AS Proportion_of_Active_Users,
  SUM (AF.Inactive_User) AS Inactive_Users,
  ROUND (SAFE_DIVIDE (
    SUM (AF.Inactive_User),
    SUM (AF.Total_User)), 4) AS Proportion_of_Inactive_Users,
  SUM (AF.No_App_User) AS No_App_Users,
  ROUND (SAFE_DIVIDE (
    SUM (AF.No_App_User),
    SUM (AF.Total_User)), 4) AS Proportion_of_No_App_Users,
  SUM (AF.App_Only_User) AS App_Only_Users,
  ROUND (SAFE_DIVIDE (
    SUM (AF.App_Only_User),
    SUM (AF.Total_User)), 4) AS Proportion_of_App_Only_Users,
  SUM (AF.App_And_Services) AS App_And_Services,
  ROUND (SAFE_DIVIDE (
    SUM (AF.App_And_Services),
    SUM (AF.Total_User)), 4) AS Proportion_of_App_And_Services_Users,

  ROUND (AVG (EU.Total_Campaign_Engagements), 2)
    AS Avg_Campaign_Engagements,

  APPROX_QUANTILES (
    EU.Median_Days_Between_Services,
    2
  )[OFFSET (1)]
    AS Median_Days_Between_Services,

  ROUND (AVG (EU.Service_Count), 2)
    AS Avg_Services_Engaged,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Churn_Risk),
    SUM (AF.Active_User)), 4)
    AS Proportion_of_Churn_Risk,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Follow_up_Appointments),
    SUM (EU.Service_Count)), 4)
    AS Proportion_of_Follow_up_Appointments,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Medication_Support),
    SUM (EU.Service_Count)), 4)
    AS Proportion_of_Medication_Support,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Preventative_Screenings),
    SUM (EU.Service_Count)), 4)
    AS Proportion_of_Preventative_Screenings,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Subscription_Benefits),
    SUM (EU.Service_Count)), 4)
    AS Proportion_of_Subscription_Benefits,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Telehealth_Consultations),
    SUM (EU.Service_Count)), 4)
    AS Proportion_of_Telehealth_Consultations,

  ROUND (SAFE_DIVIDE (
    SUM (EU.Vaccinations),
    SUM (EU.Service_Count)), 4)
    AS Proportion_of_Vaccinations

FROM Activity_Flags AF
LEFT JOIN Engaged_Users EU
  ON AF.User_ID = EU.User_ID

GROUP BY
  AF.Age_Bracket
ORDER BY 
  AF.Age_Bracket;