# OpenCode Agents

This directory contains specialized agent definitions for OpenCode. Agents are expert assistants that can be invoked to handle specific types of tasks.

## Available Agents

### Development Agents

- **python-backend-agent** - Python 3.12 backend and Docker specialist for Pandas, Flask, FastAPI, and AI agents
- **frontend-engineer** - React/TypeScript frontend specialist with CloudFront + S3 deployment expertise
- **linux-specialist** - Linux and command line SME for shell scripting, system administration, and debugging

### Testing Agents

- **python-test-engineer** - Python testing specialist with pytest, Black formatter, and ruff linter
- **ts-test-engineer** - TypeScript testing specialist with Jest/Mocha and Playwright
- **test-coordinator** - Test strategy and coverage coordinator

### Quality & Review Agents

- **code-reviewer** - Senior code reviewer for architecture, security, and complexity analysis
- **security-specialist** - Application security specialist for threat modeling and OWASP compliance

### Architecture & Infrastructure Agents

- **architecture-expert** - AWS solutions architect for system design and infrastructure planning
- **cdk-expert-python** - AWS CDK expert using Python for infrastructure as code
- **cdk-expert-ts** - AWS CDK expert using TypeScript for infrastructure as code
- **devops-engineer** - CI/CD and containerization specialist

### Data & ML Agents

- **data-scientist** - Data analysis and machine learning specialist

### Documentation & Management Agents

- **documentation-engineer** - Technical documentation specialist
- **product-manager** - Feature tracking and specifications manager
- **project-coordinator** - Task orchestration and Memory Bank management
- **ui-ux-designer** - UI/UX design and accessibility specialist

## Usage

### As Skills (Slash Commands)

Agents are automatically available as skills with the `/` prefix:

```
/python-backend - Invoke the Python backend specialist
/code-reviewer - Invoke the code reviewer
/architecture-expert - Invoke the architecture expert
```

### Via Task Tool (Programmatic)

Agents can also be invoked programmatically via the Task tool:

```typescript
Task({
  subagent_type: "python-backend",
  description: "Build FastAPI endpoint",
  prompt: "Create a REST API endpoint for user management"
})
```

## Installation

Run the installer script to deploy agents:

```bash
# Install agents system-wide
./install_agents.sh

# Or install with skills
./install_skills.sh
```

This will install agents to `~/.config/opencode/agents/`

## Agent Structure

Each agent is defined by a Markdown file with YAML frontmatter:

```markdown
---
name: agent-name
description: Brief description of agent capabilities
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet|opus|haiku
---

Agent instructions and capabilities...
```

## System Configuration

The system-level configuration is stored in `~/.config/opencode/opencode.md` and defines core principles for all agents:

- Minimal changes approach
- Type safety emphasis
- Simple testing strategy
- Clear documentation standards

## Customization

You can customize agents by:

1. Editing agent files in `~/.config/opencode/agents/`
2. Creating new agent files following the same format
3. Modifying the system configuration in `~/.config/opencode/opencode.md`

Changes take effect after restarting OpenCode.
