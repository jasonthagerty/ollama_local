# Context Management for AI Sessions

This document explains how to store and retrieve conversation context for continuous AI assistance sessions with the Ollama project.

## Overview

AI assistants like Claude don't retain memory between sessions by default. However, you can preserve project context, configuration states, and session information using the tools provided in this project.

## What Context Includes

### Project State
- File structure and important configurations
- Docker container status and health
- Ollama models and their states
- GPU configuration and monitoring setup
- Environment variables and settings

### System Information
- Hardware specifications (GPU, memory)
- Docker and system versions
- Network and service configurations
- Recent logs and error states

### Session Information
- Recent commands and their outcomes
- Model performance metrics
- Troubleshooting steps taken
- Configuration changes made

## Context Management Tools

### 1. Export Context
Save the current project state for future reference:

```bash
# Export with automatic timestamp
./manage.sh export-context

# Export with custom name
./manage.sh export-context my-deepseek-session

# Export using dedicated script
./export-context.sh export my-session-name
```

### 2. Import Context
Load previously saved context information:

```bash
# Import specific context
./manage.sh import-context my-deepseek-session.json

# Import from context directory
./export-context.sh import context_20240128_143022.json
```

### 3. List Available Contexts
View all saved context files:

```bash
# Using manage script
./manage.sh list-contexts

# Using dedicated script
./export-context.sh list
```

## Context File Structure

Context files are stored as JSON with the following structure:

```json
{
  "export_info": {
    "timestamp": "2024-01-28T14:30:22-05:00",
    "hostname": "blackbox",
    "user": "jason",
    "context_name": "deepseek-session",
    "project_path": "/home/jason/Projects/ollama-local"
  },
  "project_structure": {
    "files": ["manage.sh", "docker-compose.yml", "Dockerfile", ...],
    "directories": ["./context", "./data", ...]
  },
  "docker_info": {
    "compose_status": "running services info",
    "images": "local docker images",
    "volumes": "docker volumes"
  },
  "ollama_state": {
    "running": true,
    "models": "list of installed models",
    "gpu_status": "GPU health check results"
  },
  "system_info": {
    "gpu_devices": "/dev/dri device list",
    "pci_gpu": "Intel Arc A770 detected",
    "docker_version": "Docker version info"
  }
}
```

## How to Use Context Between Sessions

### Before Ending a Session
1. Export your current context:
   ```bash
   ./manage.sh export-context working-session-$(date +%Y%m%d)
   ```

2. Note any specific issues or configurations:
   ```bash
   echo "Current issues: GPU temperature high, model loading slow" >> context/session-notes.txt
   ```

### Starting a New Session
1. List available contexts:
   ```bash
   ./manage.sh list-contexts
   ```

2. Import the relevant context:
   ```bash
   ./manage.sh import-context working-session-20240128.json
   ```

3. Review the imported information to understand:
   - What services were running
   - Which models were loaded
   - Any ongoing issues
   - Recent configuration changes

### Sharing Context with AI Assistant

When starting a new conversation with an AI assistant:

1. **Load and share the context file:**
   ```bash
   ./export-context.sh show working-session-20240128.json
   ```

2. **Provide key information in your first message:**
   ```
   I'm continuing work on an Ollama setup with Intel Arc A770 GPU. 
   Here's my current context: [paste context information]
   
   Key points from last session:
   - Running DeepSeek-Coder-V2-Lite successfully
   - GPU monitoring tools installed and working
   - Some performance optimization needed
   
   Current issue I need help with: [describe current problem]
   ```

## Best Practices

### Context Export Strategy
- Export context after major changes
- Use descriptive names for contexts
- Export before troubleshooting complex issues
- Create contexts before system updates

### Context Organization
```bash
# Good naming conventions
./manage.sh export-context initial-setup-complete
./manage.sh export-context gpu-monitoring-added
./manage.sh export-context deepseek-model-optimized
./manage.sh export-context before-docker-update
```

### Session Continuity Workflow
1. **Session Start**: Import relevant context
2. **Work Session**: Make changes, test, optimize
3. **Session End**: Export updated context
4. **Document**: Add notes about changes/issues

## Automated Context Management

### Automatic Exports
Add to your workflow scripts:

```bash
# Before major operations
./manage.sh export-context before-$(date +%H%M)-$1

# After successful changes
./manage.sh export-context after-$(date +%H%M)-$1
```

### Context Cleanup
```bash
# Clean old contexts (keeps last 30 days)
./export-context.sh clean

# Manual cleanup
find ./context -name "*.json" -mtime +7 -delete
```

## Integration with AI Conversations

### Effective Context Sharing
When sharing context with an AI assistant:

1. **Start with project overview:**
   ```
   Project: Ollama with Intel Arc GPU support
   Hardware: Intel Arc A770 16GB
   Goal: Running DeepSeek-Coder-V2 efficiently
   ```

2. **Share relevant context sections:**
   ```
   Current status: [paste ollama_state from context]
   Recent issues: [paste from recent_logs]
   System info: [paste relevant system_info]
   ```

3. **Be specific about your current needs:**
   ```
   I need help with: [specific problem]
   Expected behavior: [what should happen]
   Current behavior: [what actually happens]
   ```

### Context Templates

Create standard context templates for common scenarios:

```bash
# Performance tuning session
./manage.sh export-context perf-baseline-$(date +%Y%m%d)

# Model testing session  
./manage.sh export-context model-test-$(date +%Y%m%d)

# Troubleshooting session
./manage.sh export-context debug-$(date +%Y%m%d)
```

## Troubleshooting Context Issues

### Context Export Fails
```bash
# Check permissions
ls -la ./context/

# Check disk space
df -h .

# Manual export
./export-context.sh export debug-export
```

### Context Import Issues
```bash
# Validate JSON
jq . context/my-context.json

# Check file exists
ls -la context/

# Show context content
./export-context.sh show my-context.json
```

### Missing Context Information
- Ensure services are running when exporting
- Check if GPU tools are accessible
- Verify Docker permissions
- Review export script dependencies

## Advanced Usage

### Custom Context Scripts
Create specialized context exports for specific use cases:

```bash
# GPU-focused context
docker exec ollama-server-blackbox gpu-stats > context/gpu-context-$(date +%Y%m%d).txt

# Model-focused context
docker exec ollama-server-blackbox ollama list > context/models-$(date +%Y%m%d).txt

# Performance context
docker stats --no-stream > context/performance-$(date +%Y%m%d).txt
```

### Context Versioning
Track context evolution:

```bash
# Before major changes
./manage.sh export-context v1.0-stable

# After changes
./manage.sh export-context v1.1-experimental

# Production ready
./manage.sh export-context v1.1-production
```

This context management system helps maintain continuity between sessions and provides comprehensive project state information for effective AI assistance.