# test-release-workflow

A demonstration marketplace. Every skill is placeholder text; only the structure
and the automation around it are real.

## What this repository is for

It shows a proposed CI setup for a Claude Code plugin marketplace working
end to end, on real pull requests, so a reviewer can see the behaviour rather
than read a description of it.

See [`DEMO.md`](DEMO.md) for the walkthrough.

## Layout

```
.claude-plugin/marketplace.json     catalogs every pack
claude/plugin-a/                    one pack
  .claude-plugin/plugin.json          its manifest; version is the update key
  skills/skill-1/SKILL.md             what the pack ships
claude/plugin-b/                    a second pack, versioned independently
  skills/skill-2/SKILL.md
```
