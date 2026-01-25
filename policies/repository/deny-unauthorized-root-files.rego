# Repository Structure Policy
# Prevents arbitrary files/directories in repository root

package main

# Allowed root-level files (exhaustive list)
allowed_root_files := {
    ".gitignore",
    ".mise.toml",
    "README.md",
    "CONTRIBUTING.md",
    "Taskfile.yml",
    "agents.md",
}

# Allowed root-level directories
allowed_root_dirs := {
    ".git",
    ".github",
    ".specify",
    ".vscode",
    "constitution",
    "contracts",
    "bootstrap",
    "specs",
    "docs",
    "infra",
    "kubernetes",
    "ops",
    "policies",
    "requirements",
    "scripts",
    "stacks",
    "talos",
    "test",
}

# Prohibited file patterns in root (case-insensitive)
prohibited_patterns := [
    ".*-improvements\\.md$",
    ".*-summary\\.md$",
    ".*-notes\\.md$",
    "^SUMMARY\\.md$",
    "^NOTES\\.md$",
    "^TODO\\.md$",
    "^ROADMAP\\.md$",
    "^IMPLEMENTATION.*\\.md$",
    "^GOVERNANCE-.*\\.md$",
    "^CLAUDE\\.md$",          # Agent instructions: use canonical governance sources
    "^claude\\.md$",          # (case variations)
    "^\\.gemini$",            # Agent instructions: use canonical governance sources
    "^\\.gemini\\.md$",       # (with .md extension)
]

# Check if file matches prohibited pattern
matches_prohibited_pattern(filename) if {
    some i
    pattern := prohibited_patterns[i]
    regex.match(pattern, filename)
}

# Deny unauthorized root files
deny contains msg if {
    # Get the file path from input
    filename := input.filename
    
    # Check if it's a root-level file (no directory separator)
    not str_contains(filename, "/")
    
    # Skip hidden files (start with .)
    not startswith(filename, ".")
    
    # Check if file is not in allowed list
    not allowed_root_files[filename]
    
    msg := sprintf("Unauthorized root-level file: %s\nAllowed root files: %v\nMove to docs/, ops/, or delete if temporary summary.", [filename, allowed_root_files])
}

# Deny files matching prohibited patterns
deny contains msg if {
    filename := input.filename
    not str_contains(filename, "/")
    matches_prohibited_pattern(filename)
    
    msg := sprintf("Prohibited file pattern in root: %s\nAgent instructions must live in canonical governance sources:\n  - requirements/workflow/spec.md (Agent Governance Steering)\n  - contracts/agents.md (Agent Operating Rules)\n  - .github/copilot-instructions.md (copilot-specific tool guidance)\n  - .github/agents/*.agent.md (speckit agents)\n\nSee: ADR-0030 for agent governance steering policy.", [filename])
}

# Deny unauthorized root directories
deny contains msg if {
    dirname := input.dirname
    not str_contains(dirname, "/")
    not startswith(dirname, ".")
    not allowed_root_dirs[dirname]
    
    msg := sprintf("Unauthorized root-level directory: %s\nAllowed root directories: %v", [dirname, allowed_root_dirs])
}

# Helper: Check if string contains substring
str_contains(str, substr) if {
    indexof(str, substr) != -1
}
