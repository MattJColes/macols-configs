---
name: writing-blog-posts
description: Write blog posts for Matt Coles in his voice for coles.codes. Use when drafting, editing, or outlining posts for the blog.
compatibility: opencode
---

# Writing Blog Posts for Matt Coles

Matt Coles blogs at coles.codes. This skill captures his voice, positioning, and
publishing process. Read it before drafting or editing any post.

## Who Matt is (positioning)
- Principal Engineer at AWS, based in Melbourne. Posts should read like a principal
  engineer wrote them: confident, signal-rich, judgement-led. Keep a slight authoritative
  edge — never pompous, never credential-flexing.
- Lead with what he built or tried, not his title.
- He speaks at user groups and conferences (AWS re:Invent, PyCon AU), has a YouTube
  channel (https://www.youtube.com/@MattJColes), and used to present on "Devs in the Shed".
  Fine to reference this credibility lightly when it's relevant — never as a flex.

## Voice (the key rules)
- Middle-ground casual: conversational and a bit terse. Short fragments and the occasional
  run-on. First person, present tense. Go easy on em-dashes (overusing them reads as AI).
- KEEP standard capitalisation and apostrophes — capital `I`, `don't`, `it's`. It should
  read deliberate, not like typos. (Matt's raw chat style is lowercase-i and dropped
  apostrophes; do NOT replicate that in published prose.)
- Concrete over corporate. No buzzword stacking. Link to the repo / sources rather than
  describing them at length.
- Tighten wordy or cutesy phrasing. Example: "where I dump the experiments" became
  "where I write up the work that's held up".
- Prefer his phrasing "simple first, room to grow later" (he chose "grow" over "flex").
- Short paragraphs.

## Avoid (explicit dislikes)
- The opener "Most of what I do starts as 'I wonder if I can…'". Don't use that framing.
- Over-self-deprecation that undersells him, e.g. "half of it doesn't survive contact with
  reality / the half that does ends up here." A little humility is fine — but frame around
  judgement, trade-offs, and the patterns behind what works: what's worth sharing and *why*.
- AI-detector tells — Matt runs his drafts past these. Don't pile up em-dashes; don't lean on
  rule-of-three lists or "X, not Y" antithesis; skip cutesy understatement ("gently out of
  hand", "far too many containers", "out-ranked by our cats"). Vary sentence length, use plain
  words, and keep a couple of genuinely personal asides.

## The meta / ironic angle (Matt likes this — use it)
- The blog is called "coles.codes", but these days he specs and prompts a lot of it up for
  AI to write — while still doing some "artisanally". Lean into that irony with dry,
  confident humour: it's a deliberate principal-engineer workflow choice (spec well,
  delegate, review), not laziness. Useful as a recurring wink, especially in meta/intro posts.

## Topics & identity (weave in naturally when relevant)
- Python with a strong emphasis on type safety: Pydantic, PydanticAI, FastAPI, AWS Strands.
- AI agents doing the boring parts, plus agent orchestration.
- Open-source LLMs (Qwen, GLM); local fine-tuning including vision models / OCR, on a
  Framework Desktop and a DGX Spark (Unsloth).
- Homelab: Raspberry Pis, a NAS, OptiPlexes, routers — all on Tailscale, lots of containers.
- Apps: into Flutter lately; has done native and React Native.
- Backends: FastAPI, starting as a modular monolith and peeling off microservices only
  where something genuinely needs to scale.
- Favourite AWS services: Bedrock, EventBridge, Fargate (ECS), and CDK.
- Dev environment: Claude Code + Claude Opus daily, CMUX on Mac, ricing Linux + Claude Code
  configs.

## Process
- Put posts in `hugo/content/posts/`.
- Body starts headings at `##` — the title is the only H1.
- Link to related posts where it helps the reader.

## SEO hygiene checklist
Front matter:
- `title` — specific and search-friendly.
- `description` — always present, ~120–155 chars. It feeds the meta description,
  OpenGraph, JSON-LD, and llms.txt, so make it count.
- `tags` — relevant, consistent.
- `date`, plus `lastmod` when the post is materially edited.

Body:
- Descriptive link text (no "click here") and image alt text.
- Link to related posts.
- Keep slugs stable once a post is published.
