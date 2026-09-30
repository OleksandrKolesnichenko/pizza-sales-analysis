/*
 Загальні показники за рік: виручка, кількість замовлень, кількість проданих піц,
середній чек, середня кількість піц у замовленні. Кількість піц рахуйте з урахуванням quantity:
*/
SELECT 
    ROUND(SUM(od.quantity * p.price), 2) AS total_revenue, -- загальна виручка
    COUNT(DISTINCT o.order_id) AS total_orders, -- кількість замовлень
    SUM(od.quantity) AS total_pizza_sold, -- проданих піц загалом
    ROUND(SUM(od.quantity * p.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value, -- Середній чек
    ROUND(CAST(SUM(od.quantity) AS REAL) / COUNT(DISTINCT o.order_id), 2) AS average_pizzas_per_order -- середня кількість піц у замовленні
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id;

/*
2.  Динаміка по місяцях: виручка і кількість замовлень. Який місяць найсильніший,  а який найслабший? 
★ Зміна до попереднього місяця у відсотках.
*/
SELECT 
    month,
    monthly_revenue,
    monthly_orders,
    -- Зміна виручки до попереднього місяця у %
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) * 100.0 / LAG(monthly_revenue) OVER (ORDER BY month), 
        2
    ) AS revenue_change_pct,
    -- Зміна кількості замовлень до попереднього місяця у %
    ROUND(
        (monthly_orders - LAG(monthly_orders) OVER (ORDER BY month)) * 100.0 / LAG(monthly_orders) OVER (ORDER BY month), 
        2
    ) AS orders_change_pct
FROM (
    SELECT 
        strftime('%m', o.date) AS month,
        ROUND(SUM(od.quantity * p.price), 2) AS monthly_revenue,
        COUNT(DISTINCT o.order_id) AS monthly_orders
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY strftime('%m', o.date)
) AS sub
ORDER BY month;


/*3. Навантаження за днями тижня та годинами: коли пік, а коли тихо? Скільки замовлень у середньому надходить за один понеділок, 
один вівторок і так далі? */
    SELECT 
 -- назва дня тижня:
    CASE strftime('%w', o.date)
        WHEN '0' THEN 'Неділя'
        WHEN '1' THEN 'Понеділок'
        WHEN '2' THEN 'Вівторок'
        WHEN '3' THEN 'Середа'
        WHEN '4' THEN 'Четвер'
        WHEN '5' THEN 'П''ятниця'
        WHEN '6' THEN 'Субота'
    END AS day_of_week,
    strftime('%H', o.time) AS hour, --години
    COUNT(o.order_id) AS total_orders,
-- седня кількість замовлень в один  день:
    ROUND(COUNT(o.order_id) * 1.0 / COUNT(DISTINCT o.date), 2) AS avg_orders_per_day
FROM orders o  
GROUP BY 
    strftime('%w', o.date), 
    strftime('%H', o.time)
ORDER BY 
    strftime('%w', o.date) ASC;


/*4. Бестселери та аутсайдери: топ-5 і останні 5 піц за виручкою та за кількістю (на рівні назви піци, усі розміри разом).
Чи збігаються ці списки? */
--Бестселери
SELECT 
    pt.name AS pizza_name,
    SUM(od.quantity) AS total_quantity_sold -- сума продажів
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_quantity_sold DESC
LIMIT 5;

--Аутсайдери

SELECT 
    pt.name AS pizza_name,
    SUM(od.quantity) AS total_quantity_sold -- сума продажів
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_quantity_sold ASC
LIMIT 5;


/*5Категорії та розміри: частка виручки кожної категорії та кожного розміру.
Які розміри продаються найкраще?*/
SELECT 
    pt.category AS pizza_category,
    p.size AS pizza_size,
    SUM(od.quantity) AS total_quantity_sold,
    ROUND(SUM(od.quantity * p.price), 2) AS total_revenue,
    ROUND(
        SUM(od.quantity * p.price) * 100.0 / SUM(SUM(od.quantity * p.price)) OVER (), 
        2
    ) AS revenue_percentage
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.category, p.size
ORDER BY pt.category, total_revenue DESC;


/*6Кандидати на вилучення з меню: які піци (на рівні назви, усі розміри разом) мають
найменшу частку виручки й найменші продажі? Обґрунтуйте, які 3–5 позицій можна прибрати і 
скільки виручки це зачепить. ★ Накопичувальна частка виручки. */
WITH pizza_sales AS (
    SELECT 
        pt.name AS pizza_name,
        SUM(od.quantity) AS total_quantity_sold,
        ROUND(SUM(od.quantity * p.price), 2) AS total_revenue
    FROM order_details od
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
    GROUP BY pt.name
)
SELECT 
    pizza_name,
    total_quantity_sold,
    total_revenue,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_percentage,
    ROUND(
        SUM(total_revenue) OVER (
            ORDER BY total_revenue ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / SUM(total_revenue) OVER (), 
        2
    ) AS cumulative_revenue_percentage
FROM pizza_sales
ORDER BY total_revenue ASC
LIMIT 5;



/* 7 Великі замовлення: яка частка замовлень містить 4 і більше піц (сума quantity у замовленні)
і скільки виручки вони дають? Чи варто робити окрему пропозицію для компаній? */
WITH order_summary AS (
    -- Рахуємо загальну кількість піц і загальну суму виручки для кожного окремого замовлення
    SELECT 
        od.order_id,
        SUM(od.quantity) AS total_quantity_per_order,
        SUM(od.quantity * p.price) AS total_revenue_per_order
    FROM order_details od
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY od.order_id
), 
classified_orders AS (
    -- Класифікуємо замовлення на корпоративні/великі (4+ піци) і звичайні (<4 піц)
    SELECT 
        order_id,
        total_quantity_per_order,
        total_revenue_per_order,
        CASE 
            WHEN total_quantity_per_order >= 4 THEN 'Large Orders (4+ pizzas)'
            ELSE 'Standard Orders (<4 pizzas)'
        END AS order_category
    FROM order_summary
)
-- Агрегуємо результати для отримання часток за замовленнями і виручкою
SELECT 
    order_category,
    COUNT(order_id) AS total_orders_count,
    ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM order_summary), 2) AS order_percentage,
    ROUND(SUM(total_revenue_per_order), 2) AS category_revenue,
    ROUND(SUM(total_revenue_per_order) * 100.0 / (SELECT SUM(total_revenue_per_order) FROM order_summary), 2) AS revenue_percentage
FROM classified_orders
GROUP BY order_category;


/* 8Акція: у які дні тижня та години варто її запустити? Запропонуйте конкретну акцію та оцініть потенціал: 
яка зараз виручка в цьому часовому вікні і що дасть її зростання на 10%. */
SELECT 
    CASE strftime('%w', o.date)
        WHEN '0' THEN 'Неділя'
        WHEN '1' THEN 'Понеділок'
        WHEN '2' THEN 'Вівторок'
        WHEN '3' THEN 'Середа'
        WHEN '4' THEN 'Четвер'
        WHEN '5' THEN 'П''ятниця'
        WHEN '6' THEN 'Субота'
    END AS day_of_week,
    -- Година
    strftime('%H', o.time) AS hour,
    -- Кількість замовлень у цей час
    COUNT(DISTINCT o.order_id) AS total_orders,
    -- Загальна виручка у цей час
    ROUND(SUM(od.quantity * p.price), 2) AS window_revenue
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id
GROUP BY strftime('%w', o.date), strftime('%H', o.time)
ORDER BY window_revenue ASC
LIMIT 5;







