SELECT 
    bal.storage_name AS "Назва Складу",
    p.product_name AS "Назва Товару",
    p.product_category_name AS "Категорія",
    p.pershi_riven_kategori AS "Група Товарів",
    bal.product_count AS "Поточний Залишок",
    bal.product_reserved AS "В Резерві (Під Замовлення)",
    (bal.product_count - bal.product_reserved) AS "Доступно до продажу",
    bal.product_price_base_uah AS "Базова ціна за од, грн",
    bal.product_stock_in_date AS "Дата останнього надходження"
FROM storage_balances bal
LEFT JOIN products p ON bal.product_id = p.product_id
WHERE bal.product_count > 0 OR bal.product_reserved > 0
ORDER BY bal.storage_name, p.product_name;