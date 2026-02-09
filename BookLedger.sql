-- Drop triggers first
-- Triggers depend on tables, so they must be removed before dropping tables
DROP TRIGGER IF EXISTS trg_sales_trust_reward ON sales_header CASCADE;
DROP TRIGGER IF EXISTS trg_returns_trust_penalty ON returns CASCADE;
DROP TRIGGER IF EXISTS trg_auto_loyalty ON sales_header CASCADE;
DROP TRIGGER IF EXISTS trg_audit_book_changes ON books CASCADE;

-- Drop materialized views
DROP MATERIALIZED VIEW IF EXISTS mv_dashboard_genre_trends CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_dashboard_top_authors CASCADE;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS returns CASCADE;
DROP TABLE IF EXISTS purchase_order_details CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS book_assets CASCADE;
DROP TABLE IF EXISTS sales_details CASCADE;
DROP TABLE IF EXISTS sales_header CASCADE;
DROP TABLE IF EXISTS book_authors CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS authors CASCADE;
DROP TABLE IF EXISTS genres CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;

-- Drop sequences
DROP SEQUENCE IF EXISTS seq_customer_id CASCADE;
DROP SEQUENCE IF EXISTS seq_sale_id CASCADE;
DROP SEQUENCE IF EXISTS seq_po_id CASCADE;

-- Drop functions and procedures
DROP FUNCTION IF EXISTS fn_smart_search CASCADE;
DROP FUNCTION IF EXISTS fn_adjust_trust_score CASCADE;
DROP FUNCTION IF EXISTS fn_get_vip_price CASCADE;
DROP FUNCTION IF EXISTS trg_func_reward_purchase CASCADE;
DROP FUNCTION IF EXISTS trg_func_penalize_return CASCADE;
DROP FUNCTION IF EXISTS trg_func_calculate_loyalty CASCADE;
DROP FUNCTION IF EXISTS trg_func_audit_books CASCADE;
DROP PROCEDURE IF EXISTS proc_atomic_checkout CASCADE;
DROP PROCEDURE IF EXISTS proc_add_book_asset CASCADE;
DROP PROCEDURE IF EXISTS proc_auto_restock CASCADE;
DROP PROCEDURE IF EXISTS prc_refresh_dashboards CASCADE;

