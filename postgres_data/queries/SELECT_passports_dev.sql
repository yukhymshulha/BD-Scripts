SELECT 
    pass.order_id AS "ID Карти Техпроцесу",
    pass.father_product_name AS "Готовий Виріб (Батьківський Товар)",
    pass.father_product_id AS "ID Виробу",
    pass.product_name AS "Компонент / Матеріал",
    pass.product_id AS "ID Компонента",
    pass.product_count AS "Кількість на Одиницю Виробу",
    -- Перевірка поточної наявності компонента на складах
    p.product_unit AS "Одиниця Виміру"
FROM product_passports pass
LEFT JOIN products p ON pass.product_id = p.product_id
ORDER BY pass.father_product_name, pass.order_id;