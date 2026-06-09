USE coffeeshop_db;

-- =========================================================
-- SUBQUERIES & NESTED LOGIC PRACTICE
-- =========================================================

-- Q1) Scalar subquery (AVG benchmark):
--     List products priced above the overall average product price.
--     Return product_id, name, price.
Select product_id, name, price
from products
where price > (
	select avg(price)
	from products);
-- Q2) Scalar subquery (MAX within category):
--     Find the most expensive product(s) in the 'Beans' category.
--     (Return all ties if more than one product shares the max price.)
--     Return product_id, name, price.
select p.product_id, p.name, p.price
from products as p
inner join categories as c on c.category_id = p.category_id
where c.name = 'Beans'
and p.price = (
	select max(p2.price)
    from products as p2
    join categories as c2 on c2.category_id = p2.category_id
    where c2.name = 'Beans');
-- Q3) List subquery (IN with nested lookup):
--     List customers who have purchased at least one product in the 'Merch' category.
--     Return customer_id, first_name, last_name.
--     Hint: Use a subquery to find the category_id for 'Merch', then a subquery to find product_ids.
Select distinct c.customer_id, c.first_name, c.last_name
from customers c
join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
where oi.product_id in(
	select product_id
    from products
    where category_id = (
		select category_id
        from categories
        where name = 'Merch'
        )
	);
-- Q4) List subquery (NOT IN / anti-join logic):
--     List products that have never been ordered (their product_id never appears in order_items).
--     Return product_id, name, price.
Select product_id, name, price
from products
where product_id not in (
    select product_id
    from order_items);    
-- Q5) Table subquery (derived table + compare to overall average):
--     Build a derived table that computes total_units_sold per product
--     (SUM(order_items.quantity) grouped by product_id).
--     Then return only products whose total_units_sold is greater than the
--     average total_units_sold across all products.
--     Return product_id, product_name, total_units_sold.

-- I tried to use a subquery first, then Blake suggested
-- useding a CTE during office hours to make it look better.
-- I'm leaving both for my own reference!
Select product_id, name, total_units_sold
from (select p.product_id, p.name, sum(oi.quantity) as total_units_sold
		from products p
        join order_items oi on p.product_id = oi.product_id
        group by p.product_id, p.name) as derived_table
where total_units_sold > (
		select avg(total_units_sold2)
        from (select sum(oi2.quantity) as total_units_sold2
        from products p2
        join order_items oi2 on p2.product_id = oi2.product_id
        group by p2.product_id) as avg_table);
        
with derived_table as (
	select p.product_id, p.name, sum(oi.quantity) as total_units_sold
	from products p
	join order_items oi on p.product_id = oi.product_id
	group by p.product_id, p.name)
select product_id, name, total_units_sold
from derived_table
where total_units_sold > (select avg(total_units_sold) from derived_table);