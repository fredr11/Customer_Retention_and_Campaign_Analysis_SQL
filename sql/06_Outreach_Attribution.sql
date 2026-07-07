-- =========================================================
--  OUTREACH ACTIVITIES
--  Campaign Exposure, Responses, and Service Conversions
-- =========================================================

-- ---------------------------------------------------------
-- STEP 1: Join campaigns, responses, and service records
--         within 30 days of outreach
-- ---------------------------------------------------------

CREATE TABLE `Outreach_Activities` AS

WITH Outreach_Activities_Base AS (

  SELECT
    -- Campaign details
    oc.Campaign_ID,
    oc.OutreachType,
    oc.OutreachDate,
    oc.OutreachBudget,
    oc.TargetSegment,

    -- Campaign response metrics
    cr.User_ID,
    cr.ResponseFlag,
    cr.CTR,
    cr.EngagementCount,

    -- Service information (if conversion occurred)
    sr.Service_ID,
    sr.ServiceStartDate,
    sr.ServiceFee,
    sr.ServiceType,
    sr.AccessChannel,

    -- Flag indicating whether a service conversion occurred
    CASE
      WHEN sr.Service_ID IS NOT NULL THEN 1
      ELSE 0
    END AS Converted,

    -- Rank services per campaign-user pair
    ROW_NUMBER () OVER (
      PARTITION BY oc.Campaign_ID, cr.User_ID
      ORDER BY sr.ServiceStartDate ASC
    ) AS Campaign_Service_Rank,

    -- Rank campaigns per user-service pair
    ROW_NUMBER () OVER (
      PARTITION BY cr.User_ID, sr.Service_ID
      ORDER BY oc.OutreachDate ASC
    ) AS User_Service_Rank

  FROM `Outreach_Campaigns` oc

  INNER JOIN `Campaign_Response` cr
    ON oc.Campaign_ID = cr.Campaign_ID

  LEFT JOIN `Service_Records` sr
    ON cr.User_ID = sr.User_ID
   AND sr.ServiceStartDate >= oc.OutreachDate
   AND DATE_DIFF (
         sr.ServiceStartDate,
         oc.OutreachDate,
         DAY
       ) <= 30
)

-- ---------------------------------------------------------
-- STEP 2: Remove duplicate service attributions
--         Keep earliest valid conversion only
-- ---------------------------------------------------------

SELECT
  Campaign_ID,
  OutreachType,
  OutreachDate,
  OutreachBudget,
  TargetSegment,

  User_ID,
  ResponseFlag,
  CTR,
  EngagementCount,

  Service_ID,
  ServiceStartDate,
  ServiceFee,
  ServiceType,
  AccessChannel,

  Converted

FROM Outreach_Activities_Base

WHERE
  Campaign_Service_Rank = 1
  AND (
    Service_ID IS NULL
    OR User_Service_Rank = 1
  );