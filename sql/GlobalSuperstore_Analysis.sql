-- ============================================================================
-- PROJECT : Global Superstore Sales & Profit Analysis
-- DATABASE: GlobalSuperstore (SQL Server)   TABLE: Sales
-- CONTENTS:
--   0. Table setup (data types)
--   1. Data cleaning & quality checks
--   2. Basic data exploration
--   3. Performance by category and region
--   4. Filtering and HAVING examples
--   5. Window function: ROW_NUMBER
--   6. CTE + window functions: customer ranking (overall and per region)
--   7. Reconciliation with the Power BI dashboard
-- Run the sections one by one in SSMS (select a block, press F5).
-- ============================================================================

USE GlobalSuperstore;
GO

-- ============================================================================
-- SECTION 0: TABLE SETUP - DATA TYPE FIXES
-- ============================================================================

-- Convert numeric columns to proper data types after the flat file import
ALTER TABLE Sales ALTER COLUMN Profit   float;
ALTER TABLE Sales ALTER COLUMN Sales    float;
ALTER TABLE Sales ALTER COLUMN Discount float;
ALTER TABLE Sales ALTER COLUMN Quantity int;

-- Verify the final column data types
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Sales';

-- ============================================================================
-- SECTION 1: DATA CLEANING & QUALITY CHECKS
-- Review the output of each check. If a check returns problem rows, fix them
-- with UPDATE / DELETE and document the fix right below the check.
-- ============================================================================

-- 1.1 Missing values in key columns (every count should be 0)
SELECT
    SUM(CASE WHEN Row_ID        IS NULL THEN 1 ELSE 0 END) AS Null_Row_ID,
    SUM(CASE WHEN Order_ID      IS NULL THEN 1 ELSE 0 END) AS Null_Order_ID,
    SUM(CASE WHEN Order_Date    IS NULL THEN 1 ELSE 0 END) AS Null_Order_Date,
    SUM(CASE WHEN Customer_Name IS NULL THEN 1 ELSE 0 END) AS Null_Customer_Name,
    SUM(CASE WHEN Region        IS NULL THEN 1 ELSE 0 END) AS Null_Region,
    SUM(CASE WHEN Category      IS NULL THEN 1 ELSE 0 END) AS Null_Category,
    SUM(CASE WHEN Sales         IS NULL THEN 1 ELSE 0 END) AS Null_Sales,
    SUM(CASE WHEN Profit        IS NULL THEN 1 ELSE 0 END) AS Null_Profit
FROM Sales;

-- 1.2 Duplicate rows: Row_ID should be unique (no rows expected)
SELECT Row_ID, COUNT(*) AS Occurrences
FROM Sales
GROUP BY Row_ID
HAVING COUNT(*) > 1;

-- 1.3 Date range and date logic
SELECT MIN(Order_Date) AS First_Order, MAX(Order_Date) AS Last_Order
FROM Sales;

-- Orders shipped before they were ordered (no rows expected)
SELECT COUNT(*) AS Ship_Before_Order
FROM Sales
WHERE Ship_Date < Order_Date;

-- 1.4 Invalid numeric values (no rows expected)
SELECT COUNT(*) AS Invalid_Rows
FROM Sales
WHERE Sales <= 0
   OR Quantity <= 0
   OR Discount < 0
   OR Discount > 1;

-- 1.5 Text consistency: stray spaces in names (no rows expected)
SELECT COUNT(*) AS Untrimmed_Names
FROM Sales
WHERE Customer_Name <> LTRIM(RTRIM(Customer_Name))
   OR Region        <> LTRIM(RTRIM(Region))
   OR Category      <> LTRIM(RTRIM(Category));

-- 1.6 Distinct values of categorical columns (look for typos or duplicates)
SELECT Region,   COUNT(*) AS Row_Count FROM Sales GROUP BY Region   ORDER BY Region;
SELECT Segment,  COUNT(*) AS Row_Count FROM Sales GROUP BY Segment  ORDER BY Segment;
SELECT Category, COUNT(*) AS Row_Count FROM Sales GROUP BY Category ORDER BY Category;

-- ============================================================================
-- SECTION 2: BASIC DATA EXPLORATION
-- ============================================================================

-- Check the total number of rows in the table
SELECT COUNT(*) AS Total_Rows
FROM Sales;

-- Inspect the first rows to understand the structure of the data
SELECT TOP 100 *
FROM Sales;

-- ============================================================================
-- SECTION 3: PERFORMANCE BY CATEGORY AND REGION (before building Power BI charts)
-- ============================================================================

-- Which product category generates the most profit?
SELECT
    Category,
    ROUND(SUM(Sales), 2)  AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit
