-- ============================================================================
-- ПОВНА СХЕМА БАЗИ ДАНИХ — ФІНАЛЬНА ВЕРСІЯ 3.0
-- ============================================================================
-- PostgreSQL 12+
-- Створено: 2026-07-10
-- Статус: Готовий до деплою
-- ============================================================================

-- ============================================================================
-- ЧАСТИНА 1: EXTENSIONS ТА СХЕМИ
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS moddatetime;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS etl;

-- ============================================================================
-- ЧАСТИНА 2: ДОВІДНИКИ (REFERENCE DATA)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: currencies
-- ----------------------------------------------------------------------------
CREATE TABLE core.currencies (
    currency_code  CHAR(3) PRIMARY KEY,
    currency_name  VARCHAR(100) NOT NULL,
    symbol         VARCHAR(5),
    decimal_places INT NOT NULL DEFAULT 2,
    is_base        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.currencies IS 'Довідник валют (ISO 4217)';

-- ----------------------------------------------------------------------------
-- Таблиця: units_of_measure
-- ----------------------------------------------------------------------------
CREATE TABLE core.units_of_measure (
    unit_code  VARCHAR(20) PRIMARY KEY,
    erp_id     VARCHAR(50) UNIQUE,
    unit_name  VARCHAR(100) NOT NULL,
    unit_type  VARCHAR(30) NOT NULL CHECK (unit_type IN ('weight','length','volume','count')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT erp_id_not_empty CHECK (erp_id IS NULL OR erp_id <> '')
);

COMMENT ON TABLE core.units_of_measure IS 'Довідник одиниць виміру';
COMMENT ON COLUMN core.units_of_measure.erp_id IS 'ERP-код одиниці виміру. Для стандартних одиниць (kg, pcs) може бути NULL.';

-- Окремий індекс на erp_id не потрібен — UNIQUE-обмеження вище вже його створює

-- ----------------------------------------------------------------------------
-- Таблиця: uom_conversions
-- ----------------------------------------------------------------------------
ALTER TABLE core.units_of_measure
    ADD CONSTRAINT unique_unit_code_type UNIQUE (unit_code, unit_type);

CREATE TABLE core.uom_conversions (
    from_unit         VARCHAR(20)    NOT NULL,
    from_unit_type    VARCHAR(30)    NOT NULL,
    to_unit           VARCHAR(20)    NOT NULL,
    to_unit_type      VARCHAR(30)    NOT NULL,
    conversion_factor DECIMAL(18,6)  NOT NULL CHECK (conversion_factor > 0),
    PRIMARY KEY (from_unit, to_unit),
    FOREIGN KEY (from_unit, from_unit_type) REFERENCES core.units_of_measure (unit_code, unit_type),
    FOREIGN KEY (to_unit,   to_unit_type)   REFERENCES core.units_of_measure (unit_code, unit_type),
    CONSTRAINT same_type CHECK (from_unit_type = to_unit_type),
    CONSTRAINT no_self_conversion CHECK (from_unit <> to_unit)
);

COMMENT ON TABLE core.uom_conversions IS 'Коефіцієнти конвертації одиниць виміру';

-- ----------------------------------------------------------------------------
-- Таблиця: exchange_rates
-- ----------------------------------------------------------------------------
CREATE TABLE core.exchange_rates (
    from_currency CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    to_currency   CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    valid_from    DATE NOT NULL,
    valid_to      DATE,
    rate          DECIMAL(18,6) NOT NULL CHECK (rate > 0),
    PRIMARY KEY (from_currency, to_currency, valid_from),
    CONSTRAINT no_overlap EXCLUDE USING gist (
        from_currency WITH =,
        to_currency   WITH =,
        daterange(valid_from, COALESCE(valid_to, DATE '9999-12-31'), '[]') WITH &&
    )
);

COMMENT ON TABLE core.exchange_rates IS 'Курси валют з захистом від перекриття періодів';

CREATE INDEX idx_exchange_rates_valid ON core.exchange_rates (valid_from, valid_to);

-- ============================================================================
-- ЧАСТИНА 3: CORE ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: clients
-- ----------------------------------------------------------------------------
CREATE TABLE core.clients (
    client_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    erp_id       VARCHAR(50) NOT NULL UNIQUE,
    client_name  VARCHAR(200) NOT NULL,
    payment_name VARCHAR(200),
    phone        VARCHAR(20),
    email        VARCHAR(100),
    client_group VARCHAR(50),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT erp_id_not_empty CHECK (erp_id <> '')
);

COMMENT ON TABLE core.clients IS 'Довідник клієнтів';
COMMENT ON COLUMN core.clients.erp_id IS 'ERP-код клієнта. ERP — master, локальне створення заборонене.';

CREATE INDEX idx_clients_erp_id ON core.clients (erp_id);
CREATE INDEX idx_clients_group ON core.clients (client_group);

-- ----------------------------------------------------------------------------
-- Таблиця: users
-- ----------------------------------------------------------------------------
CREATE TABLE core.users (
    user_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_name  VARCHAR(200) NOT NULL,
    email      VARCHAR(100) UNIQUE,
    role       VARCHAR(50) NOT NULL CHECK (role IN ('manager','author','admin')),
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.users IS 'Довідник користувачів системи';

CREATE INDEX idx_users_role ON core.users (role);

-- ----------------------------------------------------------------------------
-- Таблиця: legal_entities
-- ----------------------------------------------------------------------------
CREATE TABLE core.legal_entities (
    legal_entity_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_entity_name VARCHAR(300) NOT NULL,
    tax_code          VARCHAR(20) UNIQUE,
    address           TEXT,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.legal_entities IS 'Юридичні особи';

-- ----------------------------------------------------------------------------
-- Таблиця: processes
-- ----------------------------------------------------------------------------
CREATE TABLE core.processes (
    process_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    process_name VARCHAR(200) NOT NULL,
    description  TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE core.processes IS 'Бізнес-процеси';

-- ----------------------------------------------------------------------------
-- Таблиця: order_statuses
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_statuses (
    status_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status_name VARCHAR(100) NOT NULL,
    status_code VARCHAR(30) UNIQUE,
    sort_order  INT,
    is_final    BOOLEAN NOT NULL DEFAULT FALSE,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE core.order_statuses IS 'Довідник статусів замовлень';

-- ----------------------------------------------------------------------------
-- Таблиця: order_sources
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_sources (
    order_source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name     VARCHAR(100) NOT NULL,
    source_code     VARCHAR(30) UNIQUE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE core.order_sources IS 'Джерела замовлень';

-- ============================================================================
-- ЧАСТИНА 4: FINANCIAL ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: payment_categories
-- ----------------------------------------------------------------------------
CREATE TABLE core.payment_categories (
    category_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_name VARCHAR(100) NOT NULL,
    category_code VARCHAR(30) UNIQUE,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE core.payment_categories IS 'Категорії платежів';

-- ----------------------------------------------------------------------------
-- Таблиця: accounts
-- ----------------------------------------------------------------------------
CREATE TABLE core.accounts (
    account_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_name    VARCHAR(200) NOT NULL,
    account_number  VARCHAR(50),
    currency_code   CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    bank_name       VARCHAR(200),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE core.accounts IS 'Банківські рахунки';

CREATE INDEX idx_accounts_currency ON core.accounts (currency_code);

-- ============================================================================
-- ЧАСТИНА 5: CATALOG ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: product_categories
-- ----------------------------------------------------------------------------
CREATE TABLE core.product_categories (
    category_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id         UUID REFERENCES core.product_categories (category_id),
    category_name     VARCHAR(200) NOT NULL,
    materialized_path TEXT NOT NULL DEFAULT '/',
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.product_categories IS 'Ієрархія категорій товарів (Materialized Path)';

CREATE INDEX idx_product_categories_parent ON core.product_categories (parent_id);
CREATE INDEX idx_cat_path ON core.product_categories USING btree (materialized_path text_pattern_ops);

-- ----------------------------------------------------------------------------
-- Таблиця: products
-- ----------------------------------------------------------------------------
CREATE TABLE core.products (
    product_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    erp_id       VARCHAR(50) NOT NULL UNIQUE,
    category_id  UUID REFERENCES core.product_categories (category_id),
    unit_code    VARCHAR(20) REFERENCES core.units_of_measure (unit_code),
    product_name VARCHAR(300) NOT NULL,
    sku          VARCHAR(50),
    barcode      VARCHAR(50),
    weight       DECIMAL(15,3),
    is_deleted   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT erp_id_not_empty CHECK (erp_id <> '')
);

COMMENT ON TABLE core.products IS 'Довідник товарів';
COMMENT ON COLUMN core.products.erp_id IS 'ERP-код товару. ERP — master, локальне створення заборонене.';

CREATE INDEX idx_products_erp_id ON core.products (erp_id);
CREATE INDEX idx_products_category ON core.products (category_id);
CREATE INDEX idx_products_sku ON core.products (sku);
CREATE INDEX idx_products_barcode ON core.products (barcode);

-- ============================================================================
-- ЧАСТИНА 6: WAREHOUSE ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: storages
-- ----------------------------------------------------------------------------
CREATE TABLE core.storages (
    storage_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    erp_id                VARCHAR(50) NOT NULL UNIQUE,
    storage_name          VARCHAR(200) NOT NULL,
    storage_type          VARCHAR(50) NOT NULL CHECK (storage_type IN ('warehouse','shop','virtual')),
    responsible_user_id   UUID REFERENCES core.users (user_id),
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT erp_id_not_empty CHECK (erp_id <> '')
);

COMMENT ON TABLE core.storages IS 'Довідник складів';
COMMENT ON COLUMN core.storages.erp_id IS 'ERP-код складу. ERP — master, локальне створення заборонене.';

CREATE INDEX idx_storages_erp_id ON core.storages (erp_id);
CREATE INDEX idx_storages_type ON core.storages (storage_type);
CREATE INDEX idx_storages_responsible ON core.storages (responsible_user_id);

-- ----------------------------------------------------------------------------
-- Таблиця: storage_balances
-- ----------------------------------------------------------------------------
CREATE TABLE core.storage_balances (
    storage_id       UUID NOT NULL REFERENCES core.storages (storage_id),
    product_id       UUID NOT NULL REFERENCES core.products (product_id),
    product_serial   VARCHAR(100) NOT NULL DEFAULT 'N/A',
    product_lot_id   VARCHAR(50) NOT NULL DEFAULT 'N/A',
    stock_in_date    DATE,
    product_count    INT NOT NULL DEFAULT 0 CHECK (product_count >= 0),
    product_reserved INT NOT NULL DEFAULT 0 CHECK (product_reserved >= 0 AND product_reserved <= product_count),
    price_base       DECIMAL(15,2),
    currency_code    CHAR(3) REFERENCES core.currencies (currency_code),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (storage_id, product_id, product_serial, product_lot_id),
    CONSTRAINT serial_qty_max_one CHECK (product_serial = 'N/A' OR product_count <= 1)
);

COMMENT ON TABLE core.storage_balances IS 'Поточні залишки товарів на складах';
COMMENT ON COLUMN core.storage_balances.product_serial IS 'Серійний номер. Для несеріалізованих товарів — ''N/A''';
COMMENT ON COLUMN core.storage_balances.product_lot_id IS 'Номер партії. Для товарів без партій — ''N/A''';

CREATE INDEX idx_storage_balances_product ON core.storage_balances (product_id);
CREATE INDEX idx_storage_balances_lot ON core.storage_balances (product_lot_id);

-- ----------------------------------------------------------------------------
-- Таблиця: storage_operations
-- ----------------------------------------------------------------------------
CREATE TABLE core.storage_operations (
    operation_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_type             VARCHAR(30) NOT NULL CHECK (
        operation_type IN ('receipt','shipment','transfer','write-off','reversal')
    ),
    operation_date             TIMESTAMPTZ NOT NULL,
    user_id                    UUID REFERENCES core.users (user_id),
    storage_from_id            UUID REFERENCES core.storages (storage_id),
    storage_to_id              UUID REFERENCES core.storages (storage_id),
    order_id                   UUID,  -- FK буде додано після створення orders
    client_id                  UUID REFERENCES core.clients (client_id),
    reversal_of_operation_id   UUID REFERENCES core.storage_operations (operation_id),
    comments                   TEXT,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reversal_type_consistency CHECK (
        (operation_type = 'reversal') = (reversal_of_operation_id IS NOT NULL)
    )
);

COMMENT ON TABLE core.storage_operations IS 'Складські операції (незнищенні, тільки сторно)';

CREATE UNIQUE INDEX uq_one_reversal_per_operation
    ON core.storage_operations (reversal_of_operation_id)
    WHERE reversal_of_operation_id IS NOT NULL;

CREATE INDEX idx_storage_ops_order ON core.storage_operations (order_id);
CREATE INDEX idx_storage_ops_date ON core.storage_operations (operation_date);

-- ----------------------------------------------------------------------------
-- Таблиця: storage_operation_items
-- ----------------------------------------------------------------------------
CREATE TABLE core.storage_operation_items (
    operation_id      UUID NOT NULL REFERENCES core.storage_operations (operation_id),
    product_id        UUID NOT NULL REFERENCES core.products (product_id),
    serial            VARCHAR(100) NOT NULL DEFAULT 'N/A',
    lot_id            VARCHAR(50) NOT NULL DEFAULT 'N/A',
    quantity          INT NOT NULL CHECK (quantity <> 0),
    price             DECIMAL(15,2),
    currency_code     CHAR(3) REFERENCES core.currencies (currency_code),
    custom_attributes JSONB,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (operation_id, product_id, serial, lot_id),
    CONSTRAINT serial_qty_one CHECK (serial = 'N/A' OR quantity IN (1, -1))
);

COMMENT ON TABLE core.storage_operation_items IS 'Специфікація складських операцій (незнищенні)';

CREATE INDEX idx_storage_op_items_product ON core.storage_operation_items (product_id);

-- ----------------------------------------------------------------------------
-- Таблиця: production_costs
-- ----------------------------------------------------------------------------
CREATE TABLE core.production_costs (
    operation_id  UUID NOT NULL REFERENCES core.storage_operations (operation_id),
    cost_source   VARCHAR(100) NOT NULL,
    amortization  DECIMAL(15,2),
    salary        DECIMAL(15,2),
    total_cost    DECIMAL(15,2) GENERATED ALWAYS AS (COALESCE(amortization, 0) + COALESCE(salary, 0)) STORED,
    PRIMARY KEY (operation_id, cost_source)
);

COMMENT ON TABLE core.production_costs IS 'Виробничі витрати';

-- ============================================================================
-- ЧАСТИНА 7: ORDERS ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: orders
-- ----------------------------------------------------------------------------
CREATE TABLE core.orders (
    order_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_order_id   UUID REFERENCES core.orders (order_id),
    order_number      VARCHAR(50),
    order_date        DATE NOT NULL,
    manager_id        UUID REFERENCES core.users (user_id),
    author_id         UUID REFERENCES core.users (user_id),
    legal_entity_id   UUID REFERENCES core.legal_entities (legal_entity_id),
    process_id        UUID REFERENCES core.processes (process_id),
    status_id         UUID REFERENCES core.order_statuses (status_id),
    order_source_id   UUID REFERENCES core.order_sources (order_source_id),
    root_product_id   UUID REFERENCES core.products (product_id),
    is_incoming       BOOLEAN,
    external_id       VARCHAR(100),
    rating_score      DECIMAL(3,2),
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_order_external UNIQUE (order_source_id, external_id),
    CONSTRAINT unique_order_number_per_source UNIQUE (order_source_id, order_number)
);

COMMENT ON TABLE core.orders IS 'Замовлення (client_id видалено — використовуємо order_roles)';

CREATE INDEX idx_orders_parent ON core.orders (parent_order_id);
CREATE INDEX idx_orders_manager ON core.orders (manager_id);
CREATE INDEX idx_orders_author ON core.orders (author_id);
CREATE INDEX idx_orders_legal_entity ON core.orders (legal_entity_id);
CREATE INDEX idx_orders_process ON core.orders (process_id);
CREATE INDEX idx_orders_status ON core.orders (status_id);
CREATE INDEX idx_orders_source ON core.orders (order_source_id);
CREATE INDEX idx_orders_root_product ON core.orders (root_product_id);
CREATE INDEX idx_orders_date ON core.orders (order_date);

-- Додати FK для storage_operations.order_id
ALTER TABLE core.storage_operations
    ADD CONSTRAINT fk_storage_operations_order
    FOREIGN KEY (order_id) REFERENCES core.orders (order_id);

-- ----------------------------------------------------------------------------
-- Таблиця: order_roles
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_roles (
    order_id   UUID NOT NULL REFERENCES core.orders (order_id) ON DELETE CASCADE,
    role_type  VARCHAR(30) NOT NULL CHECK (
        role_type IN ('customer','payer','recipient','bill_to','ship_to','supplier')
    ),
    party_id   UUID NOT NULL REFERENCES core.clients (client_id),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, role_type, party_id)
);

COMMENT ON TABLE core.order_roles IS 'Ролі клієнтів у замовленні (єдине джерело істини). Кілька сторін на одну роль дозволено (напр. кілька ship_to), is_primary позначає головну.';

CREATE INDEX idx_order_roles_party ON core.order_roles (party_id);

-- Не більше однієї "головної" сторони на роль в межах замовлення
CREATE UNIQUE INDEX uq_order_roles_primary
    ON core.order_roles (order_id, role_type)
    WHERE is_primary = TRUE;

-- ----------------------------------------------------------------------------
-- Таблиця: order_financials
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_financials (
    order_id              UUID PRIMARY KEY REFERENCES core.orders (order_id) ON DELETE CASCADE,
    payment_category_id   UUID REFERENCES core.payment_categories (category_id),
    account_id            UUID REFERENCES core.accounts (account_id),
    order_sum             DECIMAL(15,2) NOT NULL CHECK (order_sum >= 0),
    paid_sum              DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (paid_sum >= 0),
    is_paid               BOOLEAN GENERATED ALWAYS AS (order_sum > 0 AND paid_sum >= order_sum) STORED,
    requires_prepayment   BOOLEAN NOT NULL DEFAULT FALSE,
    prepayment_percent    DECIMAL(5,2),
    expected_payment_date DATE,
    currency_code         CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.order_financials IS 'Фінансова частина замовлення';

CREATE INDEX idx_order_financials_unpaid ON core.order_financials (order_id) WHERE is_paid = FALSE;

-- ----------------------------------------------------------------------------
-- Таблиця: order_logistics
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_logistics (
    order_id              UUID PRIMARY KEY REFERENCES core.orders (order_id) ON DELETE CASCADE,
    procurement_deadline  DATE,
    delivery_date         DATE,
    actual_issue_date     DATE,
    actual_receive_date   DATE,
    supply_process_sum    DECIMAL(15,2),
    delivery_note         TEXT,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.order_logistics IS 'Логістична частина замовлення';

-- ----------------------------------------------------------------------------
-- Таблиця: order_obligations
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_obligations (
    order_id             UUID PRIMARY KEY REFERENCES core.orders (order_id) ON DELETE CASCADE,
    our_obligations      TEXT,
    client_obligations   TEXT,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.order_obligations IS 'Зобов''язання сторін';

-- ----------------------------------------------------------------------------
-- Таблиця: order_items
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_items (
    item_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES core.orders (order_id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES core.products (product_id),
    product_count   INT NOT NULL CHECK (product_count > 0),
    product_price   DECIMAL(15,2) NOT NULL,
    currency_code   CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    product_sum     DECIMAL(15,2) GENERATED ALWAYS AS (product_count * product_price) STORED,
    delivery_date   DATE,
    is_posted       BOOLEAN NOT NULL DEFAULT FALSE,
    custom_attributes JSONB,
    payment_plan    JSONB
);

COMMENT ON TABLE core.order_items IS 'Позиції замовлення';

CREATE INDEX idx_order_items_order ON core.order_items (order_id);
CREATE INDEX idx_order_items_product ON core.order_items (product_id);

-- ----------------------------------------------------------------------------
-- Таблиця: order_status_history (partitioned)
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_status_history (
    history_id          UUID DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES core.orders (order_id),
    status_change_date  TIMESTAMPTZ NOT NULL,
    status_id           UUID NOT NULL REFERENCES core.order_statuses (status_id),
    author_id           UUID REFERENCES core.users (user_id),
    comments            TEXT,
    PRIMARY KEY (history_id, status_change_date)
) PARTITION BY RANGE (status_change_date);

COMMENT ON TABLE core.order_status_history IS 'Історія зміни статусів замовлень (партиціонована)';

-- Партиції
CREATE TABLE core.order_status_history_2024 PARTITION OF core.order_status_history
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE core.order_status_history_2025 PARTITION OF core.order_status_history
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE core.order_status_history_2026 PARTITION OF core.order_status_history
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE core.order_status_history_2027 PARTITION OF core.order_status_history
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
-- Запобіжник: без цього вставка дати поза 2024-2027 впаде з "no partition of relation found"
CREATE TABLE core.order_status_history_default PARTITION OF core.order_status_history DEFAULT;

CREATE INDEX idx_order_status_history_order ON core.order_status_history (order_id);
CREATE INDEX idx_order_status_history_date ON core.order_status_history (status_change_date);

-- ----------------------------------------------------------------------------
-- Таблиця: order_stage_transitions
-- ----------------------------------------------------------------------------
CREATE TABLE core.order_stage_transitions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id          UUID NOT NULL REFERENCES core.orders (order_id),
    stage_type        VARCHAR(50) NOT NULL CHECK (stage_type IN ('procurement','production','delivery','payment')),
    stage_status      VARCHAR(30) NOT NULL CHECK (stage_status IN ('pending','accepted','in_progress','completed','cancelled')),
    transitioned_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by        UUID REFERENCES core.users (user_id),
    comments          TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.order_stage_transitions IS 'Стани workflow замовлень';

CREATE INDEX idx_stage_order ON core.order_stage_transitions (order_id);
CREATE INDEX idx_stage_type_status ON core.order_stage_transitions (stage_type, stage_status);
CREATE INDEX idx_stage_date ON core.order_stage_transitions (transitioned_at);

-- ============================================================================
-- ЧАСТИНА 8: PAYMENTS ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: payments
-- ----------------------------------------------------------------------------
CREATE TABLE core.payments (
    payment_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_date    DATE NOT NULL,
    payment_sum     DECIMAL(15,2) NOT NULL CHECK (payment_sum > 0),
    currency_code   CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    exchange_rate   DECIMAL(18,6),
    payment_key     VARCHAR(100),
    payment_code    VARCHAR(50),
    payment_comment TEXT,
    client_id       UUID REFERENCES core.clients (client_id),
    author_id       UUID REFERENCES core.users (user_id),
    category_id     UUID REFERENCES core.payment_categories (category_id),
    account_id      UUID REFERENCES core.accounts (account_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.payments IS 'Платежі (order_id відсутній — використовуємо payment_allocations)';

CREATE INDEX idx_payments_date ON core.payments (payment_date);
CREATE INDEX idx_payments_client ON core.payments (client_id);
CREATE INDEX idx_payments_code ON core.payments (payment_code);

-- ----------------------------------------------------------------------------
-- Таблиця: payment_allocations
-- ----------------------------------------------------------------------------
CREATE TABLE core.payment_allocations (
    allocation_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id                 UUID NOT NULL REFERENCES core.payments (payment_id) ON DELETE CASCADE,
    order_id                   UUID NOT NULL REFERENCES core.orders (order_id) ON DELETE CASCADE,
    allocated_amount           DECIMAL(15,2) NOT NULL CHECK (allocated_amount > 0),
    allocated_amount_currency  CHAR(3) NOT NULL REFERENCES core.currencies (currency_code),
    applied_rate               DECIMAL(18,6) NOT NULL CHECK (applied_rate > 0),
    allocated_at               TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (payment_id, order_id)
);

COMMENT ON TABLE core.payment_allocations IS 'Розподіл платежів між замовленнями (M:N)';
COMMENT ON COLUMN core.payment_allocations.allocated_amount IS 'Сума розподілу у валюті ЗАМОВЛЕННЯ';
COMMENT ON COLUMN core.payment_allocations.applied_rate IS 'Курс конвертації payment_currency → order_currency';

CREATE INDEX idx_payment_allocations_order ON core.payment_allocations (order_id);
CREATE INDEX idx_payment_allocations_payment ON core.payment_allocations (payment_id);

-- ============================================================================
-- ЧАСТИНА 9: STAGING ТАБЛИЦІ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Таблиця: staging.orders_raw
-- ----------------------------------------------------------------------------
CREATE TABLE staging.orders_raw (
    raw_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     TEXT,
    external_id  TEXT NOT NULL,
    source_code  TEXT,
    client_erp_id TEXT,
    manager_name TEXT,
    status_name  TEXT,
    order_sum    TEXT,
    order_date   TEXT,
    received_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    etl_status   VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        etl_status IN ('pending','processing','done','error')
    ),
    etl_error    TEXT
);

COMMENT ON TABLE staging.orders_raw IS 'Сирі вхідні замовлення';

CREATE INDEX idx_staging_orders_status ON staging.orders_raw (etl_status);

-- ----------------------------------------------------------------------------
-- Таблиця: staging.order_items_raw
-- ----------------------------------------------------------------------------
CREATE TABLE staging.order_items_raw (
    raw_item_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_external_id TEXT NOT NULL,
    source_code     TEXT NOT NULL,
    product_erp_id  TEXT NOT NULL,
    quantity        INT NOT NULL,
    price           DECIMAL(15,2) NOT NULL,
    currency_code   CHAR(3) NOT NULL DEFAULT 'UAH',
    delivery_date   TEXT,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    etl_status      VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        etl_status IN ('pending','processing','done','error')
    ),
    etl_error       TEXT
);

COMMENT ON TABLE staging.order_items_raw IS 'Сирі вхідні позиції замовлень';

CREATE INDEX idx_staging_items_status ON staging.order_items_raw (etl_status);
CREATE INDEX idx_staging_items_order ON staging.order_items_raw (order_external_id, source_code);

-- ----------------------------------------------------------------------------
-- Таблиця: staging.products_raw (для синхронізації довідників)
-- ----------------------------------------------------------------------------
CREATE TABLE staging.products_raw (
    raw_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    erp_id       TEXT NOT NULL,
    product_name TEXT,
    category_name TEXT,
    unit_code    TEXT,
    sku          TEXT,
    barcode      TEXT,
    weight       TEXT,
    received_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    etl_status   VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        etl_status IN ('pending','processing','done','error')
    ),
    etl_error    TEXT
);

COMMENT ON TABLE staging.products_raw IS 'Сирі дані товарів з ERP';

CREATE INDEX idx_staging_products_erp ON staging.products_raw (erp_id);
CREATE INDEX idx_staging_products_status ON staging.products_raw (etl_status);

-- ============================================================================
-- ЧАСТИНА 10: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View: v_storage_operations
-- ----------------------------------------------------------------------------
CREATE VIEW core.v_storage_operations AS
SELECT so.*,
       COALESCE(i.amount, 0)          AS amount,
       COALESCE(i.cost, 0)            AS cost
FROM core.storage_operations so
LEFT JOIN LATERAL (
    SELECT SUM(soi.quantity)               AS amount,
           SUM(soi.quantity * soi.price)   AS cost
    FROM core.storage_operation_items soi
    WHERE soi.operation_id = so.operation_id
) i ON TRUE;

COMMENT ON VIEW core.v_storage_operations IS 'Складські операції з обчисленими amount/cost';

-- ============================================================================
-- ЧАСТИНА 11: FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Функція: fn_get_rate_to_uah
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_get_rate_to_uah(
    p_from CHAR(3), p_on_date DATE
) RETURNS DECIMAL(18,6) AS $$
    SELECT CASE
        WHEN p_from = 'UAH' THEN 1::DECIMAL(18,6)
        ELSE (
            SELECT er.rate
            FROM core.exchange_rates er
            WHERE er.from_currency = p_from
              AND er.to_currency   = 'UAH'
              AND er.valid_from   <= p_on_date
              AND (er.valid_to IS NULL OR er.valid_to >= p_on_date)
            ORDER BY er.valid_from DESC
            LIMIT 1
        )
    END;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION core.fn_get_rate_to_uah IS 'Отримати курс валюти до UAH на дату';

-- ----------------------------------------------------------------------------
-- Функція: fn_get_rate
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_get_rate(
    p_from CHAR(3), p_to CHAR(3), p_on_date DATE
) RETURNS DECIMAL(18,6) AS $$
    SELECT CASE
        WHEN p_from = p_to THEN 1::DECIMAL(18,6)
        ELSE core.fn_get_rate_to_uah(p_from, p_on_date)
             / NULLIF(core.fn_get_rate_to_uah(p_to, p_on_date), 0)
    END;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION core.fn_get_rate IS 'Отримати курс конвертації між двома валютами';

-- ----------------------------------------------------------------------------
-- Функція: fn_change_balance
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_change_balance(
    p_storage_id UUID, p_product_id UUID, p_serial VARCHAR, p_lot VARCHAR,
    p_delta INT, p_date DATE, p_price DECIMAL(15,2), p_currency CHAR(3)
) RETURNS VOID AS $$
BEGIN
    IF p_storage_id IS NULL THEN
        RAISE EXCEPTION 'Storage is required for this movement (product %)', p_product_id;
    END IF;

    INSERT INTO core.storage_balances (
        storage_id, product_id, product_serial, product_lot_id,
        stock_in_date, product_count, price_base, currency_code
    ) VALUES (
        p_storage_id, p_product_id, p_serial, p_lot,
        p_date, p_delta, p_price, p_currency
    )
    ON CONFLICT (storage_id, product_id, product_serial, product_lot_id)
    DO UPDATE SET
        product_count = core.storage_balances.product_count + EXCLUDED.product_count,
        updated_at    = CURRENT_TIMESTAMP;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_change_balance IS 'Змінити залишок товару на складі (UPSERT)';

-- ----------------------------------------------------------------------------
-- Функція: fn_apply_item_to_balance (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_apply_item_to_balance() RETURNS TRIGGER AS $$
DECLARE
    v_op       core.storage_operations%ROWTYPE;
    v_eff_type VARCHAR(30);
BEGIN
    SELECT * INTO v_op FROM core.storage_operations WHERE operation_id = NEW.operation_id;

    IF v_op.operation_type = 'reversal' THEN
        SELECT operation_type INTO v_eff_type
        FROM core.storage_operations
        WHERE operation_id = v_op.reversal_of_operation_id;
        IF NEW.quantity >= 0 THEN
            RAISE EXCEPTION 'Reversal items must have negative quantity (operation %)', NEW.operation_id;
        END IF;
    ELSE
        v_eff_type := v_op.operation_type;
        IF NEW.quantity <= 0 THEN
            RAISE EXCEPTION '% items must have positive quantity (operation %)', v_eff_type, NEW.operation_id;
        END IF;
    END IF;

    IF v_eff_type IN ('receipt', 'transfer') THEN
        PERFORM core.fn_change_balance(
            v_op.storage_to_id, NEW.product_id, NEW.serial, NEW.lot_id,
            NEW.quantity, v_op.operation_date::DATE, NEW.price, NEW.currency_code
        );
    END IF;

    IF v_eff_type IN ('shipment', 'transfer', 'write-off') THEN
        PERFORM core.fn_change_balance(
            v_op.storage_from_id, NEW.product_id, NEW.serial, NEW.lot_id,
            -NEW.quantity, v_op.operation_date::DATE, NEW.price, NEW.currency_code
        );
    END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_apply_item_to_balance IS 'Тригер: оновлення залишків при INSERT в storage_operation_items';

-- ----------------------------------------------------------------------------
-- Функція: fn_prevent_item_modification (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_prevent_item_modification() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'storage_operation_items are immutable. Use reversal operation.';
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_prevent_item_modification IS 'Тригер: заборона UPDATE/DELETE на storage_operation_items';

-- ----------------------------------------------------------------------------
-- Функція: fn_prevent_operation_modification (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_prevent_operation_modification() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Cannot delete storage_operation %. Use reversal instead.', OLD.operation_id;
    END IF;

    IF OLD.operation_type            IS DISTINCT FROM NEW.operation_type
       OR OLD.operation_date         IS DISTINCT FROM NEW.operation_date
       OR OLD.user_id                IS DISTINCT FROM NEW.user_id
       OR OLD.storage_from_id        IS DISTINCT FROM NEW.storage_from_id
       OR OLD.storage_to_id          IS DISTINCT FROM NEW.storage_to_id
       OR OLD.order_id               IS DISTINCT FROM NEW.order_id
       OR OLD.client_id              IS DISTINCT FROM NEW.client_id
       OR OLD.reversal_of_operation_id IS DISTINCT FROM NEW.reversal_of_operation_id
    THEN
        RAISE EXCEPTION 'Only comments can be modified. Use reversal for corrections (operation %).', OLD.operation_id;
    END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_prevent_operation_modification IS 'Тригер: заборона DELETE/UPDATE ключових полів storage_operations';

-- ----------------------------------------------------------------------------
-- Функція: fn_validate_reversal (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_validate_reversal() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reversal_of_operation_id IS NOT NULL THEN
        IF NEW.reversal_of_operation_id = NEW.operation_id THEN
            RAISE EXCEPTION 'Operation cannot reverse itself';
        END IF;

        IF EXISTS (
            SELECT 1 FROM core.storage_operations
            WHERE operation_id = NEW.reversal_of_operation_id
              AND reversal_of_operation_id IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'Cannot reverse a reversal operation';
        END IF;
    END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_validate_reversal IS 'Тригер: валідація сторно при вставці';

-- ----------------------------------------------------------------------------
-- Функція: fn_reverse_storage_operation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_reverse_storage_operation(
    p_operation_id UUID,
    p_user_id      UUID
) RETURNS UUID AS $$
DECLARE
    v_original    core.storage_operations%ROWTYPE;
    v_reversal_id UUID;
BEGIN
    SELECT * INTO v_original
    FROM core.storage_operations
    WHERE operation_id = p_operation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Operation % not found', p_operation_id;
    END IF;

    IF v_original.operation_type = 'reversal' THEN
        RAISE EXCEPTION 'Cannot reverse a reversal operation';
    END IF;

    IF EXISTS (SELECT 1 FROM core.storage_operations
               WHERE reversal_of_operation_id = p_operation_id) THEN
        RAISE EXCEPTION 'Operation % already reversed', p_operation_id;
    END IF;

    INSERT INTO core.storage_operations (
        operation_type, operation_date, user_id,
        storage_from_id, storage_to_id,
        order_id, client_id,
        reversal_of_operation_id, comments
    ) VALUES (
        'reversal', CURRENT_TIMESTAMP, p_user_id,
        v_original.storage_from_id, v_original.storage_to_id,
        v_original.order_id, v_original.client_id,
        v_original.operation_id,
        'Reversal of operation ' || p_operation_id
    ) RETURNING operation_id INTO v_reversal_id;

    INSERT INTO core.storage_operation_items (
        operation_id, product_id, serial, lot_id, quantity, price, currency_code, custom_attributes
    )
    SELECT v_reversal_id, product_id, serial, lot_id, -quantity, price, currency_code, custom_attributes
    FROM core.storage_operation_items
    WHERE operation_id = p_operation_id;

    RETURN v_reversal_id;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_reverse_storage_operation IS 'Створити сторно операції';

-- ----------------------------------------------------------------------------
-- Функція: fn_validate_allocation_currency (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_validate_allocation_currency() RETURNS TRIGGER AS $$
DECLARE
    v_order_currency CHAR(3);
BEGIN
    SELECT currency_code INTO v_order_currency
    FROM core.order_financials
    WHERE order_id = NEW.order_id;

    IF v_order_currency IS NULL THEN
        RAISE EXCEPTION 'Order % has no financials record', NEW.order_id;
    END IF;

    IF NEW.allocated_amount_currency <> v_order_currency THEN
        RAISE EXCEPTION
            'Allocation currency % must equal order currency % (order %)',
            NEW.allocated_amount_currency, v_order_currency, NEW.order_id;
    END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_validate_allocation_currency IS 'Тригер: перевірка валюти allocation на вході';

-- ----------------------------------------------------------------------------
-- Функція: fn_recalc_paid_sum (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_recalc_paid_sum() RETURNS TRIGGER AS $$
BEGIN
    UPDATE core.order_financials ofin
    SET paid_sum = (
            SELECT COALESCE(SUM(pa.allocated_amount), 0)
            FROM core.payment_allocations pa
            WHERE pa.order_id = ofin.order_id
        )
    WHERE ofin.order_id = COALESCE(NEW.order_id, OLD.order_id);

    -- Якщо order_id алокації змінили при UPDATE, старе замовлення теж треба перерахувати
    IF TG_OP = 'UPDATE' AND OLD.order_id IS DISTINCT FROM NEW.order_id THEN
        UPDATE core.order_financials ofin
        SET paid_sum = (
                SELECT COALESCE(SUM(pa.allocated_amount), 0)
                FROM core.payment_allocations pa
                WHERE pa.order_id = ofin.order_id
            )
        WHERE ofin.order_id = OLD.order_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_recalc_paid_sum IS 'Тригер: перерахунок paid_sum при зміні payment_allocations';

-- ----------------------------------------------------------------------------
-- Функція: fn_update_category_path (тригер)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.fn_update_category_path() RETURNS TRIGGER AS $$
DECLARE
    parent_path TEXT;
BEGIN
    IF TG_OP = 'UPDATE' AND EXISTS (
        SELECT 1 FROM core.product_categories WHERE parent_id = NEW.category_id
    ) THEN
        RAISE EXCEPTION 'Cannot re-parent category % with children', NEW.category_id;
    END IF;

    IF NEW.parent_id IS NULL THEN
        NEW.materialized_path := '/' || NEW.category_id::TEXT || '/';
    ELSE
        SELECT materialized_path INTO parent_path
        FROM core.product_categories WHERE category_id = NEW.parent_id;
        IF parent_path IS NULL THEN
            RAISE EXCEPTION 'Parent category % not found', NEW.parent_id;
        END IF;
        IF parent_path LIKE '%/' || NEW.category_id::TEXT || '/%' THEN
            RAISE EXCEPTION 'Cycle detected: % is a descendant of %', NEW.parent_id, NEW.category_id;
        END IF;
        NEW.materialized_path := parent_path || NEW.category_id::TEXT || '/';
    END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_update_category_path IS 'Тригер: підтримка materialized_path для категорій';

-- ----------------------------------------------------------------------------
-- Функція: etl.process_order
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION etl.process_order(p_raw_id UUID) RETURNS VOID AS $$
DECLARE
    v_raw       staging.orders_raw%ROWTYPE;
    v_client_id UUID;
    v_user_id   UUID;
    v_status_id UUID;
    v_order_id  UUID;
    v_source_id UUID;
BEGIN
    SELECT * INTO v_raw FROM staging.orders_raw WHERE raw_id = p_raw_id;
    IF NOT FOUND THEN RETURN; END IF;

    IF v_raw.order_sum IS NULL OR v_raw.order_sum !~ '^\d+(\.\d{1,2})?$' THEN
        UPDATE staging.orders_raw
        SET etl_status = 'error', etl_error = 'Invalid or missing order_sum'
        WHERE raw_id = p_raw_id;
        RETURN;
    END IF;

    IF v_raw.external_id IS NULL THEN
        UPDATE staging.orders_raw
        SET etl_status = 'error', etl_error = 'Missing external_id'
        WHERE raw_id = p_raw_id;
        RETURN;
    END IF;

    SELECT order_source_id INTO v_source_id
    FROM core.order_sources WHERE source_code = v_raw.source_code;
    IF v_source_id IS NULL THEN
        UPDATE staging.orders_raw
        SET etl_status = 'error', etl_error = 'Unknown source_code: ' || COALESCE(v_raw.source_code,'<null>')
        WHERE raw_id = p_raw_id;
        RETURN;
    END IF;

    INSERT INTO core.clients (erp_id, client_name)
    VALUES (v_raw.client_erp_id, v_raw.client_name)
    ON CONFLICT (erp_id) DO UPDATE SET client_name = EXCLUDED.client_name
    RETURNING client_id INTO v_client_id;

    SELECT user_id   INTO v_user_id   FROM core.users          WHERE user_name   = v_raw.manager_name;
    SELECT status_id INTO v_status_id FROM core.order_statuses WHERE status_name = v_raw.status_name;

    INSERT INTO core.orders (
        order_number, order_date, manager_id, author_id,
        status_id, order_source_id, external_id
    ) VALUES (
        v_raw.order_id, v_raw.order_date::DATE, v_user_id, v_user_id,
        v_status_id, v_source_id, v_raw.external_id
    )
    ON CONFLICT (order_source_id, external_id) DO UPDATE SET
        order_date = EXCLUDED.order_date,
        manager_id = EXCLUDED.manager_id,
        status_id  = EXCLUDED.status_id
    RETURNING order_id INTO v_order_id;

    INSERT INTO core.order_roles (order_id, role_type, party_id, is_primary)
    VALUES (v_order_id, 'customer', v_client_id, TRUE)
    ON CONFLICT (order_id, role_type, party_id) DO UPDATE SET is_primary = TRUE;

    INSERT INTO core.order_financials (order_id, order_sum, currency_code)
    VALUES (v_order_id, v_raw.order_sum::DECIMAL(15,2), 'UAH')
    ON CONFLICT (order_id) DO UPDATE SET
        order_sum = EXCLUDED.order_sum;

    UPDATE staging.orders_raw SET etl_status = 'done' WHERE raw_id = p_raw_id;

EXCEPTION WHEN OTHERS THEN
    UPDATE staging.orders_raw
    SET etl_status = 'error', etl_error = SQLERRM
    WHERE raw_id = p_raw_id;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION etl.process_order IS 'ETL: імпорт замовлення з staging';

-- ----------------------------------------------------------------------------
-- Функція: etl.process_order_items
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION etl.process_order_items(p_raw_item_id UUID) RETURNS VOID AS $$
DECLARE
    v_raw       staging.order_items_raw%ROWTYPE;
    v_order_id  UUID;
    v_product_id UUID;
BEGIN
    SELECT * INTO v_raw FROM staging.order_items_raw WHERE raw_item_id = p_raw_item_id;
    IF NOT FOUND THEN RETURN; END IF;

    IF v_raw.product_erp_id IS NULL OR v_raw.product_erp_id = '' THEN
        UPDATE staging.order_items_raw
        SET etl_status = 'error', etl_error = 'Missing product_erp_id'
        WHERE raw_item_id = p_raw_item_id;
        RETURN;
    END IF;

    IF v_raw.quantity <= 0 THEN
        UPDATE staging.order_items_raw
        SET etl_status = 'error', etl_error = 'Quantity must be positive'
        WHERE raw_item_id = p_raw_item_id;
        RETURN;
    END IF;

    SELECT order_id INTO v_order_id
    FROM core.orders
    WHERE external_id = v_raw.order_external_id
      AND order_source_id = (SELECT order_source_id FROM core.order_sources WHERE source_code = v_raw.source_code);
    
    IF v_order_id IS NULL THEN
        UPDATE staging.order_items_raw
        SET etl_status = 'error', etl_error = 'Order not found: ' || v_raw.order_external_id
        WHERE raw_item_id = p_raw_item_id;
        RETURN;
    END IF;

    SELECT product_id INTO v_product_id
    FROM core.products
    WHERE erp_id = v_raw.product_erp_id
      AND is_deleted = FALSE;
    
    IF v_product_id IS NULL THEN
        UPDATE staging.order_items_raw
        SET etl_status = 'error', etl_error = 'Product not found by erp_id: ' || v_raw.product_erp_id
        WHERE raw_item_id = p_raw_item_id;
        RETURN;
    END IF;

    INSERT INTO core.order_items (
        order_id, product_id, product_count, product_price, currency_code, delivery_date
    ) VALUES (
        v_order_id, v_product_id, v_raw.quantity, v_raw.price, v_raw.currency_code,
        v_raw.delivery_date::DATE
    );

    UPDATE staging.order_items_raw SET etl_status = 'done' WHERE raw_item_id = p_raw_item_id;

EXCEPTION WHEN OTHERS THEN
    UPDATE staging.order_items_raw
    SET etl_status = 'error', etl_error = SQLERRM
    WHERE raw_item_id = p_raw_item_id;
END; $$ LANGUAGE plpgsql;

COMMENT ON FUNCTION etl.process_order_items IS 'ETL: імпорт позицій замовлення з staging (зіставлення по erp_id)';

-- ============================================================================
-- ЧАСТИНА 12: TRIGGERS
-- ============================================================================

-- Тригери для storage_operation_items
CREATE TRIGGER trg_apply_item_to_balance
    AFTER INSERT ON core.storage_operation_items
    FOR EACH ROW EXECUTE FUNCTION core.fn_apply_item_to_balance();

CREATE TRIGGER trg_prevent_item_modification
    BEFORE UPDATE OR DELETE ON core.storage_operation_items
    FOR EACH ROW EXECUTE FUNCTION core.fn_prevent_item_modification();

-- Тригери для storage_operations
CREATE TRIGGER trg_prevent_operation_modification
    BEFORE UPDATE OR DELETE ON core.storage_operations
    FOR EACH ROW EXECUTE FUNCTION core.fn_prevent_operation_modification();

CREATE TRIGGER trg_validate_reversal
    BEFORE INSERT ON core.storage_operations
    FOR EACH ROW EXECUTE FUNCTION core.fn_validate_reversal();

-- Тригери для payment_allocations
CREATE TRIGGER trg_validate_allocation_currency
    BEFORE INSERT OR UPDATE ON core.payment_allocations
    FOR EACH ROW EXECUTE FUNCTION core.fn_validate_allocation_currency();

CREATE TRIGGER trg_recalc_paid_sum
    AFTER INSERT OR UPDATE OR DELETE ON core.payment_allocations
    FOR EACH ROW EXECUTE FUNCTION core.fn_recalc_paid_sum();

-- Тригер для product_categories
CREATE TRIGGER trg_update_category_path
    BEFORE INSERT OR UPDATE OF parent_id ON core.product_categories
    FOR EACH ROW EXECUTE FUNCTION core.fn_update_category_path();

-- Тригери для updated_at (moddatetime)
CREATE TRIGGER trg_clients_moddatetime           BEFORE UPDATE ON core.clients            FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_orders_moddatetime            BEFORE UPDATE ON core.orders             FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_order_financials_moddatetime  BEFORE UPDATE ON core.order_financials   FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_order_logistics_moddatetime   BEFORE UPDATE ON core.order_logistics    FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_order_obligations_moddatetime BEFORE UPDATE ON core.order_obligations  FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_storage_balances_moddatetime  BEFORE UPDATE ON core.storage_balances   FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_products_moddatetime          BEFORE UPDATE ON core.products           FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
CREATE TRIGGER trg_storages_moddatetime          BEFORE UPDATE ON core.storages           FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);

-- ============================================================================
-- ЧАСТИНА 13: MATERIALIZED VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Materialized View: mv_inventory_report
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW core.mv_inventory_report AS
SELECT
    s.storage_name,
    s.erp_id AS storage_erp_id,
    p.product_name,
    p.erp_id AS product_erp_id,
    p.sku,
    sb.currency_code,
    SUM(sb.product_count)                    AS total_stock,
    SUM(sb.product_reserved)                 AS total_reserved,
    SUM(sb.product_count * sb.price_base)    AS total_value_in_currency,
    SUM(sb.product_count * sb.price_base
        * core.fn_get_rate(sb.currency_code, 'UAH', sb.stock_in_date)) AS total_value_uah
FROM core.storage_balances sb
JOIN core.storages s  ON sb.storage_id = s.storage_id
JOIN core.products p  ON sb.product_id = p.product_id
GROUP BY s.storage_name, s.erp_id, p.product_name, p.erp_id, p.sku, sb.currency_code;

COMMENT ON MATERIALIZED VIEW core.mv_inventory_report IS 'Звіт по залишках з конвертацією в UAH';

CREATE UNIQUE INDEX uq_mv_inventory
    ON core.mv_inventory_report (storage_erp_id, product_erp_id, currency_code);

CREATE INDEX idx_mv_inventory_sku ON core.mv_inventory_report (sku);
