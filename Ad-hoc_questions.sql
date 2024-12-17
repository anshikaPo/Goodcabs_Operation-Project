/***************--------Business Request 1: City-Level Fare and Trip Summary Report---------***********************/
SELECT 
    c.city_name,
    COUNT(ft.trip_id) AS total_trips,
    ROUND(SUM(ft.fare_amount) / SUM(ft.distance_travelled_km), 2) AS avg_fare_per_km,
    ROUND(SUM(ft.fare_amount) / COUNT(ft.trip_id), 2) AS avg_fare_per_trip,
    ROUND((COUNT(ft.trip_id) * 100.0) / (SELECT COUNT(*) FROM fact_trips), 2) AS contribution_to_total_trips
FROM 
    fact_trips ft
JOIN 
    dim_city c
ON 
    ft.city_id = c.city_id
GROUP BY 
    c.city_name
    ORDER BY 
    total_trips DESC;
    
/**************-------Business Request 2: Monthly City-Level Trips Target Performance Report***************************/

WITH city_monthly_trips AS (
    -- Aggregate total trips for each city and month from fact_trips
    SELECT
        dc.city_name,                           -- Fetch city name for readability in final output
        dd.month_name,                         -- Fetch month name for time-based grouping
        dd.start_of_month AS month,            -- Aligning with the target tables using the month start date
        COUNT(ft.trip_id) AS actual_trips      -- Count of trips as actual trips taken
    FROM
        trips_db.fact_trips ft                 -- fact_trips resides in trips_db
    INNER JOIN trips_db.dim_city dc
        ON ft.city_id = dc.city_id             -- Joining to get city details
    INNER JOIN trips_db.dim_date dd
        ON ft.date = dd.date                   -- Joining to get month and date details
    GROUP BY
        dc.city_name, dd.month_name, dd.start_of_month
),

city_monthly_targets AS (
    -- Retrieve target trips for each city and month
    SELECT
        dc.city_name,                          -- Fetch city name for final output alignment
        dd.month_name,                        -- Fetch month name for time-based grouping
        mt.month,                              -- Month start date aligning with aggregated trips
        mt.total_target_trips AS target_trips -- Target trips set for the city and month
    FROM
        targets_db.monthly_target_trips mt     -- monthly_target_trips resides in targets_db
    INNER JOIN trips_db.dim_city dc
        ON mt.city_id = dc.city_id             -- Joining to get city details
    INNER JOIN trips_db.dim_date dd
        ON mt.month = dd.start_of_month        -- Joining to align target data by month
),

comparison AS (
    -- Combine actual trips and target trips for comparison
    SELECT
        cmt.city_name,                         -- City name
        cmt.month_name,                       -- Month name
        cmt.actual_trips,                     -- Actual trips taken
        ctt.target_trips,                     -- Target trips set
        CASE 
            WHEN cmt.actual_trips > ctt.target_trips THEN 'Above Target' -- Performance category
            ELSE 'Below Target'
        END AS performance_status,
        ROUND(((cmt.actual_trips - ctt.target_trips) * 100.0 / ctt.target_trips), 2) AS Pct_difference
                                                 -- Percentage difference between actual and target trips
    FROM
        city_monthly_trips cmt
    INNER JOIN city_monthly_targets ctt
        ON cmt.city_name = ctt.city_name AND cmt.month = ctt.month
)

-- Final output
SELECT
    city_name,                                 -- City name for reporting
    month_name,                               -- Month name for reporting
    actual_trips,                             -- Total trips completed
    target_trips,                             -- Total trips targeted
    performance_status,                       -- Performance classification (Above or Below Target)
    Pct_difference                            -- Percentage difference quantifying the performance gap
FROM
    comparison
ORDER BY
    city_name, month_name;
    
    WITH city_monthly_trips AS (
    -- Aggregate total trips for each city and month from fact_trips
    SELECT
        dc.city_name,                           -- Fetch city name
        dd.start_of_month AS month,            -- Month start date for alignment
        COUNT(ft.trip_id) AS actual_trips      -- Count of trips as actual trips taken
    FROM
        trips_db.fact_trips ft                 -- fact_trips resides in trips_db
    INNER JOIN trips_db.dim_city dc
        ON ft.city_id = dc.city_id             -- Joining to get city details
    INNER JOIN trips_db.dim_date dd
        ON ft.date = dd.date                   -- Joining to get month and date details
    GROUP BY
        dc.city_name, dd.start_of_month
),

