#!/bin/bash
# Performance test script for New Relic Infrastructure Agent

set -e

# Configuration
NR_CONTAINER="test-newrelic-infra"
DURATION=300  # 5 minutes test duration
INTERVAL=10   # 10 seconds sampling interval
OUTPUT_DIR="/output/performance"
RESOURCE_LOG="${OUTPUT_DIR}/resource_usage.csv"
METRICS_LOG="${OUTPUT_DIR}/metrics_count.csv"

echo "Starting performance tests"
echo "-------------------------"
echo

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Initialize CSV headers
echo "timestamp,cpu_percent,memory_usage_mb,memory_percent,disk_read_mb,disk_write_mb,network_in_mb,network_out_mb" > "$RESOURCE_LOG"
echo "timestamp,mysql_metrics,postgres_metrics,mysql_query_metrics,postgres_query_metrics,total_metrics" > "$METRICS_LOG"

echo "Running performance test for $DURATION seconds with $INTERVAL second intervals"
echo "Recording data to $RESOURCE_LOG and $METRICS_LOG"

# Function to get resource usage
get_resource_usage() {
    # Get CPU usage percentage
    CPU_PERCENT=$(docker stats "$NR_CONTAINER" --no-stream --format "{{.CPUPerc}}" | tr -d '%')
    
    # Get memory usage
    MEMORY_STATS=$(docker stats "$NR_CONTAINER" --no-stream --format "{{.MemUsage}}")
    MEMORY_USAGE=$(echo "$MEMORY_STATS" | awk '{print $1}')
    MEMORY_TOTAL=$(echo "$MEMORY_STATS" | awk '{print $3}')
    MEMORY_USAGE_MB=$(echo "$MEMORY_USAGE" | sed 's/MiB//' | sed 's/GiB/*1024/' | bc)
    MEMORY_PERCENT=$(docker stats "$NR_CONTAINER" --no-stream --format "{{.MemPerc}}" | tr -d '%')
    
    # Get disk I/O
    IO_STATS=$(docker stats "$NR_CONTAINER" --no-stream --format "{{.BlockIO}}")
    DISK_READ=$(echo "$IO_STATS" | awk '{print $1}')
    DISK_WRITE=$(echo "$IO_STATS" | awk '{print $3}')
    DISK_READ_MB=$(echo "$DISK_READ" | sed 's/MB//' | sed 's/GB/*1024/' | sed 's/kB/*0.001/' | sed 's/B/*0.000001/' | bc 2>/dev/null || echo "0")
    DISK_WRITE_MB=$(echo "$DISK_WRITE" | sed 's/MB//' | sed 's/GB/*1024/' | sed 's/kB/*0.001/' | sed 's/B/*0.000001/' | bc 2>/dev/null || echo "0")
    
    # Get network I/O
    NET_STATS=$(docker stats "$NR_CONTAINER" --no-stream --format "{{.NetIO}}")
    NET_IN=$(echo "$NET_STATS" | awk '{print $1}')
    NET_OUT=$(echo "$NET_STATS" | awk '{print $3}')
    NET_IN_MB=$(echo "$NET_IN" | sed 's/MB//' | sed 's/GB/*1024/' | sed 's/kB/*0.001/' | sed 's/B/*0.000001/' | bc 2>/dev/null || echo "0")
    NET_OUT_MB=$(echo "$NET_OUT" | sed 's/MB//' | sed 's/GB/*1024/' | sed 's/kB/*0.001/' | sed 's/B/*0.000001/' | bc 2>/dev/null || echo "0")
    
    # Output to CSV
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$CPU_PERCENT,$MEMORY_USAGE_MB,$MEMORY_PERCENT,$DISK_READ_MB,$DISK_WRITE_MB,$NET_IN_MB,$NET_OUT_MB" >> "$RESOURCE_LOG"
}

