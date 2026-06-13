USE coffeeshop_db;

-- =========================================================
-- ADVANCED SQL ASSIGNMENT
-- Subqueries, CTEs, Window Functions, Views
-- =========================================================
-- Notes:
-- - Unless a question says otherwise, use orders with status = 'paid'.
-- - Write ONE query per prompt.
-- - Keep results readable (use clear aliases, ORDER BY where it helps).

-- =========================================================
-- Q1) Correlated subquery: Above-average order totals (PAID only)
-- =========================================================
-- For each PAID order, compute order_total (= SUM(quantity * products.price)).
-- Return: order_id, customer_name, store_name, order_datetime, order_total.
-- Filter to orders where order_total is greater than the average PAID order_total
-- for THAT SAME store (correlated subquery).
-- Sort by store_name, then order_total DESC.
select
	oi.order_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    s.name as store_name,
    o.order_datetime,
    sum(oi.quantity * p.price) as order_total
from customers c
join orders o on c.customer_id = o.customer_id
join order_items oi on oi.order_id = o.order_id
join stores s on s.store_id = o.store_id
join products p on p.product_id = oi.product_id
where o.status = 'paid'
group by oi.order_id, customer_name, s.name, o.order_datetime, o.store_id
having order_total > (
		select avg(store_order_totals.total)
		from (
			select o2.order_id, o2.store_id, sum(oi2.quantity * p2.price) as total
			from orders o2
			join order_items oi2 on o2.order_id = oi2.order_id
			join products p2 on oi2.product_id = p2.product_id
			where o2.status = 'paid'
			group by o2.order_id, o2.store_id
		) as store_order_totals
		where store_order_totals.store_id = o.store_id
)
order by s.name, order_total desc;
-- =========================================================
-- Q2) CTE: Daily revenue and 3-day rolling average (PAID only)
-- =========================================================
-- Using a CTE, compute daily revenue per store:
--   revenue_day = SUM(quantity * products.price) grouped by store_id and DATE(order_datetime).
-- Then, for each store and date, return:
--   store_name, order_date, revenue_day,
--   rolling_3day_avg = average of revenue_day over the current day and the prior 2 days.
-- Use a window function for the rolling average.
-- Sort by store_name, order_date.
with daily_revenue as (
	select
		o.store_id,
		s.name as store_name,
		date(o.order_datetime) as order_date,
		sum(oi.quantity * p.price) as revenue_day
    from orders o
    join order_items oi on oi.order_id = o.order_id
    join products p on p.product_id = oi.product_id
    join stores s on s.store_id = o.store_id
    where o.status = 'paid'
    group by s.store_id, s.name, date(o.order_datetime)
)
select
	store_name,
    order_date,
    revenue_day,
    avg(revenue_day) over (
		partition by store_id
        order by order_date
        rows between 2 preceding and current row
	) as rolling_3day_avg
from daily_revenue
order by store_name, order_date;
-- =========================================================
-- Q3) Window function: Rank customers by lifetime spend (PAID only)
-- =========================================================
-- Compute each customer's total spend across ALL stores (PAID only).
-- Return: customer_id, customer_name, total_spend,
--         spend_rank (DENSE_RANK by total_spend DESC).
-- Also include percent_of_total = customer's total_spend / total spend of all customers.
-- Sort by total_spend DESC.
with customer_spend as (
	select
		c.customer_id,
        concat(c.first_name, ' ', c.last_name) as customer_name,
        sum(oi.quantity * price) as total_spend
	from customers c
    join orders o on c.customer_id = o.customer_id
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.status = 'paid'
    group by c.customer_id, c.first_name, c.last_name
)
select customer_id, customer_name, total_spend,
	dense_rank() over(order by total_spend desc) as spend_rank,
    total_spend / sum(total_spend) over () as percent_of_total
from customer_spend
order by total_spend desc;
-- =========================================================
-- Q4) CTE + window: Top product per store by revenue (PAID only)
-- =========================================================
-- For each store, find the top-selling product by REVENUE (not units).
-- Revenue per product per store = SUM(quantity * products.price).
-- Return: store_name, product_name, category_name, product_revenue.
-- Use a CTE to compute product_revenue, then a window function (ROW_NUMBER)
-- partitioned by store to select the top 1.
-- Sort by store_name.
with store_product_revenue as (
	select
		s.store_id,
        s.name as store_name,
        p.name as product_name,
        sum(oi.quantity * p.price) as product_revenue,
        c.name as category_name
	from stores s
    join orders o on s.store_id = o.store_id
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    join categories c on p.category_id = c.category_id
    where o.status = 'paid'
    group by s.store_id, s.name, p.product_id, p.name
),
revenue_ranked as (
	select
		store_name,
        product_name,
        category_name,
        product_revenue,
        row_number() over (partition by store_id order by product_revenue desc) as row_num
	from store_product_revenue
)
select store_name, product_name, category_name, product_revenue
from revenue_ranked
where row_num = 1
order by store_name;
-- =========================================================
-- Q5) Subquery: Customers who have ordered from ALL stores (PAID only)
-- =========================================================
-- Return customers who have at least one PAID order in every store in the stores table.
-- Return: customer_id, customer_name.
-- Hint: Compare count(distinct store_id) per customer to (select count(*) from stores).
select
	concat(c.first_name, ' ', c.last_name) as customer_name,
    c.customer_id
