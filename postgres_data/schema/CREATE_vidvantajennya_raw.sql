CREATE TABLE IF NOT EXISTS vidvantajennya_raw (
    order_id VARCHAR(50) PRIMARY KEY,
    order_name VARCHAR(255),
    order_date TIMESTAMP,
    client_id VARCHAR(50),
    manager_id VARCHAR(50),
    manager VARCHAR(255),
    author_id VARCHAR(50),
    author VARCHAR(255),
    process_id VARCHAR(50),
    process_name VARCHAR(255),
    order_status_id VARCHAR(50),
    order_status VARCHAR(255),
    client_phone VARCHAR(100),
    client_email VARCHAR(255),
    client_name VARCHAR(255),
    order_sum NUMERIC,
    delivery_note TEXT,
    legal_entity_id VARCHAR(50),
    external_id VARCHAR(255),
    
    -- Вкладені структури (масиви або словники) зберігаємо як JSONB
    products JSONB,
    statustime JSONB,
    
    -- Додаткові поля, що можуть бути у схемі
    order_final_date TIMESTAMP,
    father_order_id VARCHAR(50),
    legal_entity_name VARCHAR(255),
    Faktichnadatavidachi TIMESTAMP,
    Faktichnadataotrimannyaklintom TIMESTAMP,
    Dataochikuvanogoplatezhu TIMESTAMP
);