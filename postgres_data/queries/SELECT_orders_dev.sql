SELECT 
    -- Інформація про замовлення
    o.order_id AS "ID Замовлення",
    o.order_name AS "Назва Замовлення",
    o.order_date AS "Дата Замовлення",
    o.process_name AS "Бізнес-процес",
    o.order_status AS "Статус",
    o.order_sum AS "Загальна Сума Замовлення",
    
    -- Дані клієнта та менеджера
    o.client_name AS "Клієнт",
    o.client_phone AS "Телефон Клієнта",
    o.manager AS "Менеджер",
    o.legal_entity_name AS "Юридична Особа",
    
    -- Деталізація товарів у замовленні
    oi.product_count AS "Кількість Товару",
    oi.product_price AS "Ціна за Одиницю",
    oi.product_currency AS "Валюта",
    oi.product_sum AS "Сума за Товар",
    
    -- Інформація з довідника товарів
    p.product_name AS "Назва Товару з Довідника",
    p.product_category_name AS "Категорія Товару",
    p.pershi_riven_kategori AS "Категорія 1-го рівня"

FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
ORDER BY o.order_date DESC, o.order_id;