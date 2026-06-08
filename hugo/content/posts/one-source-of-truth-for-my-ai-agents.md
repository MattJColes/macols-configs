---
title: "One source of truth for my AI agents across Claude Code, Kiro and OpenCode"
description: "How my macols-configs repo defines each AI coding agent once and generates it for Claude Code, Kiro and OpenCode, with hard safety living in hooks."
date: 2026-06-08
tags: ["ai-agents", "claude-code", "developer-environment", "aws", "automation"]
---

I keep most of my machine in a single repo called `macols-configs`. It sets up my
terminal, my editor, my container runtime, and the AI coding agents I lean on every
day. When I get a new laptop or spin up a fresh Linux box, I clone it, run a couple
of install scripts, and I'm back to the setup I actually think in.

This post is about the part I've spent the most time getting right: the agents.

## The problem with running three tools

I don't use one AI coding tool. Claude Code is my daily driver, but I keep Kiro
around for AWS-native work and OpenCode for running a local model when I don't want
to send code anywhere. That's three tools that all want their own flavour of "here's
a Python backend specialist" or "here's a security reviewer".

The obvious trap is writing each agent three times. You tweak the Python persona in
Claude Code, forget to copy it across, and three weeks later Kiro is giving you
advice you stopped agreeing with. The configs drift, and you stop trusting any of
them.

So I made each agent a single source file.

## One persona, generated three ways

Every agent lives in `personas/<name>/SKILL.md`. The skill body is the canonical
content. There's a small bit of frontmatter on top, and when it says `agent: true`,
the installer generates the tool-specific agent from the *same body* and just swaps
the frontmatter around. `allowed-tools` becomes `tools`, a model gets added, and the
prose stays identical.

That means the python-backend persona reads the same whether I'm in Claude Code or
Kiro. There are 21 of them now, covering development, testing, DevOps, architecture,
security, and writing (yes, including the one writing this post). I edit one file
and re-run `install.sh`. No copy-paste, nothing to forget.

The install script takes flags so I'm not forced into all-or-nothing:
`--agents-only`, `--skills-only`, `--mcps-only`, `--hooks-only`, plus `--list` to
preview what's there and `-p` for a per-project install. Simple first, room to grow
later.

## Hard safety belongs in hooks, not prose

Here's the bit I feel strongest about.

It's tempting to put your safety rules in CLAUDE.md. "Always run `cdk diff` before
deploying." "Never rename a construct ID without checking for replacement." And that
works, right up until the context window fills with the actual task and those rules
quietly lose their grip. Model-interpreted instructions degrade as the conversation
grows. They're guidance, not a guarantee.

So the rules I actually care about live in hooks instead.

The one I reach for most is a pre-deploy hook on CDK. The nastiest CDK mistake isn't
a typo, it's a construct ID rename that looks like a harmless refactor and forces a
resource to be replaced or destroyed. The hook intercepts `cdk deploy` and
`cdk destroy` at the Bash layer, pauses, and makes me confirm I've reviewed the diff
for replacements before anything runs. It's a `PreToolUse` hook that emits an "ask"
decision, so it surfaces a real prompt rather than trusting the model to remember.

That's the principle: if getting it wrong is expensive, don't leave it to a sentence
buried in a markdown file. Put it somewhere the harness enforces it.

There are gentler hooks too. A post-code hook runs the relevant tests and linters
after a change and feeds the results back so the agent can fix what it just broke. A
post-task hook does the same at the task boundary. The boring parts stay boring.

## Local models when I don't want to phone home

OpenCode is wired up to LM Studio running GLM4.7-Air locally. Some work doesn't need
a frontier model and some code I'd just rather not send over the wire, and having a
local option in the same agent setup means I don't have to think about it. Same
personas, different engine.

This sits alongside the rest of my local-model habit. I do a fair bit of fine-tuning
on a Framework Desktop and a DGX Spark, so having local inference in my everyday
coding loop is a natural extension of that.

## The terminal half

The other half of the repo is the environment those agents run inside. There are
install scripts for macOS and Ubuntu 24.04 that lay down Python 3.12 with uv, Node
22 with TypeScript and CDK, Podman for rootless containers, AWS CLI, and a LazyVim
config. There's an optional zsh and Powerlevel10k setup if I want the shell to look
nice, and my Ghostty and iTerm colour configs come along for the ride.

None of it is clever. It's just written down, version controlled, and repeatable,
which is the whole point. The value isn't any single script. It's that I never have
to remember the setup again.

## The obvious joke

The blog is called coles.codes, and these days a good chunk of the codes is me
speccing the work and handing it to an agent. This post is no exception. I described
the repo, pointed the writing-blog-posts persona at it, and reviewed the draft. That
persona is defined in the very repo it's describing, generated by the same installer
as everything else.

That's not laziness, it's the workflow I'd recommend to anyone: spec it well,
delegate it, review it carefully. The repo is the spec for how I want my tools to
behave. The agents are what happens when you write that spec down properly and stop
repeating yourself.

The repo is [on GitHub](https://github.com/MattJColes/macols-configs) if you want to
borrow any of it.
