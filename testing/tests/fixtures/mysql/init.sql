-- Initialize MySQL database for New Relic Infrastructure testing

-- Create test database and tables
USE test;

-- Create a user for New Relic with appropriate permissions
CREATE USER IF NOT EXISTS 'newrelic'@'%' IDENTIFIED BY 'test_password';
GRANT REPLICATION CLIENT ON *.* TO 'newrelic'@'%';
GRANT SELECT ON performance_schema.* TO 'newrelic'@'%';
GRANT SELECT ON test.* TO 'newrelic'@'%';

-- Create a test table
CREATE TABLE IF NOT EXISTS sample_table (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  value INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some test data
INSERT INTO sample_table (name, value) VALUES
  ('test1', 100),
  ('test2', 200),
  ('test3', 300),
  ('test4', 400),
  ('test5', 500);

-- Set some variables to test monitoring
SET GLOBAL max_connections = 200;