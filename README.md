# Global Superstore: SQL Server + Power BI Sales & Profit Analysis 📊

An end-to-end analytics project: raw retail data loaded into **SQL Server**, validated and explored with **SQL (CTEs and window functions)**, then turned into a two-page interactive **Power BI** dashboard with custom **DAX** measures.

![Executive Performance](images/page1-executive-performance.png)

![Customer Profit Details](images/page2-customer-details.png)

## Project Workflow

1. **SQL Server / SSMS:** imported the flat file into a `GlobalSuperstore` database (`Sales` table) and fixed column data types.
2. **SQL analysis:** data validation checks, aggregations by category and region, customer ranking with CTEs and window functions.
3. **Power BI:** connected to the SQL Server table, wrote DAX measures and built the dashboard.
4. **Reconciliation:** checked that SQL results match the dashboard KPIs.

## SQL

All queries are in [`sql/GlobalSuperstore_Analysis.sql`](sql/GlobalSuperstore_Analysis.sql):

| Section | What it does |
|---|---|
| 0. Table setup | Converts `Profit`, `Sales`, `Discount` to `float` and `Quantity` to `int` |
| 1. Data cleaning & quality checks | NULL checks, duplicate `Row_ID`, date range and logic, invalid values, text consistency |
| 2-4. Exploration | Row counts, profit by category and region, filtering and `HAVING` |
| 5-6. Window functions | `ROW_NUMBER`, `RANK`, `DENSE_RANK` with `PARTITION BY`, built on a CTE that summarizes each customer |
| 7. Reconciliation | Recomputes the dashboard KPIs in SQL, including year-over-year growth with `LAG` |

The customer CTE works at the **customer-per-region** level, so a customer who buys in several regions appears once per region.

## Data Model

The dashboard uses a single flat table, `Sales`, loaded directly from SQL Server.

## DAX Measures

```DAX
Total Sales = SUM ( Sales[Sales] )

Profit Margin = DIVIDE ( SUM ( Sales[Profit] ), SUM ( Sales[Sales] ) )

YoY Growth % =
VAR LatestYear = MAX ( Sales[Year] )
VAR CurrSales  = CALCULATE ( [Total Sales], Sales[Year] = LatestYear )
VAR PrevSales  = CALCULATE ( [Total Sales], Sales[Year] = LatestYear - 1 )
RETURN
    DIVIDE ( CurrSales - PrevSales, PrevSales )

Customers = DISTINCTCOUNT ( Sales[Customer_Name] )

Loss-Making Customers =
COUNTROWS (
    FILTER ( VALUES ( Sales[Customer_Name] ), [Profit Margin] < 0 )
)

Loss-Making % = DIVIDE ( [Loss-Making Customers], [Customers] )
```

Every measure responds to the Region slicer and to cross-filtering from other visuals. When a region is selected, `Loss-Making Customers` evaluates each customer's margin **within that region**.

## Dashboard Pages

**Page 1: Executive Performance**
- KPI cards: Total Sales, YoY Growth %, Profit Margin, Total Profit, with a Region dropdown
- Profit by Region and Profit Margin by Region (volume vs. margin)
- Sales Trend 2011-2014
- Profit by Category and Sales by Segment

**Page 2: Customer Profit Details**
- Customer table with profit, margin and sales
- Scatter chart of Total Sales vs. Profit Margin per customer, loss-making customers in red
- KPI cards: Customers, Loss-Making Customers, Loss-Making %

## Key Findings

- **Total sales 12.64M**, **total profit 1.47M**, overall **profit margin 11.61%**.
- Sales grew **26.25%** in the latest year (2014 vs. 2013), from 2.3M in 2011 to 4.3M in 2014.
- **Technology** is the most profitable category (~0.66M), followed by Office Supplies and Furniture.
- **Volume is not margin:** Central earns the most profit (0.31M), while **Canada** has the highest margin (26.62%) but one of the smallest profits (0.02M). **Southeast Asia** has the lowest margin (2.02%).
- **67 of 795 customers (8.43%)** are loss-making overall.
- Within regions the picture varies widely: **Africa** has 196 of 754 customers (25.99%) loss-making, versus 83 of 570 (14.56%) in **Central Asia**.

## Repository Structure

```
├── README.md
├── sql/
│   └── GlobalSuperstore_Analysis.sql
├── powerbi/
│   └── Global-Superstore-Dashboard.pbix
└── images/
    ├── page1-executive-performance.png
    └── page2-customer-details.png
```

## How to Open

1. Install [Power BI Desktop](https://powerbi.microsoft.com/desktop/) (free, Windows).
2. Open `powerbi/Global-Superstore-Dashboard.pbix`.
3. To refresh the data, you need the `GlobalSuperstore` database in SQL Server (see the SQL file for the setup).

## Dataset

[Global Superstore Dataset](https://www.kaggle.com/datasets/fatihilhan/global-superstore-dataset) on Kaggle, a sample retail dataset. The raw data file is not included in this repository.

## Tools

SQL Server · SSMS · T-SQL (CTEs, window functions) · Power BI · DAX

## Author

Ata Yılmaz: [LinkedIn](https://www.linkedin.com/in/ata-yilmaz12)
