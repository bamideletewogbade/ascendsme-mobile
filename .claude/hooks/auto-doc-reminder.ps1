# PostToolUse hook — nudges Claude to update DESIGN/TOOLS/SKILLS.md when
# relevant files change. Output goes to stdout as a system reminder.
#
# Wired in .claude/settings.local.json on Edit|Write|MultiEdit.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
    $path = $payload.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($path)) { exit 0 }

    # Normalize separators for matching
    $p = $path -replace '\\', '/'

    $doc = $null
    $reason = $null

    if ($p -match 'lib/core/tokens\.dart' -or
        $p -match 'lib/core/widgets/' -or
        $p -match 'app_theme' -or
        ($p -match 'lib/state/app_state\.dart' -and $payload.tool_input.new_string -match '(HomeLayout|NavVariant|darkMode|AppTab)')) {
        $doc = 'DESIGN.md'
        $reason = 'design tokens, theme, or UI variants may have changed'
    }
    elseif ($p -match 'lib/services/' -or
            $p -match 'lib/config\.example\.dart' -or
            $p -match 'pubspec\.yaml' -or
            $p -match 'supabase/migrations') {
        $doc = 'TOOLS.md'
        $reason = 'service integration, dependency, or config touched'
    }
    elseif ($p -match '\.claude/skills/' -or
            $p -match '\.claude/settings(\.local)?\.json') {
        $doc = 'SKILLS.md'
        $reason = 'Claude skills or settings touched'
    }

    if ($doc) {
        Write-Output "[auto-doc] $path changed - $reason. Verify $doc still matches current state; update it in this same response if anything drifted."
    }
}
catch {
    # Never block a tool call because of a doc hook
    exit 0
}

exit 0
