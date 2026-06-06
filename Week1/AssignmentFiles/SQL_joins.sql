USE coffeeshop_db;

-- =========================================================
-- JOINS & RELATIONSHIPS PRACTICE
-- =========================================================

-- Q1) Join products to categories: list product_name, category_name, price.
select
	p.name as product_name,
	c.name as category_name,
	p.price
from products as p
inner join categories as c
	on p.category_id = c.category_id;
-- Q2) For each order item, show: order_id, order_datetime, store_name,
--     product_name, quantity, line_total (= quantity * products.price).
--     Sort by order_datetime, then order_id.
select
	oi.order_id,
    o.order_datetime,
    s.name,
    p.name,
    oi.quantity,
    oi.quantity * p.price as line_total
from order_items as oi
inner join orders as o on oi.order_id = o.order_id
inner join stores as s on o.store_id = s.store_id
inner join products as p on oi.product_id = p.product_id
order by order_datetime, order_id;
-- Q3) Customer order history (PAID only):
--     For each order, show customer_name, store_name, order_datetime,
--     order_total (= SUM(quantity * products.price) per order).
select
	concat(c.first_name, ' ', c.last_name) as customer_name,
    s.name as store_name,
    o.order_datetime,
    sum(oi.quantity * p.price) as order_total
from order_items as oi
inner join orders as o on oi.order_id = o.order_id
inner join customers as c on o.customer_id = c.customer_id
inner join stores as s on o.store_id = s.store_id
inner join products as p on oi.product_id = p.product_id
where o.status = 'paid'
group by o.order_id, c.first_name, c.last_name, s.name, o.order_datetime;
-- Q4) Left join to find customers who have never placed an order.
--     Return first_name, last_name, city, state.
select
c.first_name,
c.last_name,
c.city,
c.state
from customers as c
left join orders as o on c.customer_id = o.customer_id
where o.order_id is null;
-- Q5) For each store, list the top-selling product by units (PAID only).
--     Return store_name, product_name, total_units.
--     Hint: Use a window function (ROW_NUMBER PARTITION BY store) or a correlated subquery.
with store_product_totals as(
	select
		p.name as product_name,
		s.name as store_name,
		sum(oi.quantity) as total_units
	from order_items as oi
	inner join orders as o on oi.order_id = o.order_id
	inner join stores as s on o.store_id = s.store_id
	inner join products as p on oi.product_id = p.product_id
	where o.status = 'paid'
	group by s.name, p.name),
	ranked as (
		select *,
        row_number() over (partition by store_name order by total_units desc) as rn
        from store_product_totals)
	select store_name, product_name, total_units
	from ranked where rn = 1;
-- Q6) Inventory check: show rows where on_hand < 12 in any store.
--     Return store_name, product_name, on_hand.
select
	i.on_hand,
    s.name as store_name,
    p.name as product_name
from inventory as i
inner join stores as s on s.store_id = i.store_id
inner join products as p on p.product_id = i.product_id
where on_hand < 12;
-- Q7) Manager roster: list each store's manager_name and hire_date.
--     (Assume title = 'Manager').
select
	concat(e.first_name, ' ', e.last_name) as manager_name,
	e.hire_date,
    s.name as store_name
from employees as e
inner join stores as s on s.store_id = e.store_id
where e.title = 'Manager';
-- Q8) Using a subquery/CTE: list products whose total PAID revenue is above
--     the average PAID product revenue. Return product_name, total_revenue.
with product_revenue as(
	select
		p.name as product_name,
		sum(oi.quantity * p.price) as total_revenue
	from order_items as oi
	inner join orders as o on oi.order_id = o.order_id
	inner join products as p on oi.product_id = p.product_id
	where o.status = 'paid'
    group by p.name
	)
select product_name, total_revenue
	from product_revenue
    where total_revenue > (select avg(total_revenue) from product_revenue);
-- Q9) Churn-ish check: list customers with their last PAID order date.
--     If they have no PAID orders, show NULL.
--     Hint: Put the status filter in the LEFT JOIN's ON clause to preserve non-buyer rows.
select
	concat(c.first_name, ' ', c.last_name) as customer_name,
    max(o.order_datetime) as last_order_date
from customers as c
left join orders as o on c.customer_id = o.customer_id AND o.status = 'paid'
group by c.customer_id, c.first_name, c.last_name;
-- Q10) Product mix report (PAID only):
--     For each store and category, show total units and total revenue (= SUM(quantity * products.price)).
select
	s.name as store_name,
    c.name as category_name,
    sum(oi.quantity) as total_units,
    sum(oi.quantity * p.price) as total_revenue
from order_items as oi
inner join orders as o on o.order_id = oi.order_id
inner join stores as s on o.store_id = s.store_id
inner join products as p on p.product_id = oi.product_id
inner join categories as c on c.category_id = p.category_id
where o.status = 'paid'
group by s.name, c.name;