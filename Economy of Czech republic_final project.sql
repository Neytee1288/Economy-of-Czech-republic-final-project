-- SQL Project - Food availability based on average income in Czech Republic
-- Author: Natalia Hlavacova

-- ============================================================
-- VIEWS
-- ============================================================

-- Average salary by industry and year
CREATE VIEW avg_salaries AS
SELECT 
    payroll_year,
    industry_branch_code,
    cpib.name AS industry_name,
    ROUND(AVG(value)::numeric, 2) AS avg_salary
FROM czechia_payroll cp
LEFT JOIN czechia_payroll_industry_branch cpib
    ON cp.industry_branch_code = cpib.code
WHERE value_type_code = 5958
  AND calculation_code = 100
  AND value IS NOT NULL
GROUP BY payroll_year, industry_branch_code, cpib.name;


-- Average food prices by category and year
CREATE VIEW avg_prices AS
SELECT 
    DATE_PART('year', date_from)::int AS price_year,
    category_code,
    cpc.name AS food_name,
    cpc.price_value,
    cpc.price_unit,
    ROUND(AVG(value)::numeric, 2) AS avg_price
FROM czechia_price cp
JOIN czechia_price_category cpc
    ON cp.category_code = cpc.code
WHERE region_code IS NULL
  AND value IS NOT NULL
GROUP BY DATE_PART('year', date_from), category_code, cpc.name, cpc.price_value, cpc.price_unit;


-- ============================================================
-- PRIMARY TABLE
-- Salaries and food prices for comparable period (2006-2018)
-- ============================================================

CREATE TABLE t_natalia_hlavacova_project_SQL_primary_final AS
SELECT 
    sal.payroll_year AS year,
    sal.industry_branch_code,
    sal.industry_name,
    sal.avg_salary,
    pr.category_code,
    pr.food_name,
    pr.price_value,
    pr.price_unit,
    pr.avg_price
FROM avg_salaries sal
JOIN avg_prices pr
    ON sal.payroll_year = pr.price_year
WHERE sal.payroll_year BETWEEN 2006 AND 2018;


-- ============================================================
-- SECONDARY TABLE
-- GDP, GINI and population of European countries (2006-2018)
-- ============================================================

CREATE TABLE t_natalia_hlavacova_project_SQL_secondary_final AS
SELECT 
    e.country,
    e.year,
    e.gdp,
    e.gini,
    e.population
FROM economies e
JOIN countries c
    ON e.country = c.country
WHERE c.continent = 'Europe'
  AND e.year BETWEEN 2006 AND 2018;


-- ============================================================
-- QUESTION 1: Do wages grow in all industries or do some decline?
-- ============================================================

-- Full overview with year-over-year comparison
SELECT 
    t1.industry_name,
    t2.payroll_year AS year_prev,
    t1.payroll_year AS year_curr,
    t2.avg_salary AS salary_prev,
    t1.avg_salary AS salary_curr,
    ROUND((t1.avg_salary - t2.avg_salary)::numeric, 2) AS salary_diff,
    CASE 
        WHEN t1.avg_salary > t2.avg_salary THEN 'growth'
        WHEN t1.avg_salary < t2.avg_salary THEN 'decline'
        ELSE 'no change'
    END AS trend
FROM avg_salaries t1
JOIN avg_salaries t2
    ON t1.industry_branch_code = t2.industry_branch_code
   AND t1.payroll_year = t2.payroll_year + 1
WHERE t1.industry_branch_code IS NOT NULL
  AND t1.payroll_year BETWEEN 2006 AND 2018
ORDER BY t1.industry_name, t1.payroll_year;

-- Only years with salary decline
SELECT 
    t1.industry_name,
    t1.payroll_year AS year_of_decline,
    t2.avg_salary AS salary_prev,
    t1.avg_salary AS salary_curr,
    ROUND(((t1.avg_salary - t2.avg_salary) / t2.avg_salary * 100)::numeric, 2) AS pct_change
FROM avg_salaries t1
JOIN avg_salaries t2
    ON t1.industry_branch_code = t2.industry_branch_code
   AND t1.payroll_year = t2.payroll_year + 1
WHERE t1.avg_salary < t2.avg_salary
  AND t1.industry_branch_code IS NOT NULL
  AND t1.payroll_year BETWEEN 2006 AND 2018
ORDER BY t1.payroll_year, t1.industry_name;


-- ============================================================
-- QUESTION 2: How many liters of milk and kg of bread can be
--             bought for average salary in first and last period?
-- ============================================================

WITH avg_salary_all AS (
    SELECT 
        payroll_year,
        ROUND(AVG(avg_salary)::numeric, 2) AS overall_salary
    FROM avg_salaries
    WHERE industry_branch_code IS NOT NULL
    GROUP BY payroll_year
),
food AS (
    SELECT 
        price_year,
        food_name,
        price_unit,
        avg_price
    FROM avg_prices
    WHERE category_code IN (114201, 111301)
)
SELECT 
    s.payroll_year AS year,
    f.food_name,
    f.price_unit,
    s.overall_salary,
    f.avg_price,
    FLOOR(s.overall_salary / f.avg_price) AS purchasable_amount
