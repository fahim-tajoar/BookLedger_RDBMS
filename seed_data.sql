-- ============================================================================
-- BOOKLEDGER SEED DATA
-- ============================================================================

-- Genres
INSERT INTO genres (genre_name, description) VALUES
('Fiction', 'Novels, short stories, and literary fiction'),
('Science Fiction', 'Futuristic and speculative narratives'),
('Fantasy', 'Magical worlds and mythical adventures'),
('Mystery', 'Crime, detective, and thriller stories'),
('Non-Fiction', 'Factual works including biographies and essays'),
('Romance', 'Love stories and romantic adventures'),
('Horror', 'Dark, suspenseful, and frightening tales'),
('History', 'Historical accounts and period analyses');

-- Suppliers
INSERT INTO suppliers (company_name, contact_email, contact_phone, credit_terms) VALUES
('Penguin Distribution', 'orders@penguin-dist.com', '+1-800-555-0101', 'NET 30'),
('HarperCollins Supply', 'supply@harpercollins.com', '+1-800-555-0102', 'NET 45'),
('Macmillan Wholesale', 'wholesale@macmillan.com', '+1-800-555-0103', 'NET 30'),
('Simon & Schuster Direct', 'direct@simonschuster.com', '+1-800-555-0104', 'NET 60');

-- Authors
INSERT INTO authors (full_name, biography, country) VALUES
('Elena Morales', 'Award-winning novelist exploring themes of identity and belonging.', 'United States'),
('James Whitfield', 'Bestselling science fiction author and former astrophysicist.', 'United Kingdom'),
('Aisha Khan', 'Literary fiction writer known for lyrical prose and emotional depth.', 'Pakistan'),
('Marcus Chen', 'Master of mystery and suspense with 20+ novels published.', 'Canada'),
('Sofia Andersson', 'Fantasy author who crafts richly detailed magical worlds.', 'Sweden'),
('David Park', 'Non-fiction writer specializing in technology and society.', 'South Korea'),
('Isabella Rossi', 'Romance novelist with a devoted global readership.', 'Italy'),
('Takeshi Yamamoto', 'Horror writer blending Japanese folklore with modern terror.', 'Japan'),
('Olivia Hart', 'Debut literary fiction author and creative writing professor.', 'Australia'),
('Rafael Santos', 'Historical fiction writer bringing forgotten eras to vivid life.', 'Brazil');

-- Books
INSERT INTO books (isbn, title, genre_id, price, stock_qty, supplier_id, publication_date) VALUES
('978-0-13-110362-7', 'The Glass Garden', 1, 24.99, 35, 1, '2025-03-15'),
('978-0-13-110363-4', 'Starfall Chronicles', 2, 29.99, 20, 1, '2025-06-01'),
('978-0-13-110364-1', 'The Ember Throne', 3, 27.99, 45, 2, '2024-11-20'),
('978-0-13-110365-8', 'Silent Witness', 4, 22.99, 15, 2, '2025-01-10'),
('978-0-13-110366-5', 'Digital Minds', 5, 34.99, 8, 3, '2025-08-05'),
('978-0-13-110367-2', 'Midnight in Verona', 6, 19.99, 50, 3, '2024-09-14'),
('978-0-13-110368-9', 'The Hollow Man', 7, 21.99, 3, 4, '2025-04-22'),
('978-0-13-110369-6', 'Echoes of Empire', 8, 32.99, 12, 4, '2024-07-30'),
('978-0-13-110370-2', 'Neon Horizon', 2, 26.99, 28, 1, '2025-09-18'),
('978-0-13-110371-9', 'The Last Cartographer', 1, 23.99, 2, 2, '2025-02-28'),
('978-0-13-110372-6', 'Quantum Echoes', 2, 31.99, 18, 3, '2025-07-12'),
('978-0-13-110373-3', 'Ruins of Arathia', 3, 25.99, 40, 1, '2024-12-01'),
('978-0-13-110374-0', 'The Cipher Key', 4, 24.99, 4, 2, '2025-05-20'),
('978-0-13-110375-7', 'Love in Transit', 6, 18.99, 55, 4, '2025-01-25'),
('978-0-13-110376-4', 'The Algorithm of Us', 5, 29.99, 22, 3, '2025-10-01'),
('978-0-13-110377-1', 'Whispers in the Dark', 7, 20.99, 1, 4, '2025-03-08'),
('978-0-13-110378-8', 'The Silk Road Journals', 8, 35.99, 10, 1, '2024-08-15'),
('978-0-13-110379-5', 'Fractured Light', 1, 22.99, 30, 2, '2025-06-22'),
('978-0-13-110380-1', 'The Crown of Shadows', 3, 28.99, 38, 3, '2025-04-10'),
('978-0-13-110381-8', 'Dead Code', 4, 23.99, 16, 4, '2025-08-30');