-- Customers table with trust score and loyalty points
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    membership_pts INT DEFAULT 0 CHECK (membership_pts >= 0),
    trust_score INT DEFAULT 100 CHECK (trust_score >= 0 AND trust_score <= 100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Suppliers table
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE,
    contact_email VARCHAR(100),
    contact_phone VARCHAR(20),
    credit_terms VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Genres table for book categorization
CREATE TABLE genres (
    genre_id SERIAL PRIMARY KEY,
    genre_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- Authors table
CREATE TABLE authors (
    author_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    biography TEXT,
    country VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Books table
CREATE TABLE books (
    isbn VARCHAR(20) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    genre_id INT NOT NULL REFERENCES genres(genre_id) ON DELETE RESTRICT,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock_qty INT DEFAULT 0 CHECK (stock_qty >= 0),
    supplier_id INT REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    publication_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Book-Authors junction table (many-to-many relationship)
CREATE TABLE book_authors (
    isbn VARCHAR(20) REFERENCES books(isbn) ON DELETE CASCADE,
    author_id INT REFERENCES authors(author_id) ON DELETE CASCADE,
    author_order INT DEFAULT 1, -- For multiple authors
    PRIMARY KEY (isbn, author_id)
);

-- Book assets table for additional media
CREATE TABLE book_assets (
    asset_id SERIAL PRIMARY KEY,
    isbn VARCHAR(20) NOT NULL REFERENCES books(isbn) ON DELETE CASCADE,
    cover_image BYTEA, -- Using BYTEA instead of BLOB for PostgreSQL
    preview_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sales header table
CREATE TABLE sales_header (
    sale_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    payment_method VARCHAR(20) DEFAULT 'CASH',
    status VARCHAR(20) DEFAULT 'COMPLETED',
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('CASH', 'CARD', 'ONLINE', 'POINTS'))
);

-- Sales details table
CREATE TABLE sales_details (
    sale_id INT REFERENCES sales_header(sale_id) ON DELETE CASCADE,
    isbn VARCHAR(20) REFERENCES books(isbn) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    line_total NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    PRIMARY KEY (sale_id, isbn)
);

-- Purchase orders table
CREATE TABLE purchase_orders (
    po_id SERIAL PRIMARY KEY,
    supplier_id INT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'DRAFT',
    total_amount NUMERIC(10,2) DEFAULT 0,
    received_date TIMESTAMP,
    CONSTRAINT chk_po_status CHECK (status IN ('DRAFT', 'SUBMITTED', 'RECEIVED', 'CANCELLED'))
);

-- Purchase order details table
CREATE TABLE purchase_order_details (
    po_id INT REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
    isbn VARCHAR(20) REFERENCES books(isbn) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_cost NUMERIC(10,2) NOT NULL CHECK (unit_cost > 0),
    line_total NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    PRIMARY KEY (po_id, isbn)
);

-- Returns table for tracking product returns
CREATE TABLE returns (
    return_id SERIAL PRIMARY KEY,
    sale_id INT NOT NULL REFERENCES sales_header(sale_id) ON DELETE RESTRICT,
    isbn VARCHAR(20) NOT NULL REFERENCES books(isbn) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    condition VARCHAR(20) NOT NULL,
    reason TEXT,
    return_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    refund_amount NUMERIC(10,2) NOT NULL CHECK (refund_amount >= 0),
    CONSTRAINT chk_return_condition CHECK (condition IN ('GOOD', 'DAMAGED', 'DEFECTIVE'))
);

-- Audit logs table for tracking changes
CREATE TABLE audit_logs (
    log_id SERIAL PRIMARY KEY,
    target_table VARCHAR(50) NOT NULL,
    target_pk VARCHAR(50) NOT NULL,
    action_type VARCHAR(10) NOT NULL,
    column_changed VARCHAR(50),
    old_value TEXT,
    new_value TEXT,
    changed_by VARCHAR(50) DEFAULT CURRENT_USER,
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_action_type CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- ============================================================================
-- SEQUENCES (for Oracle compatibility, though PostgreSQL uses SERIAL)
-- ============================================================================

CREATE SEQUENCE seq_customer_id START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_sale_id START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE seq_po_id START WITH 5000 INCREMENT BY 1;

-- Set sequences to match SERIAL columns
ALTER SEQUENCE seq_customer_id OWNED BY customers.customer_id;
ALTER SEQUENCE seq_sale_id OWNED BY sales_header.sale_id;
ALTER SEQUENCE seq_po_id OWNED BY purchase_orders.po_id;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Books table indexes
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_books_genre ON books(genre_id);
CREATE INDEX idx_books_supplier ON books(supplier_id);
CREATE INDEX idx_books_stock ON books(stock_qty) WHERE stock_qty < 5;

-- Sales indexes
CREATE INDEX idx_sales_header_customer ON sales_header(customer_id);
CREATE INDEX idx_sales_header_date ON sales_header(sale_date DESC);
CREATE INDEX idx_sales_details_isbn ON sales_details(isbn);

-- Customers indexes
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_trust_score ON customers(trust_score DESC);

-- Audit logs indexes
CREATE INDEX idx_audit_logs_table ON audit_logs(target_table, target_pk);
CREATE INDEX idx_audit_logs_time ON audit_logs(change_time DESC);

-- Book authors indexes
CREATE INDEX idx_book_authors_author ON book_authors(author_id);

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

-- Function to adjust customer trust score
CREATE OR REPLACE FUNCTION fn_adjust_trust_score(
    p_customer_id INT,
    p_points INT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_score INT;
    v_new_score INT;
BEGIN
    SELECT trust_score INTO v_current_score
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer ID % not found', p_customer_id;
    END IF;

    v_new_score := v_current_score + p_points;

    -- Clamp the score between 0 and 100
    IF v_new_score > 100 THEN
        v_new_score := 100;
    ELSIF v_new_score < 0 THEN
        v_new_score := 0;
    END IF;

    UPDATE customers
    SET trust_score = v_new_score,
        updated_at = CURRENT_TIMESTAMP
    WHERE customer_id = p_customer_id;
   
END;
$$;

-- Function to get VIP pricing based on trust score
CREATE OR REPLACE FUNCTION fn_get_vip_price(
    p_isbn VARCHAR,
    p_customer_id INT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_base_price NUMERIC;
    v_trust_score INT;
    v_final_price NUMERIC;
BEGIN
    -- Get base price
    SELECT price INTO v_base_price
    FROM books
    WHERE isbn = p_isbn;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book with ISBN % not found', p_isbn;
    END IF;
   
    -- Get customer trust score
    SELECT trust_score INTO v_trust_score
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer ID % not found', p_customer_id;
    END IF;

    -- Apply discount or surcharge based on trust score
    IF v_trust_score >= 90 THEN
        v_final_price := v_base_price * 0.85; -- 15% VIP discount
    ELSIF v_trust_score >= 75 THEN
        v_final_price := v_base_price * 0.95; -- 5% good customer discount
    ELSIF v_trust_score < 30 THEN
        v_final_price := v_base_price * 1.10; -- 10% risk surcharge
    ELSE
        v_final_price := v_base_price; -- Standard price
    END IF;

    RETURN ROUND(v_final_price, 2);
END;
$$;
-- Smart search function with dynamic SQL
CREATE OR REPLACE FUNCTION fn_smart_search(
    p_title TEXT DEFAULT NULL,
    p_author TEXT DEFAULT NULL,
    p_genre TEXT DEFAULT NULL,
    p_min_price NUMERIC DEFAULT NULL,
    p_max_price NUMERIC DEFAULT NULL
)
RETURNS TABLE (
    isbn VARCHAR,
    book_title VARCHAR,
    author_name VARCHAR,
    genre VARCHAR,
    price NUMERIC,
    stock INT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    v_sql := 'SELECT DISTINCT
                b.isbn, 
                b.title, 
                a.full_name, 
                g.genre_name, 
                b.price, 
                b.stock_qty
              FROM books b
              JOIN book_authors ba ON b.isbn = ba.isbn
              JOIN authors a ON ba.author_id = a.author_id
              JOIN genres g ON b.genre_id = g.genre_id
              WHERE 1=1 ';

    IF p_title IS NOT NULL THEN
        v_sql := v_sql || ' AND b.title ILIKE ' || quote_literal('%' || p_title || '%');
    END IF;

    IF p_author IS NOT NULL THEN
        v_sql := v_sql || ' AND a.full_name ILIKE ' || quote_literal('%' || p_author || '%');
    END IF;

    IF p_genre IS NOT NULL THEN
        v_sql := v_sql || ' AND g.genre_name ILIKE ' || quote_literal('%' || p_genre || '%');
    END IF;

    IF p_min_price IS NOT NULL THEN
        v_sql := v_sql || ' AND b.price >= ' || p_min_price;
    END IF;
    
    IF p_max_price IS NOT NULL THEN
        v_sql := v_sql || ' AND b.price <= ' || p_max_price;
    END IF;

    v_sql := v_sql || ' ORDER BY b.title';

    RETURN QUERY EXECUTE v_sql;
END;
$$;

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

-- Atomic checkout procedure with full transaction handling
CREATE OR REPLACE PROCEDURE proc_atomic_checkout(
    p_customer_id INT,
    p_isbn VARCHAR,
    p_qty INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_price NUMERIC;
    v_stock INT;
    v_sale_id INT;
    v_total_cost NUMERIC;
    v_vip_price NUMERIC;
BEGIN
    -- Lock the book row for update
    SELECT stock_qty, price
    INTO v_stock, v_price
    FROM books
    WHERE isbn = p_isbn
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book with ISBN % not found', p_isbn;
    END IF;

    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', v_stock, p_qty;
    END IF;

    -- Get VIP pricing for the customer
    v_vip_price := fn_get_vip_price(p_isbn, p_customer_id);
    v_total_cost := v_vip_price * p_qty;

    -- Create sale header
    INSERT INTO sales_header (customer_id, total_amount)
    VALUES (p_customer_id, v_total_cost)
    RETURNING sale_id INTO v_sale_id;

    -- Create sale details
    INSERT INTO sales_details (sale_id, isbn, quantity, unit_price)
    VALUES (v_sale_id, p_isbn, p_qty, v_vip_price);

    -- Update book stock
    UPDATE books
    SET stock_qty = stock_qty - p_qty,
        updated_at = CURRENT_TIMESTAMP
    WHERE isbn = p_isbn;

    -- Update customer membership points (1 point per $10 spent)
    UPDATE customers
    SET membership_pts = membership_pts + FLOOR(v_total_cost / 10),
        updated_at = CURRENT_TIMESTAMP
    WHERE customer_id = p_customer_id;

    RAISE NOTICE 'Checkout successful. Sale ID: %, Total: $%', v_sale_id, v_total_cost;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Checkout failed: %', SQLERRM;
END;
$$;

-- Procedure to add book assets
CREATE OR REPLACE PROCEDURE proc_add_book_asset(
    p_isbn VARCHAR,
    p_preview TEXT DEFAULT NULL,
    p_cover_image BYTEA DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if book exists
    IF NOT EXISTS (SELECT 1 FROM books WHERE isbn = p_isbn) THEN
        RAISE EXCEPTION 'Book with ISBN % not found', p_isbn;
    END IF;

    INSERT INTO book_assets (isbn, preview_text, cover_image)
    VALUES (p_isbn, p_preview, p_cover_image);

    RAISE NOTICE 'Book asset added successfully for ISBN: %', p_isbn;
END;
$$;

-- Auto-restock procedure for low inventory
CREATE OR REPLACE PROCEDURE proc_auto_restock()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec RECORD;
    v_po_id INT;
    v_restock_qty INT := 10; -- Default restock quantity
    v_po_count INT := 0;
BEGIN
    -- Loop through books with low stock
    FOR v_rec IN 
        SELECT isbn, supplier_id, price, stock_qty
        FROM books
        WHERE stock_qty < 5 AND supplier_id IS NOT NULL
        ORDER BY stock_qty ASC
    LOOP
        -- Create purchase order
        INSERT INTO purchase_orders (supplier_id, status, total_amount)
        VALUES (v_rec.supplier_id, 'DRAFT', 0)
        RETURNING po_id INTO v_po_id;

        -- Add purchase order details
        INSERT INTO purchase_order_details (po_id, isbn, quantity, unit_cost)
        VALUES (v_po_id, v_rec.isbn, v_restock_qty, v_rec.price * 0.6); -- Assume 40% margin

        -- Update purchase order total
        UPDATE purchase_orders
        SET total_amount = v_restock_qty * (v_rec.price * 0.6)
        WHERE po_id = v_po_id;

        v_po_count := v_po_count + 1;
    END LOOP;

    RAISE NOTICE 'Auto restock completed. Created % purchase orders', v_po_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Restock failed: %', SQLERRM;
END;
$$;

-- Procedure to receive purchase order and update stock
CREATE OR REPLACE PROCEDURE proc_receive_purchase_order(
    p_po_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec RECORD;
    v_status VARCHAR(20);
BEGIN
    -- Check if PO exists and is in correct status
    SELECT status INTO v_status
    FROM purchase_orders
    WHERE po_id = p_po_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase order % not found', p_po_id;
    END IF;

    IF v_status = 'RECEIVED' THEN
        RAISE EXCEPTION 'Purchase order % already received', p_po_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Purchase order % is cancelled', p_po_id;
    END IF;

    -- Update stock for each item in the purchase order
    FOR v_rec IN 
        SELECT isbn, quantity
        FROM purchase_order_details
        WHERE po_id = p_po_id
    LOOP
        UPDATE books
        SET stock_qty = stock_qty + v_rec.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE isbn = v_rec.isbn;
    END LOOP;

    -- Update purchase order status
    UPDATE purchase_orders
    SET status = 'RECEIVED',
        received_date = CURRENT_TIMESTAMP
    WHERE po_id = p_po_id;

    RAISE NOTICE 'Purchase order % received successfully', p_po_id;
END;
$$;

-- Procedure to refresh dashboard materialized views
CREATE OR REPLACE PROCEDURE prc_refresh_dashboards()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_genre_trends;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_top_authors;
    
    RAISE NOTICE 'Executive dashboards updated successfully at %', NOW();
END;
$$;

-- ============================================================================
-- TRIGGER FUNCTIONS
-- ============================================================================

-- Trigger function to reward purchases with trust points
CREATE OR REPLACE FUNCTION trg_func_reward_purchase()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.total_amount > 50.00 THEN
        PERFORM fn_adjust_trust_score(NEW.customer_id, 2);
    END IF;
    RETURN NEW;
END;
$$;

-- Trigger function to penalize returns
CREATE OR REPLACE FUNCTION trg_func_penalize_return()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_cust_id INT;
BEGIN
    SELECT customer_id INTO v_cust_id 
    FROM sales_header 
    WHERE sale_id = NEW.sale_id;
    
    IF NEW.condition = 'DAMAGED' THEN
        PERFORM fn_adjust_trust_score(v_cust_id, -15); -- Heavy penalty
    ELSIF NEW.condition = 'DEFECTIVE' THEN
        PERFORM fn_adjust_trust_score(v_cust_id, -5); -- Moderate penalty
    ELSIF NEW.condition = 'GOOD' THEN
        PERFORM fn_adjust_trust_score(v_cust_id, -2); -- Minor penalty
    END IF;

    -- Restock the returned item
    UPDATE books
    SET stock_qty = stock_qty + NEW.quantity
    WHERE isbn = NEW.isbn;

    RETURN NEW;
END;
$$;

-- Trigger function to calculate loyalty points
CREATE OR REPLACE FUNCTION trg_func_calculate_loyalty()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_points_to_add INT;
    v_multiplier NUMERIC;
BEGIN
    -- Determine multiplier based on purchase amount
    IF NEW.total_amount > 100.00 THEN
        v_multiplier := 0.10; -- 10% for gold tier
    ELSE
        v_multiplier := 0.05; -- 5% for silver tier
    END IF;

    v_points_to_add := FLOOR(NEW.total_amount * v_multiplier);

    UPDATE customers
    SET membership_pts = membership_pts + v_points_to_add,
        updated_at = CURRENT_TIMESTAMP
    WHERE customer_id = NEW.customer_id;

    RETURN NEW;
END;
$$;

-- Trigger function to audit book changes
CREATE OR REPLACE FUNCTION trg_func_audit_books()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Audit price changes
    IF NEW.price IS DISTINCT FROM OLD.price THEN
        INSERT INTO audit_logs (
            target_table, target_pk, action_type, column_changed,
            old_value, new_value
        )
        VALUES (
            'books', OLD.isbn, 'UPDATE', 'price',
            OLD.price::TEXT, NEW.price::TEXT
        );
    END IF;

    -- Audit stock quantity changes
    IF NEW.stock_qty IS DISTINCT FROM OLD.stock_qty THEN
        INSERT INTO audit_logs (
            target_table, target_pk, action_type, column_changed,
            old_value, new_value
        )
        VALUES (
            'books', OLD.isbn, 'UPDATE', 'stock_qty',
            OLD.stock_qty::TEXT, NEW.stock_qty::TEXT
        );
    END IF;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger to reward purchases with trust score
CREATE TRIGGER trg_sales_trust_reward
AFTER INSERT ON sales_header
FOR EACH ROW
EXECUTE FUNCTION trg_func_reward_purchase();

-- Trigger to penalize returns
CREATE TRIGGER trg_returns_trust_penalty
AFTER INSERT ON returns
FOR EACH ROW
EXECUTE FUNCTION trg_func_penalize_return();

-- Trigger to calculate loyalty points
CREATE TRIGGER trg_auto_loyalty
AFTER INSERT ON sales_header
FOR EACH ROW
EXECUTE FUNCTION trg_func_calculate_loyalty();

-- Trigger to audit book changes
CREATE TRIGGER trg_audit_book_changes
AFTER UPDATE ON books
FOR EACH ROW
EXECUTE FUNCTION trg_func_audit_books();

-- Feature: Dead Stock Discounter (Dynamic Pricing)
-- Logic: If a book hasn't sold in 90 days, cut price by 10%
CREATE OR REPLACE PROCEDURE proc_discount_dead_stock()
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT := 0;
BEGIN
    -- Update books that haven't appeared in sales_details for 90 days
    -- AND haven't been updated recently (to prevent double discounting)
    UPDATE books b
    SET price = price * 0.90, -- 10% Discount
        updated_at = CURRENT_TIMESTAMP
    WHERE NOT EXISTS (
        SELECT 1 FROM sales_details sd 
        JOIN sales_header sh ON sd.sale_id = sh.sale_id
        WHERE sd.isbn = b.isbn 
        AND sh.sale_date > CURRENT_DATE - INTERVAL '90 days'
    )
    AND b.updated_at < CURRENT_DATE - INTERVAL '30 days'; -- Don't discount if we just touched it
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Applied Dead Stock discount to % books.', v_count;
END;
$$;

-- ============================================================================
-- MATERIALIZED VIEWS FOR REPORTING
-- ============================================================================

-- Dashboard view for genre trends
CREATE MATERIALIZED VIEW mv_dashboard_genre_trends AS
SELECT
    g.genre_name,
    COUNT(DISTINCT sd.isbn) AS unique_books_sold,
    SUM(sd.quantity) AS total_books_sold,
    SUM(sd.quantity * sd.unit_price) AS total_revenue,
    ROUND(AVG(sd.unit_price), 2) AS avg_selling_price
FROM sales_header sh
JOIN sales_details sd ON sh.sale_id = sd.sale_id
JOIN books b ON sd.isbn = b.isbn
JOIN genres g ON b.genre_id = g.genre_id
WHERE sh.sale_date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY g.genre_name
ORDER BY total_revenue DESC;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX idx_mv_genre_name ON mv_dashboard_genre_trends(genre_name);

-- Dashboard view for top authors
CREATE MATERIALIZED VIEW mv_dashboard_top_authors AS
SELECT
    a.author_id,
    a.full_name,
    COUNT(DISTINCT b.isbn) AS unique_titles_sold,
    SUM(sd.quantity) AS total_books_sold,
    SUM(sd.quantity * sd.unit_price) AS total_generated_revenue,
    ROUND(AVG(sd.unit_price), 2) AS avg_book_price
FROM authors a
JOIN book_authors ba ON a.author_id = ba.author_id
JOIN books b ON ba.isbn = b.isbn
JOIN sales_details sd ON b.isbn = sd.isbn
GROUP BY a.author_id, a.full_name
ORDER BY total_generated_revenue DESC
LIMIT 10;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX idx_mv_author_id ON mv_dashboard_top_authors(author_id);

-- ============================================================================
-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert sample genres
-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- View all tables
DO $$
BEGIN
    RAISE NOTICE '=== Database Setup Complete ===';
    RAISE NOTICE 'Tables created: customers, suppliers, genres, authors, books, book_authors, book_assets';
    RAISE NOTICE 'Sales tables: sales_header, sales_details, returns';
    RAISE NOTICE 'Purchase tables: purchase_orders, purchase_order_details';
    RAISE NOTICE 'Support tables: audit_logs';
    RAISE NOTICE 'Views: mv_dashboard_genre_trends, mv_dashboard_top_authors';
    RAISE NOTICE '';
    RAISE NOTICE 'Sample data inserted for testing';
    RAISE NOTICE 'System ready for use!';
END $$;
