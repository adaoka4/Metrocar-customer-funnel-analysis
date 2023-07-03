-- How many times was the app downloaded?

SELECT
  COUNT(DISTINCT app_download_key)
FROM
  app_downloads;

-- 23608

-- How many users signed up on the app?

SELECT
  COUNT(DISTINCT user_id)
FROM
  signups;

-- 17623

-- How many rides were requested?

SELECT
  COUNT(DISTINCT ride_id)
FROM
  ride_requests;

-- 385477

-- How many rides were completed?

SELECT 
  COUNT(ride_id)
FROM
app_downloads app
JOIN signups s
ON app.app_download_key = s.session_id
JOIN ride_requests r
ON s.user_id = r.user_id
WHERE
  cancel_ts IS NULL;

-- 223652

-- How many unique users requested a ride?

SELECT
  COUNT(DISTINCT user_id)
FROM
  ride_requests;

-- 12406

-- How many unique users completed a ride?

SELECT COUNT(DISTINCT user_id)
FROM ride_requests
WHERE cancel_ts IS NULL;

-- 6233

-- What is the average time of a ride from pick up to drop off?

WITH
  time_diff_hhmmss AS (
    SELECT
      pickup_ts,
      dropoff_ts,
      dropoff_ts - pickup_ts AS time_diff
    FROM
      ride_requests
    WHERE
      pickup_ts IS NOT NULL
      AND dropoff_ts IS NOT NULL
  )
SELECT
  AVG(
    EXTRACT(
      EPOCH
      FROM
        time_diff
    ) / 60
  ) AS average_time_diff_minutes
FROM
  time_diff_hhmmss;

-- 52.61 minutes

-- How many rides were accepted by a driver?

SELECT
  COUNT(accept_ts)
FROM
  ride_requests
WHERE
  accept_ts IS NOT NULL;

-- 248379

-- How many rides did we successfully collect payments for and how much was collected?

SELECT
  COUNT(ride_id) as approved_rides,
  SUM(purchase_amount_usd) as total_amount
FROM
  transactions
WHERE
  charge_status = 'Approved';

-- approved_rides - 212628, total_amount - 4251667.61

-- How many ride requests happened on each platform?

SELECT
  platform,
  COUNT(ride_id)
FROM
  app_downloads app
  JOIN signups s ON app.app_download_key = s.session_id
  JOIN ride_requests r ON s.user_id = r.user_id
GROUP BY
  platform;

-- android - 112317, ios - 234693, web - 38467

-- What is the drop-off from users signing up to users requesting a ride?

WITH users_signup AS (
  SELECT COUNT(DISTINCT user_id) AS signed_users
  FROM signups
),
users_request AS (
  SELECT COUNT(DISTINCT user_id) AS requested_users
  FROM ride_requests
)
SELECT ((signed_users - requested_users)::decimal / signed_users) * 100 AS percentage_difference
FROM users_signup, users_request;

-- 29.6%




-- funnel data aggregation
WITH funnel_data AS (
    SELECT s.user_id AS users, r.ride_id AS rides, *
    FROM app_downloads app
    LEFT JOIN signups s ON app.app_download_key = s.session_id
    LEFT JOIN ride_requests r ON s.user_id = r.user_id
    LEFT JOIN transactions t ON r.ride_id = t.ride_id
    LEFT JOIN reviews re ON t.ride_id = re.ride_id
)

SELECT '1' AS funnel_step, 'download' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT app_download_key) AS user_count
FROM funnel_data
GROUP BY platform, age_range, download_date

UNION

SELECT '2' AS funnel_step, 'signup' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT users) AS user_count
FROM funnel_data
WHERE signup_ts IS NOT NULL
GROUP BY platform, age_range, download_date

UNION

SELECT '3' AS funnel_step, 'ride_request' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT users) AS user_count
FROM funnel_data
WHERE request_ts IS NOT NULL
GROUP BY platform, age_range, download_date

UNION

SELECT '4' AS funnel_step, 'ride_accepted' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT users) AS user_count
FROM funnel_data
WHERE accept_ts IS NOT NULL
GROUP BY platform, age_range, download_date

UNION

SELECT '5' AS funnel_step, 'ride_completed' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT users) AS user_count
FROM funnel_data
WHERE accept_ts IS NOT NULL AND cancel_ts IS NULL
GROUP BY platform, age_range, download_date

UNION

SELECT '6' AS funnel_step, 'payment' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT users) AS user_count
FROM funnel_data
WHERE transaction_ts IS NOT NULL
GROUP BY platform, age_range, download_date

UNION

SELECT '7' AS funnel_step, 'review' AS action, platform, age_range, DATE(download_ts) AS download_date, COUNT(DISTINCT users) AS user_count
FROM funnel_data
WHERE review_id IS NOT NULL
GROUP BY platform, age_range, download_date;




-- request by hour

SELECT EXTRACT(HOUR FROM request_ts) AS hour_of_day, COUNT(DISTINCT ride_id) AS ride
FROM ride_requests
GROUP BY hour_of_day;