-- Book-Author mapping
INSERT INTO book_authors (isbn, author_id, author_order) VALUES
('978-0-13-110362-7', 1, 1),  -- The Glass Garden → Elena Morales
('978-0-13-110363-4', 2, 1),  -- Starfall Chronicles → James Whitfield
('978-0-13-110364-1', 5, 1),  -- The Ember Throne → Sofia Andersson
('978-0-13-110365-8', 4, 1),  -- Silent Witness → Marcus Chen
('978-0-13-110366-5', 6, 1),  -- Digital Minds → David Park
('978-0-13-110367-2', 7, 1),  -- Midnight in Verona → Isabella Rossi
('978-0-13-110368-9', 8, 1),  -- The Hollow Man → Takeshi Yamamoto
('978-0-13-110369-6', 10, 1), -- Echoes of Empire → Rafael Santos
('978-0-13-110370-2', 2, 1),  -- Neon Horizon → James Whitfield
('978-0-13-110371-9', 9, 1),  -- The Last Cartographer → Olivia Hart
('978-0-13-110372-6', 2, 1),  -- Quantum Echoes → James Whitfield
('978-0-13-110373-3', 5, 1),  -- Ruins of Arathia → Sofia Andersson
('978-0-13-110374-0', 4, 1),  -- The Cipher Key → Marcus Chen
('978-0-13-110375-7', 7, 1),  -- Love in Transit → Isabella Rossi
('978-0-13-110376-4', 6, 1),  -- The Algorithm of Us → David Park
('978-0-13-110377-1', 8, 1),  -- Whispers in the Dark → Takeshi Yamamoto
('978-0-13-110378-8', 10, 1), -- The Silk Road Journals → Rafael Santos
('978-0-13-110379-5', 3, 1),  -- Fractured Light → Aisha Khan
('978-0-13-110380-1', 5, 1),  -- The Crown of Shadows → Sofia Andersson
('978-0-13-110381-8', 4, 1);  -- Dead Code → Marcus Chen

-- Book assets (preview text)
INSERT INTO book_assets (isbn, preview_text) VALUES
('978-0-13-110362-7', 'In a house made of memory and glass, Clara tends a garden that grows things no one else can see. A luminous debut novel about loss, wonder, and the invisible threads that bind us.'),
('978-0-13-110363-4', 'When the stars begin to fall—literally—humanity''s last colony ship must navigate a dying galaxy. An epic space opera that redefines the genre.'),
('978-0-13-110364-1', 'The ancient throne of Ember has chosen its heir, but she wants nothing to do with destiny. A sweeping fantasy of rebellion, magic, and the cost of power.'),
('978-0-13-110365-8', 'Detective Lena Voss uncovers a web of silence surrounding a decades-old disappearance. Every witness remembers nothing—or pretends to.'),
('978-0-13-110366-5', 'A provocative exploration of artificial intelligence, consciousness, and what it means to be human in an increasingly digital world.'),
('978-0-13-110367-2', 'Two strangers meet during a midnight rainstorm in Verona and discover that love, like the city itself, is built on layers of beautiful ruins.'),
('978-0-13-110368-9', 'Something lives inside the walls of the old Matsuda estate. Something that whispers. Something that waits. A chilling tale of ancestral horror.'),
('978-0-13-110369-6', 'From the fall of Constantinople to the rise of the Mughal Empire, a merchant''s journal reveals the hidden forces that shaped civilizations.'),
('978-0-13-110370-2', 'In a neon-drenched megacity of 2187, a rogue AI and a human detective forge an unlikely alliance to prevent a corporate apocalypse.'),
('978-0-13-110371-9', 'The world''s last mapmaker discovers that the blank spaces on her charts aren''t empty—they''re doors. A genre-bending literary adventure.'),
('978-0-13-110380-1', 'Three kingdoms vie for the Crown of Shadows—an artifact that grants dominion over darkness itself. But shadows have a will of their own.');

