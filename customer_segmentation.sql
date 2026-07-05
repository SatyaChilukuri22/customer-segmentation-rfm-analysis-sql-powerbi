-- ==========================================
-- CUSTOMER SEGMENTATION PROJECT (RFM ANALYSIS)
-- Tech Stack: PostgreSQL + Power BI
-- ==========================================

-- ==========================================
-- 1. CREATE RAW TABLE
-- ==========================================


CREATE TABLE online_retail (

    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description TEXT,
    Quantity INT,
    InvoiceDate VARCHAR(50),
    UnitPrice DECIMAL(10,2),
    CustomerID INT,
    Country VARCHAR(100)

);

-- ==========================================
-- 2. DATA EXPLORATION
-- ==========================================

-- Total Transactions
SELECT COUNT(*)
FROM online_retail;


-- Missing Customer IDs

SELECT COUNT(*)
FROM online_retail
WHERE customerID IS NULL;


-- Unique Customers
SELECT COUNT(DISTINCT customerid) AS unique_customers
FROM online_retail
WHERE customerid IS NOT NULL;


-- Transactions by Country
SELECT
    country,
    COUNT(*) AS transactions
FROM online_retail
GROUP BY country
ORDER BY transactions DESC;

-- ==========================================
-- 3. DATA CLEANING
-- Remove:
-- Null Customers
-- Returns/Cancellations
-- Invalid Quantity
-- Invalid Price
-- ==========================================


-- Create Clean Transaction Table
CREATE TABLE retail_clean AS

SELECT
    invoiceno,
    stockcode,
    description,
    quantity,

    TO_TIMESTAMP(
        invoicedate,
        'MM/DD/YYYY HH24:MI'
    ) AS invoicedate,

    unitprice,

    customerid,

    country,

    quantity * unitprice AS revenue

FROM online_retail

WHERE customerid IS NOT NULL
  AND quantity > 0
  AND unitprice > 0
  AND invoiceno NOT LIKE 'C%';

-- Verify Clean Data

SELECT *
FROM retail_clean
LIMIT 5;

-- ==========================================
-- 4. RFM METRIC CALCULATION
-- R = Recency
-- F = Frequency
-- M = Monetary
-- ==========================================

-- Create Customer Level Metrics Using CTE

CREATE TABLE customer_rfm AS

WITH customer_metrics AS (
    SELECT
        customerid,
        MAX(invoicedate) AS last_purchase,
        COUNT(DISTINCT invoiceno) AS frequency,
        ROUND(SUM(revenue),2) AS monetary
    FROM retail_clean
    GROUP BY customerid
)

SELECT
    customerid,
    DATE '2011-12-10' - last_purchase::date AS recency,
    frequency,
    monetary
FROM customer_metrics;

-- View Customer Metrics

SELECT *
FROM customer_rfm
LIMIT 10;


-- ==========================================
-- 5. RFM SCORING
-- Window Function: NTILE()
-- ==========================================

DROP TABLE IF EXISTS rfm_scores;

CREATE TABLE rfm_scores AS

SELECT

    customerid,
    recency,
    frequency,
    monetary,

    NTILE(5) OVER (
        ORDER BY recency ASC
    ) AS r_score,

    NTILE(5) OVER (
        ORDER BY frequency ASC
    ) AS f_score,

    NTILE(5) OVER (
        ORDER BY monetary ASC
    ) AS m_score

FROM customer_rfm;

-- View RFM Scores

SELECT *
FROM rfm_scores
LIMIT 10;


-- ==========================================
-- 6. CUSTOMER SEGMENTATION
-- CASE Statement
-- ==========================================

DROP TABLE IF EXISTS customer_segments;

CREATE TABLE customer_segments AS

SELECT

    *,

    CONCAT(
        r_score,
        f_score,
        m_score
    ) AS rfm_score,

    CASE

        WHEN r_score >= 4
         AND f_score >= 4
         AND m_score >= 4
        THEN 'Champions'

        WHEN r_score >= 3
         AND f_score >= 4
        THEN 'Loyal Customers'

        WHEN r_score >= 4
         AND f_score <= 2
        THEN 'Potential Loyalists'

        WHEN r_score <= 2
         AND f_score >= 3
        THEN 'At Risk'

        WHEN m_score >= 4
        THEN 'Big Spenders'

        ELSE 'Regular Customers'

    END AS segment

FROM rfm_scores;

-- Segment Distribution

SELECT

    segment,

    COUNT(*) AS customer_count

FROM customer_segments

GROUP BY segment

ORDER BY customer_count DESC;

-- ==========================================
-- 7. BUSINESS INSIGHTS
-- ==========================================

-- Revenue by Segment (JOIN)

SELECT

    cs.segment,

    COUNT(DISTINCT rc.customerid) AS customers,

    ROUND(SUM(rc.revenue),2) AS total_revenue,

    ROUND(AVG(rc.revenue),2) AS avg_order_value

FROM customer_segments cs

JOIN retail_clean rc
ON cs.customerid = rc.customerid

GROUP BY cs.segment

ORDER BY total_revenue DESC;


-- Top 10 Customers (RANK Window Function)

WITH ranked_customers AS (

    SELECT

        customerid,

        monetary,

        RANK() OVER (
            ORDER BY monetary DESC
        ) AS customer_rank

    FROM customer_rfm

)

SELECT *

FROM ranked_customers

WHERE customer_rank <= 10;

-- Monthly Revenue Trend

SELECT

    DATE_TRUNC('month', invoicedate) AS month,

    ROUND(SUM(revenue),2) AS revenue

FROM retail_clean

GROUP BY month

ORDER BY month;

-- Top Products

SELECT

    description,

    SUM(quantity) AS quantity_sold,

    ROUND(SUM(revenue),2) AS total_revenue

FROM retail_clean

GROUP BY description

ORDER BY total_revenue DESC

LIMIT 10;

-- Revenue by Country

SELECT

    country,

    ROUND(SUM(revenue),2) AS revenue

FROM retail_clean

GROUP BY country

ORDER BY revenue DESC;

-- ==========================================
-- 8. ADVANCED SQL ANALYSIS
-- ==========================================
-- Customers with More Than 10 Orders (HAVING)

SELECT

    customerid,

    COUNT(DISTINCT invoiceno) AS total_orders,

    ROUND(SUM(revenue),2) AS total_spent

FROM retail_clean

GROUP BY customerid

HAVING COUNT(DISTINCT invoiceno) > 10

ORDER BY total_spent DESC;

-- Month-over-Month Revenue Growth (LAG)

WITH monthly_revenue AS (

    SELECT

        DATE_TRUNC('month', invoicedate) AS month,

        ROUND(SUM(revenue),2) AS revenue

    FROM retail_clean

    GROUP BY month

)

SELECT

    month,

    revenue,

    LAG(revenue) OVER(
        ORDER BY month
    ) AS previous_month_revenue,

    ROUND(
        revenue -
        LAG(revenue) OVER(
            ORDER BY month
        ),
        2
    ) AS revenue_growth

FROM monthly_revenue

ORDER BY month;

-- Top Customers by Revenue

SELECT
    customerid,
    monetary,

    DENSE_RANK() OVER(
        ORDER BY monetary DESC
    ) AS revenue_rank

FROM customer_rfm;

SELECT *
FROM customer_segments;