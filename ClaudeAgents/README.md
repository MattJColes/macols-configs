# Claude Code Agents & MCPs

This directory contains specialized AI agents and Model Context Protocol (MCP) server configurations for Claude Code.

## 📦 Model Context Protocol (MCP) Servers

MCPs extend Claude's capabilities by providing access to external tools and data sources.

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

6. **aws** - AWS service interactions
   - Integration with AWS services and APIs
   - Used by cdk-expert, python-backend, and devops-engineer

7. **dynamodb** - DynamoDB data modeling and operations
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

#### **cdk-expert-ts**
- AWS CDK TypeScript infrastructure as code
- Fargate ECS, Lambda, Step Functions patterns
- Reusable constructs and best practices
- **Auto-runs CDK tests after changes**

#### **cdk-expert-python**
- AWS CDK Python infrastructure as code
- Same patterns as TypeScript version but for Python CDK projects
- Type-safe Python constructs with dataclasses
- **Auto-runs pytest CDK tests after changes**

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

Run the installation script to set up all MCPs:

```bash
./install_mcps.sh
```

This will:
- Install all MCP servers globally via npm
- Configure Claude Code with MCP settings
- Set up AWS and DynamoDB configurations

## 🔧 Configuration

MCP configuration is stored in:
```
~/.claude/config.json
```

Knowledge graph memory is stored in:
```
~/.claude/memory
```

## 📝 Usage

Agents are invoked automatically by Claude Code based on the task. Each agent:

1. **Writes code** following best practices and style guides
2. **Runs tests** automatically after code changes (up to 3 fix attempts)
3. **Suggests commit messages** in conventional commit format
4. **Uses MCPs** automatically when needed (Sequential Thinking, Memory, etc.)

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

- **architecture-expert** → designs system → **cdk-expert-ts** or **cdk-expert-python** implements infrastructure
- **product-manager** → defines requirements → **ui-ux-designer** creates designs → **frontend-engineer** builds UI
- **test-coordinator** → plans testing → **test engineers** write tests → **developers** implement
- **documentation-engineer** → updates docs after all changes

## 🧪 Testing & Security Hooks

Automated testing and security scanning hooks are available in `/Hooks/`:

```bash
# Install the post-code hook
./Hooks/install_hooks.sh
```

The hook automatically runs after code changes:
- **pytest** - Python tests
- **jest/mocha** - JavaScript/TypeScript tests
- **bandit** - Python security scanning
- **pip-audit** - Python package vulnerability checks
- **npm audit** - Node.js package vulnerability checks

## 🛠️ Maintenance

- Update MCPs: Re-run `./install_mcps.sh`
- Update agents: Edit individual `.md` files in this directory
- View agent configs: Check frontmatter in each `.md` file (name, description, tools, model)
