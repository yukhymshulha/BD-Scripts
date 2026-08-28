SELECT 
    pay.payment_id AS "ID Платежу",
    pay.payment_date AS "Дата Платежу",
    pay.payment_sum AS "Сума Платежу",
    pay.payment_currency AS "Валюта Платежу",
    pay.payment_exchange_rate AS "Курс Валюти",
    pay.payment_comment AS "Коментар",
    pay.payment_client_name AS "Контрагент",
    pay.payment_account_name AS "Каса / Рахунок",
    pay.payment_category_name AS "Категорія Витрат/Доходів",
    pay.payment_author_name AS "Хто вніс платіж",
    -- Зв'язок із сутністю замовлень
    ord.order_id AS "ID Пов'язаного Замовлення",
    ord.order_name AS "Назва Замовлення",
    ord.process_name AS "Тип Процесу Замовлення"
FROM payments pay
LEFT JOIN orders ord ON pay.payment_order_id = ord.order_id
ORDER BY pay.payment_date DESC;