# Function to get metrics count
get_metrics_count() {
    # Get number of MySQL metrics
    MYSQL_METRICS=$(docker exec "$NR_CONTAINER" grep -c "MySQLSample" /var/log/newrelic-infra/newrelic-infra.log 2>/dev/null || echo "0")
    
    # Get number of PostgreSQL metrics
    POSTGRES_METRICS=$(docker exec "$NR_CONTAINER" grep -c "PostgresSample" /var/log/newrelic-infra/newrelic-infra.log 2>/dev/null || echo "0")
    
    # Get number of MySQL query metrics
    MYSQL_QUERY_METRICS=$(docker exec "$NR_CONTAINER" grep -c "MySQLQuerySample" /var/log/newrelic-infra/newrelic-infra.log 2>/dev/null || echo "0")
    
    # Get number of PostgreSQL query metrics
    POSTGRES_QUERY_METRICS=$(docker exec "$NR_CONTAINER" grep -c "PostgresQuerySample" /var/log/newrelic-infra/newrelic-infra.log 2>/dev/null || echo "0")
    
    # Calculate total
    TOTAL_METRICS=$((MYSQL_METRICS + POSTGRES_METRICS + MYSQL_QUERY_METRICS + POSTGRES_QUERY_METRICS))
    
    # Output to CSV
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$MYSQL_METRICS,$POSTGRES_METRICS,$MYSQL_QUERY_METRICS,$POSTGRES_QUERY_METRICS,$TOTAL_METRICS" >> "$METRICS_LOG"
}

# Loop for the duration of the test
END_TIME=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $END_TIME ]; do
    get_resource_usage
    get_metrics_count
    
    REMAINING=$((END_TIME - $(date +%s)))
    echo -ne "Test progress: $((DURATION - REMAINING))/$DURATION seconds complete\r"
    
    sleep $INTERVAL
done

echo -e "\nTest completed! Analyzing results..."

# Analyze CPU usage
CPU_AVG=$(awk -F, 'NR>1 {sum+=$2; count++} END {print sum/count}' "$RESOURCE_LOG")
CPU_MAX=$(awk -F, 'NR>1 {if ($2>max) max=$2} END {print max}' "$RESOURCE_LOG")
echo "CPU Usage: Avg ${CPU_AVG}%, Max ${CPU_MAX}%"

# Analyze memory usage
MEM_AVG=$(awk -F, 'NR>1 {sum+=$3; count++} END {print sum/count}' "$RESOURCE_LOG")
MEM_MAX=$(awk -F, 'NR>1 {if ($3>max) max=$3} END {print max}' "$RESOURCE_LOG")
echo "Memory Usage: Avg ${MEM_AVG}MB, Max ${MEM_MAX}MB"

# Analyze network usage
NET_IN_AVG=$(awk -F, 'NR>1 {sum+=$7; count++} END {print sum/count}' "$RESOURCE_LOG")
NET_OUT_AVG=$(awk -F, 'NR>1 {sum+=$8; count++} END {print sum/count}' "$RESOURCE_LOG")
echo "Network Usage: Avg In ${NET_IN_AVG}MB, Avg Out ${NET_OUT_AVG}MB"

# Analyze metrics
TOTAL_METRICS_FINAL=$(tail -1 "$METRICS_LOG" | cut -d, -f6)
METRICS_PER_SECOND=$(echo "scale=2; $TOTAL_METRICS_FINAL / $DURATION" | bc)
echo "Metrics Generated: $TOTAL_METRICS_FINAL total (${METRICS_PER_SECOND}/second)"

# Generate performance summary
echo
echo "Performance Summary:"
echo "------------------"
if (( $(echo "$CPU_AVG < 10" | bc -l) )); then
    echo "✅ CPU usage is within acceptable limits (< 10%)"
else
    echo "⚠️ CPU usage is high (${CPU_AVG}%). Consider optimization."
fi

if (( $(echo "$MEM_AVG < 500" | bc -l) )); then
    echo "✅ Memory usage is within acceptable limits (< 500MB)"
else
    echo "⚠️ Memory usage is high (${MEM_AVG}MB). Consider optimization."
fi

if (( $(echo "$METRICS_PER_SECOND > 0.5" | bc -l) )); then
    echo "✅ Metric generation rate is acceptable (> 0.5/second)"
else
    echo "⚠️ Low metric generation rate (${METRICS_PER_SECOND}/second). Check configuration."
fi

echo
echo "Performance test complete. Full results available in:"
echo "- $RESOURCE_LOG"
echo "- $METRICS_LOG"

# Generate simple visualization
echo "
# Performance Test Results

## Resource Usage
- **CPU**: Avg ${CPU_AVG}%, Max ${CPU_MAX}%
- **Memory**: Avg ${MEM_AVG}MB, Max ${MEM_MAX}MB
- **Network**: Avg In ${NET_IN_AVG}MB, Avg Out ${NET_OUT_AVG}MB

## Metrics Generation
- **Total Metrics**: $TOTAL_METRICS_FINAL
- **Rate**: ${METRICS_PER_SECOND} metrics/second

## Detailed analysis available in CSV files
" > "${OUTPUT_DIR}/summary.md"

exit 0