CREATE TABLE IF NOT EXISTS products_raw (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_id VARCHAR(50),
    product_category_name VARCHAR(255),
    product_name TEXT,
    product_deleted VARCHAR(50),
    product_unit VARCHAR(100),
    product_cdate TIMESTAMP,
    Pershiirivenkategori VARCHAR(255),
    Drugiirivenkategori VARCHAR(255),
    Tretiirivenkategori VARCHAR(255),
    CHetvertiirivenkategori VARCHAR(255),
    IDpershogorivnyakategori VARCHAR(50),
    IDdrugogorivnyakategori VARCHAR(50),
    IDtretogorivnyakategori VARCHAR(50),
    IDchetvertogorivnyakategori VARCHAR(50)
);