-- Customers
INSERT INTO customers (name, email, membership_pts, trust_score) VALUES
('Alice Johnson', 'alice@example.com', 150, 92),
('Bob Martinez', 'bob@example.com', 45, 78),
('Carol Williams', 'carol@example.com', 300, 95),
('Derek Thompson', 'derek@example.com', 10, 55),
('Eva Chen', 'eva@example.com', 80, 85),
('Frank Miller', 'frank@example.com', 5, 25);

-- Sales header and details (to populate materialized views)
INSERT INTO sales_header (customer_id, total_amount, payment_method, status) VALUES
(1, 54.98, 'CARD', 'COMPLETED'),
(2, 29.99, 'CASH', 'COMPLETED'),
(3, 86.97, 'ONLINE', 'COMPLETED'),
(1, 27.99, 'CARD', 'COMPLETED'),
(4, 22.99, 'CASH', 'COMPLETED'),
(5, 49.98, 'ONLINE', 'COMPLETED'),
(3, 32.99, 'CARD', 'COMPLETED'),
(2, 19.99, 'CASH', 'COMPLETED'),
(5, 31.99, 'ONLINE', 'COMPLETED'),
(1, 35.99, 'CARD', 'COMPLETED');

INSERT INTO sales_details (sale_id, isbn, quantity, unit_price) VALUES
(1, '978-0-13-110362-7', 1, 24.99),
(1, '978-0-13-110363-4', 1, 29.99),
(2, '978-0-13-110363-4', 1, 29.99),
(3, '978-0-13-110364-1', 1, 27.99),
(3, '978-0-13-110367-2', 2, 19.99),
(3, '978-0-13-110366-5', 1, 34.99),  -- added to match total
(4, '978-0-13-110364-1', 1, 27.99),
(5, '978-0-13-110365-8', 1, 22.99),
(6, '978-0-13-110362-7', 2, 24.99),
(7, '978-0-13-110369-6', 1, 32.99),
(8, '978-0-13-110367-2', 1, 19.99),
(9, '978-0-13-110372-6', 1, 31.99),
(10, '978-0-13-110378-8', 1, 35.99);

-- A return (to test trust penalty trigger)
INSERT INTO returns (sale_id, isbn, quantity, condition, reason, refund_amount) VALUES
(5, '978-0-13-110365-8', 1, 'DAMAGED', 'Pages were torn on arrival', 22.99);

-- Refresh materialized views so dashboard data is available
REFRESH MATERIALIZED VIEW mv_dashboard_genre_trends;
REFRESH MATERIALIZED VIEW mv_dashboard_top_authors;

-- Default admin user (email: admin@bookledger.com / password: admin123)
INSERT INTO app_users (email, password_hash, role) VALUES
('admin@bookledger.com', 'scrypt:32768:8:1$5n9ZtJEXwSGQuC0y$76c0bdf6ccc40b90ebac263d0a1df115a28b7cb899e325f472f05866194e1f975a8f1f23123f2d48c8a05281138dc40e3ec9ede72efd48a51e0d39ea88c0e136', 'admin');
