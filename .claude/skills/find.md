# Find Skill

Search the codebase efficiently using available tools (Glob for file patterns, Grep for content).

## Usage

/find <pattern|keyword>

## Instructions

When invoked:
1. Determine if the query looks like a **filename/glob** (e.g., `*.kt`, `build.gradle.kts`) or **code content** (e.g., `companion object`, `compileSdk`).
2. **Filename pattern** → use Glob to find matching files.
3. **Code content** → use Grep to search file contents.
4. If ambiguous, do both: Glob first, then Grep for the most likely hits.
5. Present results concisely: file paths with line numbers (clickable), grouped by relevance.

## Examples

- `/find build.gradle.kts` → Glob for `**/build.gradle.kts`
- `/find companion object` → Grep for `companion object` in `*.kt` files
- `/find compileSdk` → Grep for `compileSdk`, Glob for `*.gradle*`
- `/find DiscoveryForegroundService` → Glob for `**/DiscoveryForeground*` + Grep for class name
