DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path TO shop;

-- [Αυτά τα έδινε έτοιμα το PDF]
CREATE TABLE customer ( 
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
    email VARCHAR ( 255 ) NOT NULL UNIQUE, 
    first_name VARCHAR ( 80 ) NOT NULL, 
    last_name VARCHAR ( 80 ) NOT NULL, 
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE address ( 
    address_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
    customer_id BIGINT NOT NULL REFERENCES customer ON DELETE CASCADE, 
    line1 VARCHAR ( 120 ) NOT NULL, 
    city VARCHAR ( 80 ) NOT NULL, 
    postcode VARCHAR ( 20 ) NOT NULL,
    country CHAR ( 2 ) NOT NULL, 
    is_default BOOLEAN NOT NULL DEFAULT FALSE 
);

-- [Αυτή είναι η λύση για το TODO: category, product, orders, order_item]
CREATE TABLE category (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE product (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL REFERENCES category ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL
);

CREATE TABLE orders (
    order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customer ON DELETE RESTRICT,
    order_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL,
    total NUMERIC(10, 2) NOT NULL DEFAULT 0.00
);

CREATE TABLE order_item (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES product ON DELETE RESTRICT,
    quantity INT NOT NULL,
    unit_price_at_sale NUMERIC(10, 2) NOT NULL
);