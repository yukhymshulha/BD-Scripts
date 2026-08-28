SELECT 
    op.id AS "ID Складської Операції",
    op.date AS "Дата Документа",
    op.type AS "Тип Операції", -- Прибуток, Переміщення, Списання
    op.storagefromname AS "Склад-Відправник",
    op.storagetoname AS "Склад-Отримувач",
    op.numberdocument AS "Номер Документа",
    op.client AS "Контрагент (Постачальник/Клієнт)",
    
    -- Деталізація товарних рядків операції
    opi.amount AS "Кількість",
    opi.price AS "Ціна за Одиницю",
    opi.pricebase AS "Базова Ціна (Собівартість)",
    opi.cellname AS "Комірка Зберігання",
    opi.serial AS "Серійний Номер",
    
    -- Інформація з довідника товарів
    p.product_name AS "Товар з Номенклатури",
    p.product_category_name AS "Категорія Товару",
    
    -- Кастомні аналітичні мітки OneBox
    opi.custom_model AS "Модель",
    opi.custom_partiya AS "Партія",
    opi.custom_komentar AS "Коментар до товару"
FROM storage_operations op
LEFT JOIN storage_operation_items opi ON op.id = opi.operation_id
LEFT JOIN products p ON opi.productid = p.product_id
ORDER BY op.date DESC, op.id;