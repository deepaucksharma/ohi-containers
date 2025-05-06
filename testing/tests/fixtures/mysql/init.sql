-- MySQL initialization script for testing New Relic OHI

-- Create a user for New Relic monitoring with proper permissions
CREATE USER IF NOT EXISTS 'newrelic'@'%' IDENTIFIED BY 'test_password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'newrelic'@'%';
FLUSH PRIVILEGES;

-- Create a test database
CREATE DATABASE IF NOT EXISTS `test`;
USE `test`;

-- Create a test table to measure performance
CREATE TABLE IF NOT EXISTS `performance_test` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `string_value` VARCHAR(255) NULL,
  `integer_value` INT NULL,
  `float_value` FLOAT NULL,
  `date_value` DATETIME NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_created_at` (`created_at`)
);

-- Insert some sample data
INSERT INTO `performance_test` (`string_value`, `integer_value`, `float_value`, `date_value`)
SELECT 
  CONCAT('Value-', FLOOR(RAND() * 1000)),
  FLOOR(RAND() * 10000),
  RAND() * 100,
  DATE_ADD('2023-01-01', INTERVAL FLOOR(RAND() * 365) DAY)
FROM 
  (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t1,
  (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t2,
  (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t3
LIMIT 1000;

-- Create a second table to join with
CREATE TABLE IF NOT EXISTS `performance_metadata` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `test_id` INT NOT NULL,
  `metadata_key` VARCHAR(50) NOT NULL,
  `metadata_value` VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_test_id` (`test_id`),
  INDEX `idx_key` (`metadata_key`)
);

-- Insert some metadata
INSERT INTO `performance_metadata` (`test_id`, `metadata_key`, `metadata_value`)
SELECT 
  FLOOR(RAND() * 1000),
  CASE FLOOR(RAND() * 5)
    WHEN 0 THEN 'category'
    WHEN 1 THEN 'region'
    WHEN 2 THEN 'status'
    WHEN 3 THEN 'priority'
    ELSE 'tag'
  END,
  CASE FLOOR(RAND() * 5)
    WHEN 0 THEN 'high'
    WHEN 1 THEN 'medium'
    WHEN 2 THEN 'low'
    WHEN 3 THEN 'pending'
    ELSE 'completed'
  END
FROM 
  (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t1,
  (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t2,
  (SELECT 0 UNION SELECT 1 UNION SELECT 2) t3
LIMIT 2000;

-- Create a view that will trigger a complex query
CREATE OR REPLACE VIEW `performance_summary` AS
SELECT 
  pt.id,
  pt.string_value,
  pt.integer_value,
  pt.float_value,
  pt.date_value,
  COUNT(pm.id) AS metadata_count,
  GROUP_CONCAT(DISTINCT pm.metadata_key) AS metadata_keys,
  GROUP_CONCAT(DISTINCT pm.metadata_value) AS metadata_values
FROM 
  `performance_test` pt
LEFT JOIN 
  `performance_metadata` pm ON pt.id = pm.test_id
GROUP BY 
  pt.id, pt.string_value, pt.integer_value, pt.float_value, pt.date_value;

-- Create a stored procedure to generate load
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `generate_test_load`()
BEGIN
  DECLARE i INT DEFAULT 0;
  
  -- Select data with various conditions to create different query patterns
  SELECT COUNT(*) FROM performance_test;
  SELECT AVG(integer_value), MAX(float_value) FROM performance_test;
  
  -- Run a slow query
  SELECT pt.*, pm.metadata_key, pm.metadata_value
  FROM performance_test pt
  JOIN performance_metadata pm ON pt.id = pm.test_id
  WHERE pt.string_value LIKE 'Value-%'
  ORDER BY pt.created_at
  LIMIT 100;
  
  -- Another potentially slow query
  SELECT DATE(pt.created_at) as day, 
         COUNT(*) as count, 
         AVG(pt.integer_value) as avg_int,
         SUM(pt.float_value) as sum_float
  FROM performance_test pt
  GROUP BY day
  ORDER BY day;
  
  -- Query using a view (usually slower)
  SELECT * FROM performance_summary LIMIT 50;
END//
DELIMITER ;
