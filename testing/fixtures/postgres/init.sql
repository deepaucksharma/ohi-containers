-- PostgreSQL initialization script for testing New Relic OHI

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a user for New Relic monitoring with proper permissions
DO
$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'newrelic') THEN
    CREATE ROLE newrelic WITH LOGIN PASSWORD 'test_password';
  END IF;
END
$$;

-- Grant necessary permissions
GRANT pg_monitor TO newrelic;
GRANT CONNECT ON DATABASE postgres TO newrelic;

-- Create a schema for testing
CREATE SCHEMA IF NOT EXISTS test_monitoring;

-- Create performance test tables
CREATE TABLE IF NOT EXISTS test_monitoring.performance_test (
  id SERIAL PRIMARY KEY,
  string_value VARCHAR(255),
  integer_value INTEGER,
  float_value FLOAT,
  date_value DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_perf_created_at ON test_monitoring.performance_test(created_at);

-- Insert sample data
INSERT INTO test_monitoring.performance_test (string_value, integer_value, float_value, date_value)
SELECT 
  'Value-' || floor(random() * 1000)::text,
  floor(random() * 10000)::int,
  random() * 100,
  '2023-01-01'::date + (floor(random() * 365)::int || ' days')::interval
FROM 
  generate_series(1, 1000)
ON CONFLICT DO NOTHING;

-- Create a second table for joining
CREATE TABLE IF NOT EXISTS test_monitoring.performance_metadata (
  id SERIAL PRIMARY KEY,
  test_id INTEGER NOT NULL,
  metadata_key VARCHAR(50) NOT NULL,
  metadata_value VARCHAR(255),
  CONSTRAINT fk_test_id FOREIGN KEY(test_id) REFERENCES test_monitoring.performance_test(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_meta_test_id ON test_monitoring.performance_metadata(test_id);
CREATE INDEX IF NOT EXISTS idx_meta_key ON test_monitoring.performance_metadata(metadata_key);

-- Insert metadata
INSERT INTO test_monitoring.performance_metadata (test_id, metadata_key, metadata_value)
SELECT 
  floor(random() * 1000)::int,
  CASE floor(random() * 5)::int
    WHEN 0 THEN 'category'
    WHEN 1 THEN 'region'
    WHEN 2 THEN 'status'
    WHEN 3 THEN 'priority'
    ELSE 'tag'
  END,
  CASE floor(random() * 5)::int
    WHEN 0 THEN 'high'
    WHEN 1 THEN 'medium'
    WHEN 2 THEN 'low'
    WHEN 3 THEN 'pending'
    ELSE 'completed'
  END
FROM 
  generate_series(1, 2000)
ON CONFLICT DO NOTHING;

-- Create a view for performance testing
CREATE OR REPLACE VIEW test_monitoring.performance_summary AS
SELECT 
  pt.id,
  pt.string_value,
  pt.integer_value,
  pt.float_value,
  pt.date_value,
  COUNT(pm.id) AS metadata_count,
  string_agg(DISTINCT pm.metadata_key, ',') AS metadata_keys,
  string_agg(DISTINCT pm.metadata_value, ',') AS metadata_values
FROM 
  test_monitoring.performance_test pt
LEFT JOIN 
  test_monitoring.performance_metadata pm ON pt.id = pm.test_id
GROUP BY 
  pt.id, pt.string_value, pt.integer_value, pt.float_value, pt.date_value;

-- Create function to generate test load
CREATE OR REPLACE FUNCTION test_monitoring.generate_test_load()
RETURNS void AS
$$
BEGIN
  -- Simple queries
  PERFORM COUNT(*) FROM test_monitoring.performance_test;
  PERFORM AVG(integer_value), MAX(float_value) FROM test_monitoring.performance_test;
  
  -- Complex join query (potentially slow)
  PERFORM * FROM (
    SELECT pt.*, pm.metadata_key, pm.metadata_value
    FROM test_monitoring.performance_test pt
    JOIN test_monitoring.performance_metadata pm ON pt.id = pm.test_id
    WHERE pt.string_value LIKE 'Value-%'
    ORDER BY pt.created_at
    LIMIT 100
  ) subq;
  
  -- Aggregation query
  PERFORM * FROM (
    SELECT DATE(pt.created_at) as day, 
           COUNT(*) as count, 
           AVG(pt.integer_value) as avg_int,
           SUM(pt.float_value) as sum_float
    FROM test_monitoring.performance_test pt
    GROUP BY day
    ORDER BY day
  ) subq;
  
  -- Query using a view (usually slower)
  PERFORM * FROM test_monitoring.performance_summary LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Create a function that forces a sequential scan
CREATE OR REPLACE FUNCTION test_monitoring.force_sequential_scan()
RETURNS void AS
$$
BEGIN
  -- Temporarily disable indexing
  SET enable_indexscan = OFF;
  SET enable_bitmapscan = OFF;
  
  -- Run a query that would normally use an index
  PERFORM * FROM (
    SELECT *
    FROM test_monitoring.performance_test
    WHERE integer_value BETWEEN 1000 AND 9000
    ORDER BY created_at
    LIMIT 500
  ) subq;
  
  -- Restore normal behavior
  RESET enable_indexscan;
  RESET enable_bitmapscan;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions to the newrelic user
GRANT USAGE ON SCHEMA test_monitoring TO newrelic;
GRANT SELECT ON ALL TABLES IN SCHEMA test_monitoring TO newrelic;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_monitoring TO newrelic;
ALTER DEFAULT PRIVILEGES IN SCHEMA test_monitoring GRANT SELECT ON TABLES TO newrelic;