from customers c
join orders o on c.customer_id = o.customer_id
where o.status = 'paid'
group by c.customer_id, c.first_name, c.last_name
having count(distinct o.store_id) = (select count(*) from stores);
-- =========================================================
-- Q6) Window function: Time between orders per customer (PAID only)
-- =========================================================
-- For each customer, list their PAID orders in chronological order and compute:
--   prev_order_datetime (LAG),
--   minutes_since_prev (difference in minutes between current and previous order).
-- Return: customer_name, order_id, order_datetime, prev_order_datetime, minutes_since_prev.
-- Only show rows where prev_order_datetime is NOT NULL.
-- Sort by customer_name, order_datetime.
with order_history as (
	select
		concat(c.first_name, ' ', c.last_name) as customer_name,
        o.order_id,
        o.order_datetime,
        lag(o.order_datetime) over (
			partition by o.customer_id
            order by o.order_datetime
		) as prev_order_datetime
	from customers c
    join orders o on c.customer_id = o.customer_id
    where o.status = 'paid'
)
select
	customer_name,
    order_id,
    order_datetime,
    prev_order_datetime,
    timestampdiff(minute, prev_order_datetime, order_datetime) as minutes_since_prev
from order_history
where prev_order_datetime is not null
order by customer_name, order_datetime;
-- =========================================================
-- Q7) View: Create a reusable order line view for PAID orders
-- =========================================================
-- Create a view named v_paid_order_lines that returns one row per PAID order item:
--   order_id, order_datetime, store_id, store_name,
--   customer_id, customer_name,
--   product_id, product_name, category_name,
--   quantity, unit_price (= products.price),
--   line_total (= quantity * products.price)
-- 
-- After creating the view, write a SELECT that uses the view to return:
--   store_name, category_name, revenue
-- where revenue is SUM(line_total),
-- sorted by revenue DESC.
create view v_paid_order_lines as
select
	o.order_id,
    o.order_datetime,
    s.store_id,
    s.name AS store_name,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    p.product_id,
    p.name AS product_name,
    cat.name AS category_name,
    oi.quantity,
    p.price AS unit_price,
    (oi.quantity * p.price) AS line_total
from orders o
join stores s on o.store_id = s.store_id
join customers c on o.customer_id = c.customer_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join categories cat on p.category_id = cat.category_id
where o.status = 'paid';

select
store_name,
category_name,
sum(line_total) as revenue
from v_paid_order_lines
group by store_name, category_name
order by revenue desc;
-- =========================================================
-- Q8) View + window: Store revenue share by payment method (PAID only)
-- =========================================================
-- Create a view named v_paid_store_payments with:
--   store_id, store_name, payment_method, revenue
-- where revenue is total PAID revenue for that store/payment_method.
--
-- Then query the view to return:
--   store_name, payment_method, revenue,
--   store_total_revenue (window SUM over store),
--   pct_of_store_revenue (= revenue / store_total_revenue)
-- Sort by store_name, revenue DESC.
create view v_paid_store_payments as
select
	s.store_id,
	s.name as store_name,
	o.payment_method,
	sum(oi.quantity * p.price) as revenue
from stores s
join orders o on s.store_id = o.store_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
where o.status = 'paid'
group by s.store_id, s.name, o.payment_method;

select
	store_name,
    payment_method,
    revenue,
    sum(revenue) over(partition by store_name) as store_total_revenue,
    revenue / sum(revenue) over(partition by store_name) as pct_of_store_revenue
from v_paid_store_payments
order by store_name, revenue desc;
-- =========================================================
-- Q9) CTE: Inventory risk report (low stock relative to sales)
-- =========================================================
-- Identify items where on_hand is low compared to recent demand:
-- Using a CTE, compute total_units_sold per store/product for PAID orders.
-- Then join inventory to that result and return rows where:
--   on_hand < total_units_sold
-- Return: store_name, product_name, on_hand, total_units_sold, units_gap (= total_units_sold - on_hand)
-- Sort by units_gap DESC.
with recent_sales as (
	select
		o.store_id,
        oi.product_id,
        sum(oi.quantity) as total_units_sold
	from orders o
    join order_items oi on o.order_id = oi.order_id
    where o.status = 'paid'
    group by o.store_id, oi.product_id
)
select
	s.name as store_name,
    p.name as product_name,
    i.on_hand,
    rs.total_units_sold,
    (rs.total_units_sold - i.on_hand) as units_gap
from inventory i
join recent_sales rs on i.store_id = rs.store_id and i.product_id = rs.product_id
join stores s on i.store_id = s.store_id
join products p on i.product_id = p.product_id
where i.on_hand < rs.total_units_sold
order by units_gap desc;