FROM Sales
GROUP BY Category
ORDER BY Total_Profit DESC;

-- Which regions drive the company's profit?
SELECT
    Region,
    ROUND(SUM(Sales), 2)  AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit
FROM Sales
GROUP BY Region
ORDER BY Total_Profit DESC;

-- ============================================================================
-- SECTION 4: FILTERING AND HAVING EXAMPLES
-- ============================================================================

-- Total profit by category, United States only
SELECT SUM(Profit) AS Total_Profit, Category
FROM Sales
WHERE Country = 'United States'
GROUP BY Category
ORDER BY Total_Profit DESC;

-- Categories with total profit above 500,000
SELECT SUM(Profit) AS Total_Profit, Category
FROM Sales
GROUP BY Category
HAVING SUM(Profit) > 500000;

-- ============================================================================
-- SECTION 5: WINDOW FUNCTION - ROW_NUMBER
-- ============================================================================

-- Rank each product row by profit within its category
SELECT Product_Name, Category, Profit,
       ROW_NUMBER() OVER (
           PARTITION BY Category
           ORDER BY Profit DESC
       ) AS Category_Profit
FROM Sales;

-- ============================================================================
-- SECTION 6: ADVANCED ANALYSIS - CTE & WINDOW FUNCTIONS
-- Top customers by profit: overall rank and rank within each region
-- ============================================================================

WITH Customer_Total_Profit AS (
    -- Grain: one row per customer per region
    SELECT
        Customer_Name,
        Region,
        SUM(Sales)  AS Total_Sales,
        SUM(Profit) AS Total_Profit
    FROM Sales
    GROUP BY Customer_Name, Region
)
SELECT
    Customer_Name,
    Region,
    ROUND(Total_Sales, 2)  AS Total_Sales,
    ROUND(Total_Profit, 2) AS Total_Profit,
    -- Top customers within each region
    DENSE_RANK() OVER (PARTITION BY Region ORDER BY Total_Profit DESC) AS Regional_Rank,
    -- Top customers across the whole company
    RANK() OVER (ORDER BY Total_Profit DESC) AS Overall_Rank
FROM Customer_Total_Profit
WHERE Total_Profit > 0 -- Exclude loss-making customers
ORDER BY Overall_Rank;

-- ============================================================================
-- SECTION 7: RECONCILIATION WITH THE POWER BI DASHBOARD
-- The results below should match the dashboard KPIs.
-- ============================================================================

-- 7.1 Overall KPIs (dashboard: Total Sales 12.64M, Total Profit 1.47M, Profit Margin 11.61%)
SELECT
    ROUND(SUM(Sales), 2)                     AS Total_Sales,
    ROUND(SUM(Profit), 2)                    AS Total_Profit,
    ROUND(100.0 * SUM(Profit) / SUM(Sales), 2) AS Profit_Margin_Pct
FROM Sales;

-- 7.2 Customers (dashboard: Customers 795, Loss-Making Customers 67, Loss-Making % 8.43%)
SELECT
    COUNT(*) AS Customers,
    SUM(CASE WHEN Total_Profit < 0 THEN 1 ELSE 0 END) AS Loss_Making_Customers,
    ROUND(100.0 * SUM(CASE WHEN Total_Profit < 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS Loss_Making_Pct
FROM (
    SELECT Customer_Name, SUM(Profit) AS Total_Profit
    FROM Sales
    GROUP BY Customer_Name
) AS Customer_Profit;

-- 7.3 Profit margin by region (dashboard: Canada 26.62% ... Southeast Asia 2.02%)
SELECT
    Region,
    ROUND(100.0 * SUM(Profit) / SUM(Sales), 2) AS Profit_Margin_Pct
FROM Sales
GROUP BY Region
ORDER BY Profit_Margin_Pct DESC;

-- 7.4 Year-over-year sales growth with LAG (dashboard: YoY Growth 26.25%, latest year vs previous)
WITH Yearly_Sales AS (
    SELECT YEAR(Order_Date) AS Order_Year, SUM(Sales) AS Total_Sales
    FROM Sales
    GROUP BY YEAR(Order_Date)
)
SELECT
    Order_Year,
    ROUND(Total_Sales, 2) AS Total_Sales,
    ROUND(LAG(Total_Sales) OVER (ORDER BY Order_Year), 2) AS Prev_Year_Sales,
    ROUND(100.0 * (Total_Sales - LAG(Total_Sales) OVER (ORDER BY Order_Year))
          / LAG(Total_Sales) OVER (ORDER BY Order_Year), 2) AS YoY_Growth_Pct
FROM Yearly_Sales
ORDER BY Order_Year;
