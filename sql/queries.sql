-- рахуйте з урахуванням quantity:
SELECT 
    ROUND(SUM(od.quantity * p.price), 2) AS total_revenue, -- загальна виручка
    COUNT(DISTINCT o.order_id) AS total_orders, -- кількість замовлень
    SUM(od.quantity) AS total_pizza_sold, -- проданих піц загалом
    ROUND(SUM(od.quantity * p.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value, -- Середній чек
    ROUND(CAST(SUM(od.quantity) AS REAL) / COUNT(DISTINCT o.order_id), 2) AS average_pizzas_per_order -- середня кількість піц у замовленні
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id;
