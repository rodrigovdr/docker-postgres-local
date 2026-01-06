-- 1. SAMPLE TABLE CREATION
CREATE TABLE IF NOT EXISTS public.customers (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    city TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. SEED DATA
INSERT INTO public.customers (full_name, email, city) VALUES
('John Doe', 'john@example.com', 'New York'),
('Jane Smith', 'jane@example.com', 'London'),
('Alice Brown', 'alice@example.com', 'Sydney')
ON CONFLICT (email) DO NOTHING;

-- 3. APPLY SECURITY AUTOMATION
CALL public.setup_table_api('customers');

-- 4. SWAGGER DOCUMENTATION
COMMENT ON TABLE public.customers IS 'Sample customers table for testing the Docker Postgres ecosystem.';