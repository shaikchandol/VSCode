Param()

# Approve all Markdown docs by setting the Status field in the metadata table to 'Approved'.
# Usage: .\scripts\approve_all_docs.ps1

$root = Join-Path -Path (Get-Location) -ChildPath "EnterpriseRetailAI-Docs"
if (-not (Test-Path $root)) {
    Write-Error "Docs folder not found: $root"
    exit 1
}

$files = Get-ChildItem -Path $root -Filter *.md -Recurse
$pattern = '\|\s*Status\s*\|.*\|'

foreach ($f in $files) {
    Write-Host "Processing: $($f.FullName)"
    $content = Get-Content -Raw -Path $f.FullName
    if ($content -match $pattern) {
        $new = $content -replace $pattern, '| Status | Approved |'
        if ($new -ne $content) {
            Set-Content -Path $f.FullName -Value $new -Force
            Write-Host "Updated Status in $($f.Name)"
        } else {
            Write-Host "Status already Approved in $($f.Name)"
        }
    } else {
        Write-Host "No Status field found in $($f.Name) - prepending metadata block"
        $meta = @"
| Attribute | Value |
|---|---|
| Document ID | TODO |
| Type | TODO |
| Version | 1.0 |
| Status | Approved |
| Author | Enterprise Architecture |
| Date | $(Get-Date -Format 'MMMM yyyy') |

---
"@
        $new = $meta + "`r`n" + $content
        Set-Content -Path $f.FullName -Value $new -Force
        Write-Host "Prepended metadata to $($f.Name)"
    }
}

Write-Host "Done: processed $($files.Count) files."
