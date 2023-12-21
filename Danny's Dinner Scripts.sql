
-- What is the total amount each customer spent at the restaurant?
select customer_id as "Customer", sum(price) as "Amount Spent" 
from menu m inner join sales s 
on m.product_id = s.product_id 
group by s.customer_id 
order by s.customer_id;

-- How many days has each customer visited the restaurant?
select customer_id, count(distinct(extract(day from order_date))) 
from sales group by customer_id order by customer_id;

-- What was the first item from the menu purchased by each customer?
select customer_id as "Customer", min(order_date) as "First order date", product_name as "Item" 
from sales s inner join menu m 
on s.product_id = m.product_id 
where order_date=(select min(order_date) from sales) 
group by customer_id, product_name 
order by customer_id;

-- What is the most purchased item on the menu and how many times was it purchased by all customers?
select s.product_id as "Product ID", m.product_name as "Item", count(order_date) as "Counter"
from sales s inner join menu m 
on m.product_id=s.product_id 
group by s.product_id, m.product_name 
order by count(order_date) desc 
limit 1;

-- Which item was the most popular for each customer?
with popularItems as(
	select s.customer_id, m.product_name, count(s.product_id) as purchase_count,
	RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS item_rank
	from menu m inner join sales s 
	on m.product_id = s.product_id 
	group by s.customer_id, m.product_name
)
select customer_id, product_name as "Most Popular Item", purchase_count as "Purchase Count"
from popularItems
where item_rank=1;

-- Which item was purchased first by the customer after they became a member?
with first_purchase as(
	select min(order_date) as first_purchase, m.customer_id, s.product_id, m.join_date from sales s inner join members m on m.customer_id = s.customer_id where s.order_date>=m.join_date group by m.customer_id, s.product_id, m.join_date
)
select i.customer_id, i.join_date, m.product_id, m.product_name, i.first_purchase from menu m inner join first_purchase i on i.product_id = m.product_id;

-- Which item was purchased just before the customer became a member?
with just_before as(
	select max(order_date) as last_purchase, m.customer_id, m.join_date from members m inner join sales s on s.customer_id=m.customer_id where m.join_date<s.order_date group by m.customer_id, m.join_date
)
select j.customer_id, j.join_date, j.last_purchase, m.product_id, m.product_name from just_before j inner join sales s on j.customer_id = s.customer_id inner join menu m on m.product_id = s.product_id where s.order_date=last_purchase group by j.customer_id,j.join_date, j.last_purchase, m.product_id, m.product_name;

-- What is the total items and amount spent for each member before they became a member?
with before_member as(
	select m.customer_id, s.order_date, m.join_date, s.product_id from members m inner join sales s on s.customer_id = m.customer_id where s.order_date<m.join_date
)
select b.customer_id, count(*), sum(price) from menu m inner join before_member b on b.product_id = m.product_id group by b.customer_id order by b.customer_id;

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select s.customer_id as "Customer", sum(price) as "Amount Spent on Sushi", sum(20*price) as "Total points" from sales s inner join menu m on m.product_id = s.product_id where s.product_id=1 group by s.customer_id order by s.customer_id;

-- In the first week after a customer joins the program (including their join date) they earn 2x points 
-- on all items, not just sushi - how many points do customer A and B have at the end of January?
with customer_joins as(
	select m.customer_id, s.product_id, s.order_date, m.join_date from members m inner join sales s on m.customer_id = s.customer_id where s.order_date >= m.join_date and s.order_date <= '2022-01-31'
)
select c.customer_id, sum(
	case
	when c.order_date <= c.join_date + INTERVAL '7 days' THEN 20 * m.price
	else m.price
	end
) AS "Points Gained Until End of January"
from customer_joins c inner join menu m on m.product_id = c.product_id group by c.customer_id order by c.customer_id;

-- Adding a new table of transaction history which shows what the customer has ordered, order date, price 
-- and if they are a member or not
-- 1) creating a table of transaction_history
CREATE TABLE transaction_history(
    customer_id varchar(50),
    order_date date,
    product_id varchar(50)
);
-- 2) inserting initial data from sales table about customer_id, order_date, product_id
INSERT INTO transaction_history (customer_id, order_date, product_id)
SELECT customer_id, order_date, product_id
FROM sales;

-- 3) adding a new column of product_name and deriving data from menu table
ALTER TABLE transaction_history
ADD COLUMN product_name varchar(50);

UPDATE transaction_history t
SET product_name = menu.product_name
FROM menu
WHERE t.product_id = menu.product_id::varchar(50);

-- 4) adding a new column of price and deriving data from menu table
ALTER TABLE transaction_history
ADD COLUMN price integer;

UPDATE transaction_history t
SET price = menu.price
FROM menu
WHERE t.product_id = menu.product_id::varchar(50);

-- 5) adding a new column of member and checking data from members table
ALTER TABLE transaction_history
ADD COLUMN member char;

UPDATE transaction_history AS th
SET member = 
    CASE
        WHEN th.customer_id IN (SELECT customer_id FROM members where order_date>=join_date) THEN 'Y'
        ELSE 'N'
    END;

-- 6) drop the column of product_id
alter table transaction_history drop column product_id;

select * from transaction_history order by customer_id, order_date;
