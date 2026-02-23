#!/usr/bin/env python3
"""
Generate SKILL.md files from agent JSON prompts and update agent JSONs
with per-agent MCP configs, includeMcpJson, and resources.
"""
import json
import os
import textwrap

AGENTS_DIR = os.path.join(os.path.dirname(__file__), "agents")
SKILLS_DIR = os.path.join(os.path.dirname(__file__), "skills")

# MCP server definitions
MCP_SERVERS = {
    "filesystem": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", "$HOME"]
    },
    "memory": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "context7": {
        "command": "npx",
        "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "sequential-thinking": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "puppeteer": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    },
    "playwright": {
        "command": "npx",
        "args": ["-y", "@playwright/mcp"]
    },
    "dynamodb": {
        "command": "uvx",
        "args": ["awslabs.dynamodb-mcp-server@latest"],
        "env": {
            "AWS_REGION": "ap-southeast-2",
            "AWS_PROFILE": "default",
            "DDB-MCP-READONLY": "false"
        }
    },
    "aws-kb": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-aws-kb-retrieval"],
        "env": {
            "AWS_PROFILE": "default"
        }
    }
}

# Agent-to-MCP mapping (beyond the common filesystem + memory)
AGENT_MCPS = {
    "architecture-expert":      ["context7", "sequential-thinking", "aws-kb"],
    "cdk-expert-ts":        ["context7", "aws-kb"],
    "cdk-expert-python":    ["context7", "aws-kb"],
    "code-reviewer":            [],
    "data-scientist":           ["context7", "dynamodb", "aws-kb"],
    "devops-engineer":          ["context7", "playwright"],
    "documentation-engineer":   ["context7"],
    "frontend-engineer-ts":     ["context7"],
    "frontend-engineer-dart":   ["context7"],
    "linux-specialist":         [],
    "product-manager":          [],
    "project-coordinator":      [],
    "python-backend":           ["context7", "dynamodb", "aws-kb"],
    "python-test-engineer":     ["context7", "dynamodb"],
    "security-specialist":      ["context7", "sequential-thinking", "aws-kb"],
    "test-coordinator":         ["playwright"],
    "typescript-test-engineer":  ["context7", "sequential-thinking", "puppeteer", "playwright"],
    "ui-ux-designer":           ["context7", "puppeteer"],
}

# Brief role summaries for the slimmed-down prompt field
BRIEF_PROMPTS = {
    "architecture-expert": "You are a pragmatic AWS solutions architect. Follow the detailed guidelines in your skill resource for security, scalability, cost-effectiveness, and caching strategies.",
    "cdk-expert-ts": "You are an AWS CDK expert specializing in TypeScript infrastructure as code. Follow the detailed guidelines in your skill resource.",
    "cdk-expert-python": "You are an AWS CDK expert specializing in Python infrastructure as code. Follow the detailed guidelines in your skill resource.",
    "code-reviewer": "You are a senior engineer reviewing for security, architecture, and unnecessary complexity. Follow the detailed guidelines in your skill resource.",
    "data-scientist": "You are a data scientist and data engineer with deep expertise in AWS data services, big data processing, and machine learning. Follow the detailed guidelines in your skill resource.",
    "devops-engineer": "You are a DevOps engineer specializing in secure CI/CD pipelines, load testing, and monitoring. Follow the detailed guidelines in your skill resource.",
    "documentation-engineer": "You are a documentation engineer focused on clear, concise, up-to-date documentation. Follow the detailed guidelines in your skill resource.",
    "frontend-engineer-ts": "You are a frontend engineer focused on simple, clean React with TypeScript. Follow the detailed guidelines in your skill resource.",
    "frontend-engineer-dart": "You are a frontend engineer focused on clean, idiomatic Flutter and Dart. Follow the detailed guidelines in your skill resource.",
    "linux-specialist": "You are a Linux SME with deep command line, git, and containerization expertise. Follow the detailed guidelines in your skill resource.",
    "product-manager": "You are a product manager focused on spec-driven development and feature preservation. Follow the detailed guidelines in your skill resource.",
    "project-coordinator": "You are a project coordinator responsible for maintaining project context and orchestrating agent collaboration. Follow the detailed guidelines in your skill resource.",
    "python-backend": "You are a Senior Python 3.12 backend engineer focused on clean, typed, functional code with database expertise. Follow the detailed guidelines in your skill resource.",
    "python-test-engineer": "You are a Python test engineer writing pragmatic pytest tests and enforcing code standards. Follow the detailed guidelines in your skill resource.",
    "security-specialist": "You are a senior application security engineer specializing in secure development, threat modeling, and cloud security hardening. Follow the detailed guidelines in your skill resource.",
    "test-coordinator": "You are a test coordinator enforcing test-driven development and quality standards. Follow the detailed guidelines in your skill resource.",
    "typescript-test-engineer": "You are a TypeScript test engineer for pragmatic testing and code quality. Follow the detailed guidelines in your skill resource.",
    "ui-ux-designer": "You are a UI/UX designer focused on intuitive, beautiful, accessible interfaces. Follow the detailed guidelines in your skill resource.",
}


