CREATE VIEW v_payroll_avg AS
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

CREATE v_price_avg AS
SELECT 
    EXTRACT(YEAR FROM date_from)::int AS price_year,
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
GROUP BY EXTRACT(YEAR FROM date_from), category_code, cpc.name, cpc.price_value, cpc.price_unit;


CREATE TABLE t_natalia_hlavacova_project_SQL_primary_final AS
SELECT 
    vpa.payroll_year AS year,
    vpa.industry_branch_code,
    vpa.industry_name,
    vpa.avg_salary,
    vpr.category_code,
    vpr.food_name,
    vpr.price_value,
    vpr.price_unit,
    vpr.avg_price
FROM v_payroll_avg vpa
JOIN v_price_avg vpr
    ON vpa.payroll_year = vpr.price_year
WHERE vpa.payroll_year BETWEEN 2006 AND 2018;

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

SELECT 
    curr.industry_name,
    prev.payroll_year AS year_prev,
    curr.payroll_year AS year_curr,
    prev.avg_salary AS salary_prev,
    curr.avg_salary AS salary_curr,
    ROUND((curr.avg_salary - prev.avg_salary)::numeric, 2) AS salary_diff,
    CASE 
        WHEN curr.avg_salary > prev.avg_salary THEN 'rast'
        WHEN curr.avg_salary < prev.avg_salary THEN 'pokles'
        ELSE 'bez zmeny'
    END AS trend
FROM v_payroll_avg curr
JOIN v_payroll_avg prev
    ON curr.industry_branch_code = prev.industry_branch_code
   AND curr.payroll_year = prev.payroll_year + 1
WHERE curr.industry_branch_code IS NOT NULL
  AND curr.payroll_year BETWEEN 2006 AND 2018
ORDER BY curr.industry_name, curr.payroll_year;

SELECT 
    curr.industry_name,
    curr.payroll_year AS year_of_decline,
    prev.avg_salary AS salary_prev,
    curr.avg_salary AS salary_curr,
    ROUND(((curr.avg_salary - prev.avg_salary) / prev.avg_salary * 100)::numeric, 2) AS pct_change
FROM v_payroll_avg curr
JOIN v_payroll_avg prev
    ON curr.industry_branch_code = prev.industry_branch_code
   AND curr.payroll_year = prev.payroll_year + 1
WHERE curr.avg_salary < prev.avg_salary
  AND curr.industry_branch_code IS NOT NULL
  AND curr.payroll_year BETWEEN 2006 AND 2018
ORDER BY curr.payroll_year, curr.industry_name;

WITH overall_avg_salary AS (
    SELECT 
        payroll_year,
        ROUND(AVG(avg_salary)::numeric, 2) AS overall_salary
    FROM v_payroll_avg
    WHERE industry_branch_code IS NOT NULL
    GROUP BY payroll_year
),
food_prices AS (
    SELECT 
        price_year,
        food_name,
        price_unit,
        avg_price
    FROM v_price_avg
    WHERE category_code IN (114201, 111301)
)
SELECT 
    oas.payroll_year AS year,
    fp.food_name,
    fp.price_unit,
    oas.overall_salary,
    fp.avg_price,
    FLOOR(oas.overall_salary / fp.avg_price) AS purchasable_amount
FROM overall_avg_salary oas
JOIN food_prices fp
    ON oas.payroll_year = fp.price_year
WHERE oas.payroll_year IN (2006, 2018)
ORDER BY fp.food_name, oas.payroll_year;


WITH yearly_prices AS (
    SELECT 
        category_code,
        food_name,
        price_year,
        avg_price,
        LAG(avg_price) OVER (PARTITION BY category_code ORDER BY price_year) AS prev_price
    FROM v_price_avg
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

WITH salary_growth AS (
    SELECT 
        payroll_year AS year,
        ROUND(AVG(avg_salary)::numeric, 2) AS avg_salary
    FROM v_payroll_avg
    WHERE industry_branch_code IS NOT NULL
    GROUP BY payroll_year
),
salary_yoy AS (
    SELECT 
        year,
        avg_salary,
        LAG(avg_salary) OVER (ORDER BY year) AS prev_salary,
        ROUND(((avg_salary - LAG(avg_salary) OVER (ORDER BY year)) 
            / LAG(avg_salary) OVER (ORDER BY year) * 100)::numeric, 2) AS salary_pct_change
    FROM salary_growth
),
price_growth AS (
    SELECT 
        price_year AS year,
        ROUND(AVG(avg_price)::numeric, 2) AS avg_price
    FROM v_price_avg
    GROUP BY price_year
),
price_yoy AS (
    SELECT 
        year,
        avg_price,
        LAG(avg_price) OVER (ORDER BY year) AS prev_price,
        ROUND(((avg_price - LAG(avg_price) OVER (ORDER BY year)) 
            / LAG(avg_price) OVER (ORDER BY year) * 100)::numeric, 2) AS price_pct_change
    FROM price_growth
)
SELECT 
    s.year,
    s.salary_pct_change,
    p.price_pct_change,
    ROUND((p.price_pct_change - s.salary_pct_change)::numeric, 2) AS difference
FROM salary_yoy s
JOIN price_yoy p ON s.year = p.year
WHERE s.salary_pct_change IS NOT NULL
  AND p.price_pct_change IS NOT NULL
ORDER BY difference DESC;

WITH gdp_cz AS (
    SELECT 
        year,
        gdp,
        LAG(gdp) OVER (ORDER BY year) AS prev_gdp,
        ROUND(((gdp - LAG(gdp) OVER (ORDER BY year)) 
            / LAG(gdp) OVER (ORDER BY year) * 100)::numeric, 2) AS gdp_pct_change
    FROM economies
    WHERE country = 'Czech Republic'
      AND year BETWEEN 2006 AND 2018
),
salary_growth AS (
    SELECT 
        payroll_year AS year,
        ROUND(AVG(avg_salary)::numeric, 2) AS avg_salary
    FROM v_payroll_avg
    WHERE industry_branch_code IS NOT NULL
    GROUP BY payroll_year
),
salary_yoy AS (
    SELECT 
        year,
        ROUND(((avg_salary - LAG(avg_salary) OVER (ORDER BY year)) 
            / LAG(avg_salary) OVER (ORDER BY year) * 100)::numeric, 2) AS salary_pct_change
    FROM salary_growth
),
price_growth AS (
    SELECT 
        price_year AS year,
        ROUND(AVG(avg_price)::numeric, 2) AS avg_price
    FROM v_price_avg
    GROUP BY price_year
),
price_yoy AS (
    SELECT 
        year,
        ROUND(((avg_price - LAG(avg_price) OVER (ORDER BY year)) 
            / LAG(avg_price) OVER (ORDER BY year) * 100)::numeric, 2) AS price_pct_change
    FROM price_growth
)
SELECT 
    g.year,
    g.gdp_pct_change,
    s.salary_pct_change,
    p.price_pct_change,
    LEAD(s.salary_pct_change) OVER (ORDER BY g.year) AS salary_pct_next_year,
    LEAD(p.price_pct_change) OVER (ORDER BY g.year) AS price_pct_next_year
FROM gdp_cz g
LEFT JOIN salary_yoy s ON g.year = s.year
LEFT JOIN price_yoy p ON g.year = p.year
WHERE g.prev_gdp IS NOT NULL
ORDER BY g.year;
