# Conversation so far (brainstorming session in progress)

**User:** `todo list` is hard to scan once the list is long. Make it easier to read.

**Assistant:** This changes a command's output that people read every day, so I'll go the architectural way. What do you look for when you run it?

**User:** What's still open. Done items just get in the way.

**Assistant:** Two approaches:
1. **Two sections (recommended).** An `Open` heading with the open items, then a `Done` heading with the finished ones.
2. **Hide finished items.** Only open items, with a `--all` flag for the rest.

I recommend 1: nothing disappears behind a flag.

**User:** Approach 1.

**Assistant:** Design: `todo list` prints `Open (3)` then each open item's text on its own line, indented two spaces; then `Done (2)` and the same for finished items. An empty section is left out. Tests cover both sections and the empty cases. Does this look right? And shall I work on a new branch `feat/list-sections` in this checkout?

**User:** Yes to both.