FROM avg_salary_all s
JOIN food f
    ON s.payroll_year = f.price_year
WHERE s.payroll_year IN (2006, 2018)
ORDER BY f.food_name, s.payroll_year;


-- ============================================================
-- QUESTION 3: Which food category has the slowest price growth?
-- ============================================================

WITH yearly_prices AS (
    SELECT 
        category_code,
        food_name,
        price_year,
        avg_price,
        LAG(avg_price) OVER (PARTITION BY category_code ORDER BY price_year) AS prev_price
    FROM avg_prices
),
yearly_changes AS (
    SELECT 
        category_code,
        food_name,
        price_year,
        ROUND(((avg_price - prev_price) / prev_price * 100)::numeric, 2) AS pct_change
    FROM yearly_prices
    WHERE prev_price IS NOT NULL
)
SELECT 
    food_name,
    ROUND(AVG(pct_change)::numeric, 2) AS avg_annual_pct_change
FROM yearly_changes
GROUP BY category_code, food_name
ORDER BY avg_annual_pct_change ASC
LIMIT 5;


-- ============================================================
-- QUESTION 4: Is there a year where food price growth was
--             significantly higher than salary growth (>10%)?
-- ============================================================

WITH salary_by_year AS (
    SELECT 
        payroll_year AS year,
        ROUND(AVG(avg_salary)::numeric, 2) AS avg_salary
    FROM avg_salaries
    WHERE industry_branch_code IS NOT NULL
    GROUP BY payroll_year
),
salary_change AS (
    SELECT 
        year,
        avg_salary,
        LAG(avg_salary) OVER (ORDER BY year) AS prev_salary,
        ROUND(((avg_salary - LAG(avg_salary) OVER (ORDER BY year)) 
            / LAG(avg_salary) OVER (ORDER BY year) * 100)::numeric, 2) AS salary_pct
    FROM salary_by_year
),
price_by_year AS (
    SELECT 
        price_year AS year,
        ROUND(AVG(avg_price)::numeric, 2) AS avg_price
    FROM avg_prices
    GROUP BY price_year
),
price_change AS (
    SELECT 
        year,
        avg_price,
        LAG(avg_price) OVER (ORDER BY year) AS prev_price,
        ROUND(((avg_price - LAG(avg_price) OVER (ORDER BY year)) 
            / LAG(avg_price) OVER (ORDER BY year) * 100)::numeric, 2) AS price_pct
    FROM price_by_year
)
SELECT 
    s.year,
    s.salary_pct,
    p.price_pct,
    ROUND((p.price_pct - s.salary_pct)::numeric, 2) AS difference
FROM salary_change s
JOIN price_change p ON s.year = p.year
WHERE s.salary_pct IS NOT NULL
  AND p.price_pct IS NOT NULL
ORDER BY difference DESC;


-- ============================================================
-- QUESTION 5: Does GDP affect salary and food price changes?
-- ============================================================

WITH gdp_data AS (
    SELECT 
        year,
        gdp,
        LAG(gdp) OVER (ORDER BY year) AS prev_gdp,
        ROUND(((gdp - LAG(gdp) OVER (ORDER BY year)) 
            / LAG(gdp) OVER (ORDER BY year) * 100)::numeric, 2) AS gdp_pct
    FROM economies
    WHERE country = 'Czech Republic'
      AND year BETWEEN 2006 AND 2018
),
salary_by_year AS (
    SELECT 
        payroll_year AS year,
        ROUND(AVG(avg_salary)::numeric, 2) AS avg_salary
    FROM avg_salaries
    WHERE industry_branch_code IS NOT NULL
    GROUP BY payroll_year
),
salary_change AS (
    SELECT 
        year,
        ROUND(((avg_salary - LAG(avg_salary) OVER (ORDER BY year)) 
            / LAG(avg_salary) OVER (ORDER BY year) * 100)::numeric, 2) AS salary_pct
    FROM salary_by_year
),
price_by_year AS (
    SELECT 
        price_year AS year,
        ROUND(AVG(avg_price)::numeric, 2) AS avg_price
    FROM avg_prices
    GROUP BY price_year
),
price_change AS (
    SELECT 
        year,
        ROUND(((avg_price - LAG(avg_price) OVER (ORDER BY year)) 
            / LAG(avg_price) OVER (ORDER BY year) * 100)::numeric, 2) AS price_pct
    FROM price_by_year
)
SELECT 
    g.year,
    g.gdp_pct,
    s.salary_pct,
    p.price_pct,
    LEAD(s.salary_pct) OVER (ORDER BY g.year) AS salary_pct_next_year,
    LEAD(p.price_pct) OVER (ORDER BY g.year) AS price_pct_next_year
FROM gdp_data g
LEFT JOIN salary_change s ON g.year = s.year
LEFT JOIN price_change p ON g.year = p.year
WHERE g.prev_gdp IS NOT NULL
ORDER BY g.year;
