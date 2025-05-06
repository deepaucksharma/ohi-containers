-- Initialize PostgreSQL database for New Relic Infrastructure testing

-- Create a user for New Relic with appropriate permissions
CREATE USER newrelic WITH PASSWORD 'test_password';
GRANT pg_read_all_stats TO newrelic;
GRANT SELECT ON pg_stat_database, pg_stat_bgwriter TO newrelic;

-- Enable pg_stat_statements extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a test table
CREATE TABLE IF NOT EXISTS sample_table (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  value INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some test data
INSERT INTO sample_table (name, value) VALUES
  ('test1', 100),
  ('test2', 200),
  ('test3', 300),
  ('test4', 400),
  ('test5', 500);

-- Set some parameters to test monitoring
ALTER SYSTEM SET max_connections = 200;