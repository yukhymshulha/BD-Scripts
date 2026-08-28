
CREATE TABLE IF NOT EXISTS storage_balance_raw (
    id SERIAL PRIMARY KEY,
    storage_id TEXT NOT NULL,
    storage_name TEXT NOT NULL,
    storage_external_id TEXT,
    product_id TEXT NOT NULL,
    product_name TEXT,
    product_lot_id TEXT,
    product_serial TEXT,
    product_stock_in_date TIMESTAMP NOT NULL,
    product_price_base_uah NUMERIC(15, 2) NOT NULL,
    product_count NUMERIC(15, 3) NOT NULL,
    product_reserved NUMERIC(15, 3) NOT NULL,
    product_price_base NUMERIC(15, 2) NOT NULL,
    product_currency VARCHAR(10) NOT NULL
);

-- 3. Створюємо індекси (додано IF NOT EXISTS для безпеки)
CREATE INDEX IF NOT EXISTS idx_storage_balance_raw_product_id ON storage_balance_raw(product_id);
CREATE INDEX IF NOT EXISTS idx_storage_balance_raw_storage_id ON storage_balance_raw(storage_id);