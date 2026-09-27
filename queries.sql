
--- COHORT USER RETENTION MATRIX (USER COUNT & RETENTION RATE)
WITH first_purchase AS (
    SELECT 
        c.customer_unique_id, 
        MIN(o.order_month) AS cohort_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
user_activities AS (
    SELECT 
        c.customer_unique_id,
        o.order_month AS activity_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, o.order_month
),
cohort_size AS (
    SELECT 
        cohort_month, 
        COUNT(DISTINCT customer_unique_id) AS total_users
    FROM first_purchase
    GROUP BY cohort_month
)

SELECT 
    fp.cohort_month,
    ua.activity_month,
    (CAST(SUBSTR(ua.activity_month, 1, 4) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 1, 4) AS INTEGER)) * 12 +
    (CAST(SUBSTR(ua.activity_month, 6, 2) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 6, 2) AS INTEGER)) AS cohort_index,
    COUNT(DISTINCT fp.customer_unique_id) AS retained_users,
    cs.total_users
FROM first_purchase fp
JOIN user_activities ua ON fp.customer_unique_id = ua.customer_unique_id
JOIN cohort_size cs ON fp.cohort_month = cs.cohort_month
GROUP BY fp.cohort_month, ua.activity_month
ORDER BY fp.cohort_month, cohort_index;

--- Average Retention Rate
WITH first_purchase AS (
    SELECT c.customer_unique_id, MIN(o.order_month) AS cohort_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
user_activities AS (
    SELECT c.customer_unique_id, o.order_month AS activity_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, o.order_month
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS total_users
    FROM first_purchase
    GROUP BY cohort_month
),
monthly_rates AS (
    SELECT 
        fp.cohort_month,
        (CAST(SUBSTR(ua.activity_month, 1, 4) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 1, 4) AS INTEGER)) * 12 +
        (CAST(SUBSTR(ua.activity_month, 6, 2) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 6, 2) AS INTEGER)) AS period_number,
        COUNT(DISTINCT fp.customer_unique_id) * 100.0 / cs.total_users AS retention_pct
    FROM first_purchase fp
    JOIN user_activities ua ON fp.customer_unique_id = ua.customer_unique_id
    JOIN cohort_size cs ON fp.cohort_month = cs.cohort_month
    GROUP BY fp.cohort_month, ua.activity_month
)
SELECT 
    period_number,
    ROUND(AVG(retention_pct), 2) AS avg_retention_pct
FROM monthly_rates
GROUP BY period_number
ORDER BY period_number;


--- The Best and The Worst Cohort
WITH first_purchase AS (
    SELECT c.customer_unique_id, MIN(o.order_month) AS cohort_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
user_activities AS (
    SELECT c.customer_unique_id, o.order_month AS activity_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, o.order_month
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS total_users
    FROM first_purchase
    GROUP BY cohort_month
),
month_1_data AS (
    SELECT 
        fp.cohort_month,
        COUNT(DISTINCT fp.customer_unique_id) * 100.0 / cs.total_users AS retention_pct
    FROM first_purchase fp
    JOIN user_activities ua ON fp.customer_unique_id = ua.customer_unique_id
    JOIN cohort_size cs ON fp.cohort_month = cs.cohort_month
    WHERE (CAST(SUBSTR(ua.activity_month, 1, 4) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 1, 4) AS INTEGER)) * 12 +
          (CAST(SUBSTR(ua.activity_month, 6, 2) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 6, 2) AS INTEGER)) = 1
    GROUP BY fp.cohort_month
)
SELECT * FROM (
    SELECT 'Best Cohort' AS status, cohort_month, ROUND(retention_pct, 2) AS retention_pct 
    FROM month_1_data ORDER BY retention_pct DESC LIMIT 1
)
UNION ALL
SELECT * FROM (
    SELECT 'Worst Cohort' AS status, cohort_month, ROUND(retention_pct, 2) AS retention_pct 
    FROM month_1_data ORDER BY retention_pct ASC LIMIT 1
);



-- COHORT REVENUE PER USER PER PERIOD
WITH first_purchase AS (
    SELECT c.customer_unique_id, MIN(o.order_month) AS cohort_month
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT 
    fp.cohort_month,
    (CAST(SUBSTR(o.order_month, 1, 4) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 1, 4) AS INTEGER)) * 12 +
    (CAST(SUBSTR(o.order_month, 6, 2) AS INTEGER) - CAST(SUBSTR(fp.cohort_month, 6, 2) AS INTEGER)) AS period_number,
    ROUND(SUM(i.price + i.freight_value), 2) AS total_revenue
FROM first_purchase fp
JOIN olist_customers_dataset c ON fp.customer_unique_id = c.customer_unique_id
JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
JOIN olist_order_items_dataset i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
GROUP BY fp.cohort_month, period_number
ORDER BY fp.cohort_month, period_number;


