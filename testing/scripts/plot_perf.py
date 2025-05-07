#!/usr/bin/env python3
"""
Performance data plotting script for New Relic Infrastructure testing
Converts CSV performance data to charts for analysis.
"""

import sys
import os
import csv
from datetime import datetime
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

def parse_args():
    """Parse command line arguments"""
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <csv_file> [output_dir]")
        sys.exit(1)
        
    csv_file = sys.argv[1]
    
    if len(sys.argv) > 2:
        output_dir = sys.argv[2]
    else:
        output_dir = os.path.dirname(csv_file)
        
    return csv_file, output_dir

def load_csv_data(csv_file):
    """Load performance data from CSV file"""
    try:
        df = pd.read_csv(csv_file)
        print(f"Loaded {len(df)} rows from {csv_file}")
        return df
    except Exception as e:
        print(f"Error loading CSV file: {e}")
        sys.exit(1)

def generate_summary(df):
    """Generate summary statistics for performance data"""
    summary = {}
    
    # Group by database type and operation
    grouped = df.groupby(['db_type', 'operation'])
    
    for (db_type, operation), group in grouped:
        key = f"{db_type}_{operation}"
        summary[key] = {
            'count': len(group),
            'avg_duration': group['duration_ms'].mean(),
            'min_duration': group['duration_ms'].min(),
            'max_duration': group['duration_ms'].max(),
            'std_duration': group['duration_ms'].std()
        }
    
    return summary

def plot_durations(df, output_dir):
    """Generate duration bar charts by operation type"""
    # Filter only duration data
    duration_df = df[df['duration_ms'] > 0]
    
    # Group by database type and operation
    grouped = duration_df.groupby(['db_type', 'operation'])
    
    # Create plot
    plt.figure(figsize=(12, 8))
    
    # Prepare data for bar chart
    db_types = duration_df['db_type'].unique()
    operations = duration_df['operation'].unique()
    
    # Create a dictionary to store average durations
    avg_durations = {}
    
    for (db_type, operation), group in grouped:
        if operation not in avg_durations:
            avg_durations[operation] = {}
        avg_durations[operation][db_type] = group['duration_ms'].mean()
    
    # Generate bar chart data
    bar_width = 0.35
    index = np.arange(len(operations))
    
    # Create bars for each database type
    for i, db_type in enumerate(db_types):
        values = [avg_durations.get(op, {}).get(db_type, 0) for op in operations]
        plt.bar(index + i*bar_width, values, bar_width, label=db_type)
    
    # Add labels and title
    plt.xlabel('Operation')
    plt.ylabel('Average Duration (ms)')
    plt.title('Average Query Duration by Database Type and Operation')
    plt.xticks(index + bar_width/2, operations)
    plt.legend()
    
    # Save chart
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'durations_by_operation.png'))
    print(f"Saved duration chart to {output_dir}/durations_by_operation.png")

def plot_time_series(df, output_dir):
    """Generate time series chart of durations"""
    # Filter only duration data
    duration_df = df[df['duration_ms'] > 0].copy()
    
    # Convert timestamp to datetime
    duration_df['timestamp'] = pd.to_datetime(duration_df['timestamp'])
    
    # Sort by timestamp
    duration_df = duration_df.sort_values('timestamp')
    
    # Create plot
    plt.figure(figsize=(12, 8))
    
    # Group by database type
    for db_type in duration_df['db_type'].unique():
        db_data = duration_df[duration_df['db_type'] == db_type]
        plt.plot(db_data['timestamp'], db_data['duration_ms'], label=db_type, marker='o')
    
    # Add labels and title
    plt.xlabel('Time')
    plt.ylabel('Duration (ms)')
    plt.title('Query Duration Over Time by Database Type')
    plt.legend()
    plt.grid(True)
    
    # Rotate x-axis labels for better readability
    plt.xticks(rotation=45)
    
    # Save chart
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'duration_time_series.png'))
    print(f"Saved time series chart to {output_dir}/duration_time_series.png")

def generate_report(summary, output_dir):
    """Generate a summary report as HTML"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>New Relic Performance Test Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            h1 { color: #1d3557; }
            h2 { color: #457b9d; }
            table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f1faee; }
            tr:nth-child(even) { background-color: #f2f2f2; }
            .summary { background-color: #e0f7fa; padding: 10px; border-radius: 5px; }
            .chart { margin: 20px 0; }
            .warning { color: #ff6347; }
        </style>
    </head>
    <body>
        <h1>New Relic Performance Test Report</h1>
        <p>Generated on: """ + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + """</p>
        
        <div class="summary">
            <h2>Summary</h2>
            <p>This report presents the results of performance tests run against MySQL and PostgreSQL databases with New Relic monitoring enabled.</p>
        </div>
        
        <h2>Performance Metrics by Database and Operation</h2>
        <table>
            <tr>
                <th>Database Type</th>
                <th>Operation</th>
                <th>Samples</th>
                <th>Avg Duration (ms)</th>
                <th>Min Duration (ms)</th>
                <th>Max Duration (ms)</th>
                <th>Std Dev (ms)</th>
                <th>Status</th>
            </tr>
    """
    
    # Add rows for each database type and operation
    for key, data in summary.items():
        db_type, operation = key.split('_', 1)
        avg_duration = data['avg_duration']
        
        # Determine status based on average duration
        if avg_duration > 2000:
            status = '<span class="warning">SLOW</span>'
        else:
            status = 'OK'
        
        html_content += f"""
            <tr>
                <td>{db_type}</td>
                <td>{operation}</td>
                <td>{data['count']}</td>
                <td>{avg_duration:.2f}</td>
                <td>{data['min_duration']:.2f}</td>
                <td>{data['max_duration']:.2f}</td>
                <td>{data['std_duration']:.2f}</td>
                <td>{status}</td>
            </tr>
        """
    
    # Add charts to report
    html_content += """
        </table>
        
        <h2>Performance Charts</h2>
        
        <div class="chart">
            <h3>Average Query Duration by Database Type and Operation</h3>
            <img src="durations_by_operation.png" alt="Duration by Operation Chart" width="800">
        </div>
        
        <div class="chart">
            <h3>Query Duration Over Time</h3>
            <img src="duration_time_series.png" alt="Duration Time Series Chart" width="800">
        </div>
        
        <footer>
            <p>© New Relic Infrastructure Testing Framework</p>
        </footer>
    </body>
    </html>
    """
    
    # Write report to file
    report_path = os.path.join(output_dir, 'performance_report.html')
    with open(report_path, 'w') as f:
        f.write(html_content)
    
    print(f"Generated performance report: {report_path}")

def main():
    """Main function"""
    # Parse command line arguments
    csv_file, output_dir = parse_args()
    
    # Load CSV data
    df = load_csv_data(csv_file)
    
    # Generate summary
    summary = generate_summary(df)
    
    # Generate charts
    plot_durations(df, output_dir)
    plot_time_series(df, output_dir)
    
    # Generate report
    generate_report(summary, output_dir)
    
    print("Performance analysis completed successfully!")

if __name__ == "__main__":
    main()
