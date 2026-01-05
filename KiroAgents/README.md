# Kiro CLI Agents & MCPs

This directory contains specialized AI agents and Model Context Protocol (MCP) server configurations for Kiro CLI (formerly Amazon Q Developer CLI).

## 📦 Model Context Protocol (MCP) Servers

MCPs extend Kiro's capabilities by providing access to external tools and data sources.

### Installed MCPs

1. **filesystem** - File operations for all agents
   - Read, write, and navigate file systems
   - Used by all agents for code and documentation work

2. **sequential-thinking** - Complex problem-solving and structured reasoning
   - Breaks down problems into manageable steps
   - Ideal for system design planning and architectural decisions
   - Used by architecture-expert and all agents for complex tasks

3. **puppeteer** - Browser automation and web interaction
   - Navigate websites, take screenshots, interact with web pages
   - Critical for UI testing and automation
   - Used by test engineers for browser-based testing

4. **playwright** - Cross-browser testing and modern web automation
   - Advanced web automation with cross-browser support
   - Feature-rich alternative to Puppeteer
   - Used by typescript-test-engineer and python-test-engineer

5. **memory** - Knowledge graph memory for persistent context
   - Maintains project context across sessions using knowledge graphs
   - Prevents repetition and retains key project details
   - Automatically used by all agents

6. **aws-kb** - AWS Knowledge Base retrieval
   - Integration with AWS Knowledge Bases for RAG applications
   - Used by architecture-expert and backend developers

7. **context7** - Real-time version-specific documentation
   - Provides up-to-date documentation for libraries and frameworks
   - Used by all agents when researching latest APIs

8. **dynamodb** - DynamoDB data modeling and operations
   - Direct DynamoDB table management and queries
   - Data modeling assistance
   - Used by python-backend and data-scientist

## 🤖 Specialized Agents

### Architecture & Design

#### **architecture-expert**
- System architecture and design decisions
- Creates architecture diagrams with Mermaid
- Evaluates scalability and performance considerations
- Focuses on simplicity and avoiding over-engineering

#### **ui-ux-designer**
- User interface and experience design
- Creates wireframes and design specifications
- WCAG accessibility compliance
- Mobile-first responsive design

### Development

#### **python-backend-agent**
- Python 3.12 backend development (Flask, FastAPI)
- DynamoDB, Redis, MongoDB expertise
- Type-safe, functional code with DRY principles
- AWS Cognito authentication and security
- **Auto-runs tests after code changes**

#### **frontend-engineer**
- TypeScript and React development
- Tailwind CSS, lightweight component design
- AWS Cognito integration
- CloudWatch RUM monitoring
- **Auto-runs tests after code changes**

#### **cdk-expert**
- AWS CDK TypeScript infrastructure as code
- Fargate ECS, Lambda, Step Functions patterns
- Reusable constructs and best practices
- **Auto-runs CDK tests after changes**

#### **data-scientist**
- Pandas, NumPy, scikit-learn for data analysis
- ETL pipelines and data quality
- ML model development and evaluation
- Maintains DATA_CATALOG.md documentation

#### **linux-specialist**
- Bash scripting and system administration
- POSIX-compliant scripts for portability
- System troubleshooting and DevOps tasks
- Security hardening and performance tuning

### Testing

#### **test-coordinator**
- Orchestrates test-first development approach
- Coordinates between python-test-engineer and ts-test-engineer
- Defines testing strategy and coverage requirements
- Ensures 90%+ code coverage

#### **python-test-engineer**
- pytest for Python testing
- Integration tests with real dev resources
- Minimal mocking, prefers real I/O
- Black formatting and ruff linting

#### **typescript-test-engineer**
- Jest/Mocha for unit tests
- Playwright for E2E browser testing
- Real dev API integration tests
- ESLint and Prettier formatting

### DevOps & Infrastructure

#### **devops-engineer**
- GitHub Actions or GitLab CI pipelines
- Security scanning (Semgrep SAST, dependency checks)
- Load testing with Locust
- Playwright canaries for monitoring

#### **code-reviewer**
- Security vulnerability detection
- Removes over-engineering and unnecessary abstractions
- Enforces early refactoring before complexity grows
- Aggressive comment cleanup (keeps only valuable comments)

### Documentation & Management

#### **documentation-engineer**
- README, DEVELOPMENT, ARCHITECTURE docs
- Mermaid diagrams for visualizations
- Keeps docs simple, current, and actionable
- Uses templates for consistency

#### **product-manager**
- Product requirements and feature specifications
- User story creation and success metrics
- Compliance and regulatory requirements
- Coordinates with ui-ux-designer and architecture-expert

