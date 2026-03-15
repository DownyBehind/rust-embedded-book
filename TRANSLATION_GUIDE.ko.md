# Korean Translation Guide

## Goals

- Keep technical meaning identical to upstream.
- Preserve mdBook structure and link integrity.
- Maintain consistent terminology across chapters.

## Non-negotiable Rules

- Do not rename files or directories referenced by `src/SUMMARY.md`.
- Do not change code behavior in examples.
- Keep relative links and image paths as-is unless they are already broken.
- Keep license and attribution statements intact.

## Translation Style

- Prefer clear, direct Korean over literal word-by-word translation.
- Keep product names, crate names, and commands in original form.
- Translate headings and body text, but preserve markdown structure.

## PR Unit

- Recommended size: 1-3 chapters or 8-12 files.
- Each PR must include validation results from build/test/link checks.

## Weekly Upstream Sync

1. Fetch upstream changes.
2. Classify changes: new files, moved files, prose, links.
3. Apply updates to translation branch.
4. Run validation.
5. Merge and publish.
