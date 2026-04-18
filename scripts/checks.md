# Discovery verification checklist

This file is the single source of truth for quality gates in the discovery workflow. Each bullet is a yes/no question the LLM answers while reading a candidate repo. The script reads this file to build both the LLM prompt and the JSON schema for structured output, then applies every check as a hard gate before writing a PR.

**To add a check:** add a bullet in the format below. The script will automatically include it in the prompt, the schema, and the hard filter.

**To remove a check:** delete or comment out the bullet.

**Format:**

```
- **check_name** — Question the model should answer yes/no.
```

The `check_name` must be `snake_case`, globally unique, and appear exactly once. The question should be unambiguous and answerable from the repo's README + description alone. You can use `{{subject.name}}` inside the question text — it'll be substituted at runtime.

## Checks

- **readme_is_about_project** — Does the README describe THIS specific project, its features, and how to use it? (not empty, not a generic template, not someone else's README copy-pasted in)
- **install_command_matches_name** — Does the README contain an install or import command that references this project's own package name? (e.g. `npm install <this-project>`, or an import statement that uses the project's name)
- **has_usage_example** — Does the README contain a working code example showing how to use this project? (actual runnable code, not just a feature list)
- **describes_unique_value** — Does the README explain what makes THIS project distinct from {{subject.canonical_repo}} itself? (e.g. a different backend, a language port, a bridge to another ecosystem — not just a rebrand)
- **is_not_copy_of_canonical** — Is the README substantively its own writing, NOT a verbatim or near-verbatim copy of the canonical {{subject.name}} README provided to you?
- **has_real_code** — Based on the README and description, does the repo appear to have real source code implementing what it describes? (not a stub, placeholder, or bookmark repo)
- **is_subject_focused** — Is {{subject.name}} central to this project's identity? A port, adapter, or wrapper of {{subject.name}} passes. A broader platform that happens to ship one {{subject.name}} adapter among many supported targets does NOT pass.