# Cohort Analysis Matrix
with first_purchase as (
    select 
        c.customer_unique_id, 
        min(o.order_month) as cohort_month
    from olist_customers_dataset c
    join olist_orders_dataset o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id
),
user_activities as (
    select 
        c.customer_unique_id, 
        o.order_month as activity_month
    from olist_customers_dataset c
    join olist_orders_dataset o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id, o.order_month
),
periods as (
    select 
        fp.cohort_month,
        fp.customer_unique_id,
        (cast(substr(ua.activity_month, 1, 4) as integer) - cast(substr(fp.cohort_month, 1, 4) as integer)) * 12 +
        (cast(substr(ua.activity_month, 6, 2) as integer) - cast(substr(fp.cohort_month, 6, 2) as integer)) as period_number
    from first_purchase fp
    join user_activities ua on fp.customer_unique_id = ua.customer_unique_id
)
select 
    cohort_month,
    count(distinct case when period_number = 0 then customer_unique_id end) as m_0,
    count(distinct case when period_number = 1 then customer_unique_id end) as m_1,
    count(distinct case when period_number = 2 then customer_unique_id end) as m_2,
    count(distinct case when period_number = 3 then customer_unique_id end) as m_3,
    count(distinct case when period_number = 4 then customer_unique_id end) as m_4,
    count(distinct case when period_number = 5 then customer_unique_id end) as m_5,
    count(distinct case when period_number = 6 then customer_unique_id end) as m_6
from periods
group by cohort_month
order by cohort_month;


--- Retention for States
with first_purchase as (
    select 
        c.customer_unique_id, 
        c.customer_state,
        min(o.order_month) as cohort_month
    from olist_customers_dataset c
    join olist_orders_dataset o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id, c.customer_state
),
user_activities as (
    select 
        c.customer_unique_id, 
        o.order_month as activity_month
    from olist_customers_dataset c
    join olist_orders_dataset o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id, o.order_month
)
select 
    fp.customer_state,
    fp.cohort_month,
    (cast(substr(ua.activity_month, 1, 4) as integer) - cast(substr(fp.cohort_month, 1, 4) as integer)) * 12 +
    (cast(substr(ua.activity_month, 6, 2) as integer) - cast(substr(fp.cohort_month, 6, 2) as integer)) as period_number,
    count(distinct fp.customer_unique_id) as retained_users
from first_purchase fp
join user_activities ua on fp.customer_unique_id = ua.customer_unique_id
group by fp.customer_state, fp.cohort_month, period_number
order by fp.customer_state, fp.cohort_month, period_number;


--- Cumulative Items Purchased per User

with first_purchase as (
    select 
        c.customer_unique_id,
        min(o.order_month) as cohort_month
    from olist_customers_dataset c
    join olist_orders_dataset o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id
),
cohort_size as (
    select 
        cohort_month, 
        count(distinct customer_unique_id) as total_users 
    from first_purchase
    group by cohort_month
), 
monthly_items as (
    select 
        fp.cohort_month,
        (cast(substr(o.order_month, 1, 4) as integer) - cast(substr(fp.cohort_month, 1, 4) as integer)) * 12 +
        (cast(substr(o.order_month, 6, 2) as integer) - cast(substr(fp.cohort_month, 6, 2) as integer)) as period_number,
        count(i.order_item_id) as total_items
    from first_purchase fp
    join olist_customers_dataset c on fp.customer_unique_id = c.customer_unique_id
    join olist_orders_dataset o on c.customer_id = o.customer_id
    join olist_order_items_dataset i on o.order_id = i.order_id
    where o.order_status = 'delivered'
    group by fp.cohort_month, period_number
) select 
    m.cohort_month,
    m.period_number,
    round(sum(m.total_items) over (partition by m.cohort_month order by m.period_number) * 1.0 / cs.total_users, 2) as cumulative_items_per_user
from monthly_items m
join cohort_size cs on m.cohort_month = cs.cohort_month
where m.period_number <= 6
order by m.cohort_month, m.period_number;


--- Common Freight Value for Cohort Months
with first_purchase as (
    select 
        c.customer_unique_id,
        min(o.order_month) as cohort_month
    from olist_customers_dataset c
    join olist_orders_dataset o on c.customer_id = o.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id
), 
cohort_size as (
    select 
        cohort_month, 
        count(distinct customer_unique_id) as total_users 
    from first_purchase
    group by cohort_month
), 
monthly_freight as (
    select 
        fp.cohort_month,
        (cast(substr(o.order_month, 1, 4) as integer) - cast(substr(fp.cohort_month, 1, 4) as integer)) * 12 +
        (cast(substr(o.order_month, 6, 2) as integer) - cast(substr(fp.cohort_month, 6, 2) as integer)) as period_number,
        sum(i.freight_value) as total_freight
    from first_purchase fp
    join olist_customers_dataset c on fp.customer_unique_id = c.customer_unique_id
    join olist_orders_dataset o on c.customer_id = o.customer_id
    join olist_order_items_dataset i on o.order_id = i.order_id
    where o.order_status = 'delivered'
    group by fp.cohort_month, period_number
)
select 
    mf.cohort_month,
    mf.period_number,
    round(
        sum(mf.total_freight) over (
            partition by mf.cohort_month 
            order by mf.period_number
        ) * 1.0 / cs.total_users, 
    2) as cumulative_freight_per_user
from monthly_freight mf
join cohort_size cs on mf.cohort_month = cs.cohort_month
where mf.period_number <= 6
order by mf.cohort_month, mf.period_number;
