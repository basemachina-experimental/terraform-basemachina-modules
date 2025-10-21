-- ========================================
-- BaseMachina Bridge Database Initialization
-- ========================================
-- This script initializes the database with sample data
-- for testing and development purposes.

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert seed data
INSERT INTO users (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Charlie Brown', 'charlie@example.com'),
    ('Diana Prince', 'diana@example.com'),
    ('Ethan Hunt', 'ethan@example.com')
ON CONFLICT (email) DO NOTHING;

-- Verify data
SELECT COUNT(*) AS user_count FROM users;
SELECT * FROM users ORDER BY id;
