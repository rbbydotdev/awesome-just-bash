# Awesome just-bash [![Awesome](https://awesome.re/badge-flat.svg)](https://awesome.re)

> A curated list of resources for [just-bash](https://github.com/vercel-labs/just-bash) — a virtual bash environment with an in-memory filesystem, designed for AI agents.

just-bash gives an agent a real-feeling shell — pipes, redirections, loops, `jq`, `sqlite3`, optional Python and JS — without giving it your machine. This list tracks ports, filesystem adapters, integrations, and projects building on it.

## Contents

- [Official](#official)
- [Ports](#ports)
- [Filesystem Adapters](#filesystem-adapters)
- [Libraries](#libraries)
- [Integrations](#integrations)
- [Built With just-bash](#built-with-just-bash)
- [Contributing](#contributing)

## Official

- [just-bash](https://github.com/vercel-labs/just-bash) — The original TypeScript implementation from Vercel Labs. ![](https://img.shields.io/github/stars/vercel-labs/just-bash?style=flat-square&label=%20&color=gray)
- [bash-tool](https://github.com/vercel-labs/bash-tool) — A thin AI SDK tool wrapper around just-bash, ready to drop into a `generateText` / `streamText` call. ![](https://img.shields.io/github/stars/vercel-labs/bash-tool?style=flat-square&label=%20&color=gray)
- [justbash.dev](https://justbash.dev/) — Project homepage and docs.

## Ports

Reimplementations of just-bash in other languages.

- [just-bash-py](https://github.com/dbreunig/just-bash-py) — Pure-Python port by Drew Breunig. Same in-memory virtual filesystem model, callable from Python agents. ![](https://img.shields.io/github/stars/dbreunig/just-bash-py?style=flat-square&label=%20&color=gray)
- [just-bash (Rust)](https://github.com/arthur-zhang/just-bash) — Rust port. ![](https://img.shields.io/github/stars/arthur-zhang/just-bash?style=flat-square&label=%20&color=gray)
- [just-bash-rs](https://github.com/nate-trojian/just-bash-rs) — Second Rust port with three filesystem modes (Memory, ReadThrough, Passthrough), 25 built-in commands, and a declarative command extension system. ![](https://img.shields.io/github/stars/nate-trojian/just-bash-rs?style=flat-square&label=%20&color=gray)
- [just-bash-swift](https://github.com/mweinbach/just-bash-swift) — Pure-Swift port targeting iOS, macOS, and iPadOS where `Process`/`NSTask` are unavailable. In-memory VFS, 40+ commands, recursive-descent parser, ships as a SwiftPM library. ![](https://img.shields.io/github/stars/mweinbach/just-bash-swift?style=flat-square&label=%20&color=gray)
- [just_bash](https://github.com/elixir-ai-tools/just_bash) — Elixir port with in-memory VFS, HTTPS-only network access with host allowlists, custom command behaviour via `JustBash.Commands.Command`, and a `~b` sigil for one-liner scripting. ![](https://img.shields.io/github/stars/elixir-ai-tools/just_bash?style=flat-square&label=%20&color=gray)

## Filesystem Adapters

just-bash ships with `InMemoryFs`, `OverlayFs`, `ReadWriteFs`, and `MountableFs`. These pluggable adapters add new backends.

- [just-bash-dropbox](https://github.com/manishrc/just-bash-dropbox) — Dropbox-backed filesystem. Reads and writes go to a Dropbox account. ![](https://img.shields.io/github/stars/manishrc/just-bash-dropbox?style=flat-square&label=%20&color=gray)
- [just-bash-gdrive](https://github.com/alexknowshtml/just-bash-gdrive) — Google Drive filesystem adapter. ![](https://img.shields.io/github/stars/alexknowshtml/just-bash-gdrive?style=flat-square&label=%20&color=gray)
- [just-bash-openfs](https://github.com/jeffchuber/just-bash-openfs) — OpenFS adapter. ![](https://img.shields.io/github/stars/jeffchuber/just-bash-openfs?style=flat-square&label=%20&color=gray)
- [bash-gres](https://github.com/marcoripa96/bash-gres) — PostgreSQL-backed `IFileSystem` with workspace isolation via row-level security, BM25 full-text search, and optional pgvector semantic/hybrid search. Works with `postgres.js` or Drizzle. ![](https://img.shields.io/github/stars/marcoripa96/bash-gres?style=flat-square&label=%20&color=gray)
- [just-bash-postgres](https://github.com/F1nnM/just-bash-postgres) — Second Postgres filesystem provider using ltree hierarchy, full-text search, pgvector semantic/hybrid search, and per-session row-level security. ![](https://img.shields.io/github/stars/F1nnM/just-bash-postgres?style=flat-square&label=%20&color=gray)
- [durable-bash](https://github.com/StableModels/durable-bash) — Cloudflare Durable Object-backed `IFileSystem` adapter. Persists bash command output in a Durable Object's SQLite storage; 121 tests, full `IFileSystem` interface coverage, ships as `@stablemodels/durable-bash`. ![](https://img.shields.io/github/stars/StableModels/durable-bash?style=flat-square&label=%20&color=gray)

## Libraries

Helper packages for building on top of just-bash.

- [just-bash-util](https://github.com/blindmansion/just-bash-util) — Type-safe CLI command framework for `defineCommand`. Subcommands with option inheritance, auto-generated `--help`, typo suggestions, and a `command()` builder reminiscent of commander/yargs. ![](https://img.shields.io/github/stars/blindmansion/just-bash-util?style=flat-square&label=%20&color=gray)
- [just-git](https://github.com/blindmansion/just-git) — Pure-TypeScript git implementation with 36 commands that plugs into just-bash as a custom command — pipes, redirects, and `&&` chaining work natively. Also ships a standalone embeddable git server with HTTP/SSH/in-process transport and pluggable storage (SQLite, Postgres, Durable Objects). ![](https://img.shields.io/github/stars/blindmansion/just-git?style=flat-square&label=%20&color=gray)

## Integrations

- [agentfs](https://github.com/tursodatabase/agentfs) — Turso's filesystem-for-agents. Ships an `ai-sdk-just-bash` example showing the two together. ![](https://img.shields.io/github/stars/tursodatabase/agentfs?style=flat-square&label=%20&color=gray)
- [just-bash-mcp](https://github.com/dalist1/just-bash-mcp) — MCP server exposing a sandboxed just-bash environment to any MCP client. ![](https://img.shields.io/github/stars/dalist1/just-bash-mcp?style=flat-square&label=%20&color=gray)
- [convex-sandbox](https://github.com/wantpinow/convex-sandbox) — Persistent bash sandboxes backed by Convex file storage. Lazy filesystem hydration, mutation-diffing writeback, and session-persisted `cwd` — no VMs or containers. ![](https://img.shields.io/github/stars/wantpinow/convex-sandbox?style=flat-square&label=%20&color=gray)
- [context-fs](https://github.com/mwolting/context-fs) — Exposes APIs, databases, and services as virtual filesystems navigable by AI agents via `ls`/`cat`/`find`; ships a `@context-fs/just-bash` package that runs bash scripts against those virtual filesystems. ![](https://img.shields.io/github/stars/mwolting/context-fs?style=flat-square&label=%20&color=gray)

## Built With just-bash

Notable projects that depend on just-bash in the wild.

- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — Vercel's agent browser uses just-bash in its docs runtime. ![](https://img.shields.io/github/stars/vercel-labs/agent-browser?style=flat-square&label=%20&color=gray)
- [coplane/localsandbox](https://github.com/coplane/localsandbox) — Local sandbox shim that wires just-bash and agentfs together. ![](https://img.shields.io/github/stars/coplane/localsandbox?style=flat-square&label=%20&color=gray)

## Contributing

Contributions welcome. Open a PR adding your project, or an issue with a link and I'll take a look. Please keep entries to one line and lead with what makes the project distinct, not what it generically does.

## License

[![CC0](https://licensebuttons.net/p/zero/1.0/80x15.png)](https://creativecommons.org/publicdomain/zero/1.0/)

To the extent possible under law, the contributors have waived all copyright and related or neighboring rights to this work.
