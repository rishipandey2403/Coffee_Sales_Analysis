-- Monday Coffee Analysis

SELECT * FROM city;
SELECT * FROM products;
SELECT * FROM customers;
SELECT * FROM sales;

-- Reports & Analysis

-- 1) Coffee Consumers Count
-- How many people in each city consume coffee, given that 25% of population consume coffee
SELECT
	city_name as "City",
	Round((population*0.25)/1000000,2) as "Coffee Consumers in Millions",
	city_rank as "City Rank"
FROM city
ORDER BY 2 DESC;

-- 2) Total Revenue From Coffee Sales
-- What is total revenue generated from coffee sales last across all cities in last quarter of 2023
SELECT
	ci.city_name as "City",
	sum(total) as "Total Revenue"
FROM sales as s
JOIN customers as c ON c.customer_id = s.customer_id
JOIN city as ci ON ci.city_id = c.city_id
WHERE 
	  extract(Quarter from sale_date) = 4 
	  and
	  extract(Year from sale_date) = 2023
GROUP BY 1;

-- 3) Sales Count For Each Product
-- For Each Coffee Product How many units have been sold
SELECT
	p.product_name as "Coffe Name",
	count(*) as Total
FROM SALES as s
LEFT JOIN products as p
on s.product_id=p.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- 4) Average Sales Amount per City
-- What is the average sales amount per customer in each city
SELECT
	ci.city_name as "City",
	sum(total) as "Total_Revenue",
	count(distinct c.customer_id) as "Total Customers",
	ROUND(
		sum(total)::numeric/
		count(distinct c.customer_id)::numeric
	,2) as Average_Sales_Per_Customer
FROM sales as s
JOIN customers as c ON c.customer_id = s.customer_id
JOIN city as ci ON ci.city_id = c.city_id
GROUP BY 1
ORDER BY 4;

-- 5) City Population and Coffee Consumers
-- Provide a list of cities along with their populations and estimated coffee consumers.
WITH City_Table as 
(
	SELECT
		city_name,
		Round((population * 0.25)/1000000,2) as Coffee_Consumers
	FROM city
),
Customer_table
as
(SELECT
	ci.city_name,
	count(distinct c.customer_id) as unique_cx
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON c.city_id = ci.city_id
GROUP BY 1
)
SELECT
	City_Table.city_name,
	City_Table.Coffee_Consumers as "Consumers in Millions",
	Customer_table.unique_cx as "Unique Customers"
FROM City_Table 
JOIN Customer_table 
on City_Table.city_name=Customer_table.city_name;

-- 6) Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?
SELECT
	*
FROM
(SELECT
	ci.city_name,
	p.product_name,
	count(s.sale_id) as total_orders,
	Dense_Rank() over(partition by ci.city_name order by count(s.sale_id) desc) as rank
FROM sales as s
JOIN products as p
ON p.product_id = s.product_id
JOIN customers as c
ON c.customer_id = s.customer_id
JOIN city as ci
ON ci.city_id = c.city_id
GROUP BY 1,2) as t1
WHERE rank<=3

-- 7) Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products
SELECT
	ci.city_name as City,
	count(DISTINCT c.customer_id) as Customer_Count
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON c.city_id = ci.city_id
WHERE 
	s.product_id in (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
GROUP BY 1
ORDER BY 2 DESC

-- 8) Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer
WITH city_table
as
(
	SELECT
		ci.city_name as City,
		ROUND(
			sum(total)::numeric/
			count(distinct c.customer_id)::numeric
		,2) as Average_Sales_Per_Customer,
		count(DISTINCT c.customer_id) as Customer_Count
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2 DESC
),
city_rent
AS
(
	SELECT
		city_name,
		estimated_rent
	FROM city
)

SELECT
	cr.city_name,
	cr.estimated_rent,
	ct.Customer_Count,
	ct.Average_Sales_Per_Customer,
	ROUND(cr.estimated_rent::numeric/ct.Customer_Count::numeric,2) as Average_rent_Per_Customer
FROM city_rent as cr
JOIN city_table as ct ON
cr.city_name=ct.City
ORDER BY 4 DESC,5 DESC

-- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city

WITH
monthly_sales
AS
(
	SELECT 
		ci.city_name,
		EXTRACT(MONTH FROM sale_date) as month,
		EXTRACT(YEAR FROM sale_date) as YEAR,
		SUM(s.total) as total_sale
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1, 2, 3
	ORDER BY 1, 3, 2
),
growth_ratio
AS
(
		SELECT
			city_name,
			month,
			year,
			total_sale as cr_month_sale,
			LAG(total_sale, 1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sale
		FROM monthly_sales
)

SELECT
	city_name,
	month,
	year,
	cr_month_sale,
	last_month_sale,
	ROUND(
		(cr_month_sale-last_month_sale)::numeric/last_month_sale::numeric * 100
		, 2
		) as growth_ratio

FROM growth_ratio
WHERE 
	last_month_sale IS NOT NULL	

-- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

WITH city_table
AS
(
	SELECT 
		ci.city_name,
		SUM(s.total) as total_revenue,
		COUNT(DISTINCT s.customer_id) as total_cx,
		ROUND(
				SUM(s.total)::numeric/
					COUNT(DISTINCT s.customer_id)::numeric
				,2) as avg_sale_pr_cx
		
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2 DESC
),
city_rent
AS
(
	SELECT 
		city_name, 
		estimated_rent,
		ROUND((population * 0.25)/1000000, 3) as estimated_coffee_consumer_in_millions
	FROM city
)
SELECT 
	cr.city_name,
	total_revenue,
	cr.estimated_rent as total_rent,
	ct.total_cx,
	estimated_coffee_consumer_in_millions,
	ct.avg_sale_pr_cx,
	ROUND(
		cr.estimated_rent::numeric/
									ct.total_cx::numeric
		, 2) as avg_rent_per_cx
FROM city_rent as cr
JOIN city_table as ct
ON cr.city_name = ct.city_name
ORDER BY 2 DESC