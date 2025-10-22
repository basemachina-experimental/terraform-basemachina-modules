-- ========================================
-- Database Initialization Script
-- ========================================
-- このスクリプトは、Cloud SQLデータベースに
-- サンプルテーブルとデータを作成します

-- ========================================
-- Users Table
-- ========================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- Products Table
-- ========================================
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- Orders Table
-- ========================================
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    total_price DECIMAL(10, 2) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- Sample Data: Users
-- ========================================
INSERT INTO users (username, email) VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com')
ON CONFLICT (username) DO NOTHING;

-- ========================================
-- Sample Data: Products
-- ========================================
INSERT INTO products (name, description, price) VALUES
    ('Product A', 'Description for Product A', 100.00),
    ('Product B', 'Description for Product B', 200.00),
    ('Product C', 'Description for Product C', 300.00)
ON CONFLICT DO NOTHING;

-- ========================================
-- Sample Data: Orders
-- ========================================
INSERT INTO orders (user_id, product_id, quantity, total_price) VALUES
    (1, 1, 2, 200.00),
    (2, 2, 1, 200.00),
    (3, 3, 3, 900.00)
ON CONFLICT DO NOTHING;

-- ========================================
-- Verification Queries
-- ========================================
-- 作成されたデータを確認

SELECT 'Users:' AS table_name;
SELECT * FROM users;

SELECT 'Products:' AS table_name;
SELECT * FROM products;

SELECT 'Orders:' AS table_name;
SELECT * FROM orders;
