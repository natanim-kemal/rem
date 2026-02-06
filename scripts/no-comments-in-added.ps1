$files = git diff --cached --name-only --diff-filter=A
$files = $files | Where-Object { $_ -and $_.Trim().Length -gt 0 }

if (-not $files) {
    exit 0
}

$ignoreFragments = @(
    "node_modules",
    "apps/mobile/build",
    "apps/mobile/.dart_tool",
    "convex/_generated",
    "apps/mobile/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
    "apps/mobile/lib/data/database/database.g.dart"
)

$extensions = @(
    ".dart",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".kt",
    ".java",
    ".gradle",
    ".kts",
    ".yml",
    ".yaml",
    ".ps1",
    ".sh",
    ".xml",
    ".html",
    ".css",
    ".scss"
)

$commentFiles = @()

foreach ($file in $files) {
    $skip = $false
    foreach ($fragment in $ignoreFragments) {
        if ($file -like "*$fragment*") {
            $skip = $true
            break
        }
    }
    if ($skip) {
        continue
    }

    $ext = [System.IO.Path]::GetExtension($file)
    if (-not $extensions.Contains($ext)) {
        continue
    }

    if (-not (Test-Path $file)) {
        continue
    }

    $content = Get-Content -Raw -LiteralPath $file -ErrorAction SilentlyContinue
    if ($null -eq $content) {
        continue
    }

    $hasComment = $false

    if ($ext -in @(".dart", ".ts", ".tsx", ".js", ".jsx", ".kt", ".java", ".gradle", ".kts")) {
        if ($content -match "(?m)^\s*//") {
            $hasComment = $true
        }
    } elseif ($ext -in @(".yml", ".yaml", ".ps1", ".sh")) {
        if ($ext -eq ".sh") {
            $lines = $content -split "`n"
            foreach ($line in $lines) {
                $trimmed = $line.TrimStart()
                if ($trimmed.StartsWith("#") -and -not $trimmed.StartsWith("#!")) {
                    $hasComment = $true
                    break
                }
            }
        } else {
            if ($content -match "(?m)^\s*#") {
                $hasComment = $true
            }
        }
    } elseif ($ext -in @(".xml", ".html")) {
        if ($content -match "<!--") {
            $hasComment = $true
        }
    } elseif ($ext -in @(".css", ".scss")) {
        if ($content -match "(?m)^\s*//") {
            $hasComment = $true
        }
    }

    if ($hasComment) {
        $commentFiles += $file
    }
}

if ($commentFiles.Count -gt 0) {
    Write-Error "Added files contain comments:`n$($commentFiles -join "`n")"
    exit 1
}

exit 0
