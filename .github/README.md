# GitHub Actions for Docker Validation Framework

This directory contains GitHub Actions workflow configurations for automatically testing the Docker validation framework.

## Available Workflows

### 1. docker-validation.yml

**Basic workflow** for testing the Docker validation framework on both Linux and Windows.

- Runs on push to main branch or pull requests
- Tests on both Linux and Windows runners
- Runs unit tests and image validation tests

### 2. complete-validation.yml

**Comprehensive workflow** that runs all test categories with detailed reporting.

- Runs on push, pull requests, and weekly schedule
- Separate jobs for each test category
- Uploads test logs as artifacts
- Generates a test summary report

### 3. debug-workflow.yml

**Interactive workflow** for debugging tests in the GitHub Actions environment.

- Manually triggered with customizable options
- Select which test category to run
- Choose test platform (Linux, Windows, or both)
- Enable debug mode for additional diagnostic information

## Running the Workflows

### Automated Execution

The workflows will run automatically on:
- Push to main/master branch
- Pull requests to main/master branch
- Weekly schedule (complete-validation only)

### Manual Execution

To manually trigger a workflow:

1. Go to the "Actions" tab in your GitHub repository
2. Select the workflow you want to run
3. Click "Run workflow"
4. For the debug workflow, select the options you want to use
5. Click "Run workflow" again

## Test Results

Test results can be found in several places:

1. **Workflow logs**: Available in the GitHub Actions UI
2. **Artifacts**: Test logs and reports are uploaded as artifacts
3. **Test summary**: The complete-validation workflow generates a summary report

## Customizing Workflows

To customize the workflows for your specific needs:

1. Edit the relevant YAML file in the `.github/workflows` directory
2. Adjust job configurations, test commands, or other settings
3. Commit and push your changes

## Troubleshooting

If tests fail in GitHub Actions but pass locally:

1. Use the debug-workflow.yml with debug mode enabled
2. Check file permissions (scripts must be executable)
3. Verify that paths are correct for both Linux and Windows
4. Ensure Docker socket is properly mounted
5. Check for platform-specific issues in your tests

## Best Practices

1. Keep workflows focused on specific testing tasks
2. Use matrix builds for testing multiple configurations
3. Upload test artifacts for debugging
4. Set reasonable timeout values for tests
5. Use GitHub Secrets for sensitive information