city_monthly_targets AS (
    -- Retrieve target trips for each city and month
    SELECT
        dc.city_name,                          -- Fetch city name
        mt.month,                              -- Month start date aligning with aggregated trips
        mt.total_target_trips AS target_trips -- Target trips set for the city and month
    FROM
        targets_db.monthly_target_trips mt     -- monthly_target_trips resides in targets_db
    INNER JOIN trips_db.dim_city dc
        ON mt.city_id = dc.city_id             -- Joining to get city details
),

comparison AS (
    -- Combine actual trips and target trips for comparison
    SELECT
        cmt.city_name,                         -- City name
        SUM(cmt.actual_trips) AS total_actual_trips, -- Total actual trips for the city
        SUM(ctt.target_trips) AS total_target_trips  -- Total target trips for the city
    FROM
        city_monthly_trips cmt
    INNER JOIN city_monthly_targets ctt
        ON cmt.city_name = ctt.city_name AND cmt.month = ctt.month
    GROUP BY
        cmt.city_name
)

-- Final output
SELECT
    city_name,                                 -- City name for reporting
    total_actual_trips AS actual_trips,       -- Total trips completed
    total_target_trips AS target_trips,       -- Total trips targeted
    CASE 
        WHEN total_actual_trips > total_target_trips THEN 'Above Target'
        ELSE 'Below Target'
    END AS performance_status,                -- Performance classification (Above or Below Target)
    ROUND(((total_actual_trips - total_target_trips) * 100.0 / total_target_trips), 2) AS pct_difference
                                               -- Percentage difference quantifying the performance gap
FROM
    comparison
ORDER BY
    city_name;


/*****************************-----------------Buisness Request -3     --------------------------****************/
    -- City-Level Repeat Passenger Trip Frequency Report
-- This query calculates the percentage distribution of repeat passengers by the number of trips (from 2 to 10) they have taken in each city.
-- It joins the `dim_repeat_trip_distribution` and `dim_city` tables to get the percentage of repeat passengers taking 2, 3, 4, ..., 10 trips per month.

WITH RepeatPassengerTripFrequency AS (
    SELECT
        dcd.city_name,  -- City Name
        rtd.trip_count,  -- Number of trips taken by repeat passengers
        SUM(rtd.repeat_passenger_count) AS repeat_passenger_count -- Total repeat passengers for each trip count
    FROM
        dim_repeat_trip_distribution rtd
    JOIN
        dim_city dcd ON rtd.city_id = dcd.city_id  -- Joining with city to get city names
    GROUP BY
        dcd.city_name, rtd.trip_count  -- Grouping by city and trip count
),
TotalRepeatPassengers AS (
    SELECT
        dcd.city_name,  -- City Name
        SUM(rtd.repeat_passenger_count) AS total_repeat_passenger_count -- Total repeat passengers per city
    FROM
        dim_repeat_trip_distribution rtd
    JOIN
        dim_city dcd ON rtd.city_id = dcd.city_id  -- Joining with city to get city names
    GROUP BY
        dcd.city_name  -- Grouping by city
)

