-- Sample Data Seed Script for PostgreSQL

-- Create products table (via Flyway migration - this is sample data only)
INSERT INTO products (name, description, price) VALUES
('Laptop Pro 15', 'High-performance laptop with 15-inch display', 1299.99),
('Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 29.99),
('Mechanical Keyboard', 'RGB backlit mechanical gaming keyboard', 89.99),
('USB-C Hub', '7-in-1 USB-C hub with HDMI and ethernet', 49.99),
('Laptop Stand', 'Aluminum adjustable laptop stand', 39.99),
('Webcam HD', '1080p HD webcam with built-in microphone', 79.99),
('Headphones Pro', 'Noise-canceling over-ear headphones', 199.99),
('External SSD 1TB', 'Portable external SSD with USB-C', 129.99),
('Monitor 27"', '27-inch 4K IPS monitor', 399.99),
('Desk Mat XL', 'Extra large desk mat for keyboard and mouse', 24.99);

-- Create sample orders
INSERT INTO orders (product_id, quantity, status) VALUES
(1, 2, 'completed'),
(3, 1, 'completed'),
(5, 3, 'processing'),
(7, 1, 'completed'),
(9, 1, 'shipped'),
(2, 5, 'completed'),
(4, 2, 'processing'),
(6, 1, 'completed'),
(8, 2, 'shipped'),
(10, 4, 'completed');

-- Initialize file processing logs table (will be populated by worker)
-- INSERT INTO file_processing_logs (file_name, file_size, status, processed_at) VALUES
-- ('sample-data.csv', 1024, 'pending', NOW());