def generate_skill_md(name, description, prompt_content):
    """Generate a SKILL.md file with YAML frontmatter."""
    return f"""---
name: {name}
description: {description}
---

{prompt_content}
"""


def build_mcp_servers(agent_name):
    """Build the mcpServers dict for an agent."""
    servers = {}
    # Common MCPs for all agents
    servers["filesystem"] = MCP_SERVERS["filesystem"].copy()
    servers["memory"] = MCP_SERVERS["memory"].copy()

    # Agent-specific MCPs
    extra_mcps = AGENT_MCPS.get(agent_name, [])
    for mcp_name in extra_mcps:
        servers[mcp_name] = MCP_SERVERS[mcp_name].copy()
        # Deep copy env if present
        if "env" in MCP_SERVERS[mcp_name]:
            servers[mcp_name]["env"] = MCP_SERVERS[mcp_name]["env"].copy()

    return servers


def process_agents():
    """Process all agent JSON files."""
    for filename in sorted(os.listdir(AGENTS_DIR)):
        if not filename.endswith(".json"):
            continue

        agent_name = filename.replace(".json", "")
        filepath = os.path.join(AGENTS_DIR, filename)

        with open(filepath, "r") as f:
            agent = json.load(f)

        # 1. Create SKILL.md
        skill_dir = os.path.join(SKILLS_DIR, agent_name)
        os.makedirs(skill_dir, exist_ok=True)

        skill_content = generate_skill_md(
            agent["name"],
            agent["description"],
            agent["prompt"]
        )

        skill_path = os.path.join(skill_dir, "SKILL.md")
        with open(skill_path, "w") as f:
            f.write(skill_content)

        print(f"  + skill: {agent_name}/SKILL.md")

        # 2. Update agent JSON
        brief_prompt = BRIEF_PROMPTS.get(agent_name, agent["prompt"][:200])
        mcp_servers = build_mcp_servers(agent_name)

        updated_agent = {
            "name": agent["name"],
            "description": agent["description"],
            "tools": agent["tools"],
            "allowedTools": agent["allowedTools"],
            "prompt": brief_prompt,
            "includeMcpJson": False,
            "mcpServers": mcp_servers,
            "resources": [
                "file://.kiro/steering/**/*.md",
                f"skill://.kiro/skills/{agent_name}/SKILL.md"
            ]
        }

        with open(filepath, "w") as f:
            json.dump(updated_agent, f, indent=4)
            f.write("\n")

        mcp_names = ["filesystem", "memory"] + AGENT_MCPS.get(agent_name, [])
        print(f"  * agent: {agent_name}.json -> MCPs: {', '.join(mcp_names)}")


if __name__ == "__main__":
    print("Generating SKILL.md files and updating agent JSONs...\n")
    process_agents()
    print(f"\nDone! Generated skills in {SKILLS_DIR}")
    print(f"Updated agents in {AGENTS_DIR}")