SELECT
    rpt.city_name,
    COALESCE(SUM(CASE WHEN rpt.trip_count = '2-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "2_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '3-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "3_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '4-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "4_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '5-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "5_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '6-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "6_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '7-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "7_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '8-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "8_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '9-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "9_trips",
    COALESCE(SUM(CASE WHEN rpt.trip_count = '10-Trips' THEN rpt.repeat_passenger_count ELSE 0 END), 0) / total_repeat.total_repeat_passenger_count * 100 AS "10_trips"
FROM
    RepeatPassengerTripFrequency rpt
JOIN
    TotalRepeatPassengers total_repeat ON rpt.city_name = total_repeat.city_name
GROUP BY
    rpt.city_name, total_repeat.total_repeat_passenger_count
ORDER BY
    rpt.city_name;
    
    -- Buiness Question -4 **********Cities with Highest and Lowest Total New Passengers Report*************************************
-- This query calculates the total new passengers for each city and ranks them.
-- It categorizes the cities into "Top 3" for highest new passengers and "Bottom 3" for lowest new passengers.

WITH TotalNewPassengers AS (
    SELECT
        dcd.city_name,  -- City Name
        SUM(fps.new_passengers) AS total_new_passengers -- Total number of new passengers per city
    FROM
        fact_passenger_summary fps
    JOIN
        dim_city dcd ON fps.city_id = dcd.city_id  -- Joining with city to get city names
    GROUP BY
        dcd.city_name  -- Grouping by city to calculate the total new passengers
),

RankedCities AS (
    SELECT
        city_name,
        total_new_passengers,
        ROW_NUMBER() OVER (ORDER BY total_new_passengers DESC) AS rank_desc,  -- Ranking cities based on total new passengers (descending order)
        ROW_NUMBER() OVER (ORDER BY total_new_passengers ASC) AS rank_asc  -- Ranking cities based on total new passengers (ascending order)
    FROM
        TotalNewPassengers
)

SELECT
    city_name,
    total_new_passengers,
    CASE
        WHEN rank_desc <= 3 THEN 'Top 3'  -- Categorizing the top 3 cities
        WHEN rank_asc <= 3 THEN 'Bottom 3'  -- Categorizing the bottom 3 cities
    END AS city_category
FROM
    RankedCities
WHERE
    rank_desc <= 3 OR rank_asc <= 3  -- Filtering to include only top 3 and bottom 3 cities
ORDER BY
    city_category DESC, total_new_passengers DESC;  -- Sorting to display "Top 3" cities first
    
    -- Buiness Question -5 :*****************Month with Highest Revenue for Each City Report****************************
-- This query calculates the total revenue for each city by month and identifies the month with the highest revenue.
-- It also calculates the percentage contribution of that month's revenue to the city's total revenue.

WITH MonthlyRevenue AS (
    SELECT
        dcd.city_name,  -- City Name
        ddt.month_name,  -- Month Name
        SUM(ft.fare_amount) AS revenue -- Total revenue for each city and month
    FROM
        fact_trips ft
    JOIN
        dim_city dcd ON ft.city_id = dcd.city_id  -- Joining with city to get city names
    JOIN
        dim_date ddt ON ft.date = ddt.date  -- Joining with date to get month names
    GROUP BY
        dcd.city_name, ddt.month_name  -- Grouping by city and month
),

TotalRevenue AS (
    SELECT
        city_name,  -- City Name
        SUM(revenue) AS total_revenue  -- Total revenue for each city across all months
    FROM
        MonthlyRevenue
    GROUP BY
        city_name  -- Grouping by city to calculate the total revenue per city
)

SELECT
    mr.city_name,
    mr.month_name AS highest_revenue_month,  -- The month with the highest revenue
    mr.revenue,  -- Revenue for the month with the highest revenue
    (mr.revenue / tr.total_revenue) * 100 AS percentage_contribution  -- Calculating the percentage contribution of the highest revenue month
FROM
    MonthlyRevenue mr
JOIN
    TotalRevenue tr ON mr.city_name = tr.city_name  -- Joining with total revenue to calculate percentage contribution
WHERE
    mr.revenue = (SELECT MAX(revenue) FROM MonthlyRevenue WHERE city_name = mr.city_name)  -- Filtering for the month with the highest revenue for each city
ORDER BY
    mr.city_name;
    
    
    -- Buniess Request -6 -********Repeat Passenger Rate Analysis Report********************
-- This query calculates the repeat passenger rate both on a monthly level and city-wide level.

WITH MonthlyRepeatRate AS (
    SELECT
        dcd.city_name,  -- City Name
        ddt.month_name,  -- Month Name
        SUM(fps.total_passengers) AS total_passengers,  -- Total passengers in the city for the month
        SUM(fps.repeat_passengers) AS repeat_passengers,  -- Total repeat passengers in the city for the month
        (SUM(fps.repeat_passengers) / SUM(fps.total_passengers)) * 100 AS monthly_repeat_passenger_rate  -- Monthly repeat passenger rate
    FROM
        fact_passenger_summary fps
    JOIN
        dim_city dcd ON fps.city_id = dcd.city_id  -- Joining with city to get city names
    JOIN
        dim_date ddt ON fps.month = ddt.date  -- Joining with date to get month names
    GROUP BY
        dcd.city_name, ddt.month_name  -- Grouping by city and month
),

CityRepeatRate AS (
    SELECT
        dcd.city_name,  -- City Name
        SUM(fps.repeat_passengers) AS total_repeat_passengers,  -- Total repeat passengers in the city across all months
        SUM(fps.total_passengers) AS total_passengers,  -- Total passengers in the city across all months
        (SUM(fps.repeat_passengers) / SUM(fps.total_passengers)) * 100 AS city_repeat_passenger_rate  -- City-wide repeat passenger rate
    FROM
        fact_passenger_summary fps
    JOIN
        dim_city dcd ON fps.city_id = dcd.city_id  -- Joining with city to get city names
    GROUP BY
        dcd.city_name  -- Grouping by city to get total repeat passenger rate for the city
)

SELECT
    mrr.city_name,
    mrr.month_name AS month,
    mrr.total_passengers,
    mrr.repeat_passengers,
    mrr.monthly_repeat_passenger_rate,
    crr.city_repeat_passenger_rate
FROM
    MonthlyRepeatRate mrr
JOIN
    CityRepeatRate crr ON mrr.city_name = crr.city_name  -- Joining with city-wide repeat passenger rate
ORDER BY
    mrr.city_name, mrr.month_name;  -- Sorting by city and month




