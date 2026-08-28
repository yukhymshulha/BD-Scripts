CREATE TABLE IF NOT EXISTS pasports_raw (
    order_id VARCHAR(50) PRIMARY KEY,
    order_name VARCHAR(255),
    order_cdate TIMESTAMP,
    father_product_id VARCHAR(50),
    products JSONB
);