#### **project-coordinator**
- High-level project planning and milestone tracking
- Assigns tasks to appropriate specialized agents
- Manages dependencies between teams
- Ensures compatibility across the stack

## 🚀 Installation

Run the installation script to set up all agents and MCPs:

```bash
./install_agents.sh
```

This will:
- Install all agents to `~/.kiro/agents/`
- Optionally install and configure MCP servers
- Set up Kiro CLI configuration

## 🔧 Configuration

MCP configuration is stored in:
```
~/.kiro/settings/mcp.json
```

Agent configurations are stored in:
```
~/.kiro/agents/
```

Knowledge graph memory is stored in:
```
~/.kiro/memory
```

## 📝 Usage

Agents are invoked automatically by Kiro CLI based on the task. Each agent:

1. **Writes code** following best practices and style guides
2. **Runs tests** automatically after code changes (up to 3 fix attempts)
3. **Suggests commit messages** in conventional commit format
4. **Uses MCPs** automatically when needed (Sequential Thinking, Memory, etc.)

### Basic Commands

```bash
# Start Kiro chat session
kiro chat

# Alternative command (backwards compatible)
q chat

# List available agents
/agent list

# Use specific agent
/agent use code-reviewer

# Generate a new agent
/agent generate
```

### Example Prompts

```bash
"Use code-reviewer to review my changes"
"Switch to frontend-engineer agent"
"Use python-backend to help with the API"
"Use architecture-expert to design a new microservice"
```

## 🔄 Workflow Example

```bash
User: "Add user authentication with Cognito"

1. test-coordinator defines testing strategy
2. python-test-engineer writes tests first
3. python-backend-agent implements auth code
4. python-backend-agent auto-runs tests
5. If tests fail, auto-fixes errors (max 3 attempts)
6. code-reviewer checks for security issues
7. Suggests commit: "feat: add Cognito JWT authentication"
```

## 📚 Agent Coordination

Agents work together seamlessly:

- **architecture-expert** → designs system → **cdk-expert** implements infrastructure
- **product-manager** → defines requirements → **ui-ux-designer** creates designs → **frontend-engineer** builds UI
- **test-coordinator** → plans testing → **test engineers** write tests → **developers** implement
- **documentation-engineer** → updates docs after all changes

## 🛠️ Maintenance

- Update MCPs: Re-run `./install_mcps.sh`
- Update agents: Edit individual `.json` files in the `agents/` directory
- View agent configs: Check `~/.kiro/agents/`
- Reinstall agents: Re-run `./install_agents.sh`

## 🔗 Integration with AWS

All agents are optimized for AWS development:
- Seamless AWS Cognito authentication
- DynamoDB and other AWS service expertise
- CDK infrastructure as code patterns
- CloudWatch logging and monitoring
- AWS Secrets Manager for credential management

## 📖 Migration from Amazon Q Developer CLI

Kiro CLI is backwards compatible with Amazon Q Developer CLI. If you're migrating:

1. **Automatic Migration**: When you install Kiro CLI, your Q Developer configuration is automatically migrated
2. **Manual Setup**: If you prefer a fresh start, use the installation scripts in this directory
3. **Backwards Compatibility**: You can still use `q chat` instead of `kiro chat`

### Key Differences

| Feature | Amazon Q Developer CLI | Kiro CLI |
|---------|------------------------|----------|
| Config directory | `~/.aws/amazonq/` | `~/.kiro/` |
| Agents directory | `~/.aws/amazonq/cli-agents/` | `~/.kiro/agents/` |
| MCP config | `~/.aws/amazonq/mcp-config.json` | `~/.kiro/settings/mcp.json` |
| Command | `q chat` | `kiro chat` or `q chat` |

## 📚 Additional Resources

- [Kiro CLI Documentation](https://kiro.dev/docs/cli/)
- [Kiro Agent Configuration Reference](https://kiro.dev/docs/cli/custom-agents/configuration-reference/)
- [MCP Servers](https://modelcontextprotocol.io/)
- [AWS Knowledge Bases](https://aws.amazon.com/bedrock/knowledge-bases/)

## 🎯 Next Steps

1. Run `./install_agents.sh` to install all agents
2. Configure AWS credentials if not already done
3. Start using Kiro: `kiro chat`
4. Try different agents for different tasks
5. Customize agent prompts as needed

---

**Note**: Kiro CLI is the successor to Amazon Q Developer CLI. All functionality is preserved and enhanced with additional features. For the latest updates, visit [kiro.dev](https://kiro.dev/).
