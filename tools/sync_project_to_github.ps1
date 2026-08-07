<#!
.SYNOPSIS
Syncs the deliverable project source to the GitHub repository configured in .env.

.DESCRIPTION
The default branch becomes the current source snapshot. Runtime data, product
assets, rendered videos, logs and all credentials are deliberately excluded.
GitHub commit history is retained.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateRange(1, 100)]
    [int]$BatchSize = 50
)

$ErrorActionPreference = 'Stop'

function Read-DotEnv([string]$Path) {
    $result = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
            $value = $matches[2].Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $result[$matches[1]] = $value
        }
    }
    $result
}

function Get-BlobSha([byte[]]$Bytes) {
    $header = [Text.Encoding]::UTF8.GetBytes("blob $($Bytes.Length)`0")
    $all = New-Object byte[] ($header.Length + $Bytes.Length)
    [Array]::Copy($header, 0, $all, 0, $header.Length)
    [Array]::Copy($Bytes, 0, $all, $header.Length, $Bytes.Length)
    (([BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash($all))) -replace '-', '').ToLowerInvariant()
}

function Invoke-GraphQl([hashtable]$Headers, [string]$Query, [hashtable]$Variables) {
    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 16 -Compress
    $response = Invoke-RestMethod -Method Post -Headers $Headers -Uri 'https://api.github.com/graphql' -ContentType 'application/json' -Body $body
    if ($response.errors) { throw ($response.errors | ConvertTo-Json -Compress) }
    $response.data
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$settings = Read-DotEnv (Join-Path $ProjectRoot '.env')
foreach ($name in 'GITHUB_TOKEN','GITHUB_OWNER','GITHUB_REPO','GITHUB_BRANCH') {
    if (-not $settings[$name]) { throw "Missing $name in .env" }
}

# Only these locations are source-controlled. Add a source directory here before it can be uploaded.
$sourceRoots = @('config','docs','manual_prompts','tools','workers','workflows','tests')
$rootNames = @('Dockerfile','.gitignore','.env.example')
$rootExtensions = @('.md','.ps1','.bat','.py','.yml','.yaml','.json')
$blockedPrefixes = @('.env','.repo-clear-','runtime/','test_logs/','openai_jobs/','local_products/','product_reference_pack/','tmp_video_review_','video_jobs/','video_output/','video_jobs_no_watermark/','video_output_no_watermark/','__pycache__/','临时文件/')
$local = @{}

Get-ChildItem -LiteralPath $ProjectRoot -File -Recurse | ForEach-Object {
    $path = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\','/') -replace '\\','/'
    $inSourceRoot = @($sourceRoots | Where-Object { $path.StartsWith("$_/", [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    $isRootSource = ($path -notmatch '/') -and (($rootNames -contains $path) -or ($rootExtensions -contains $_.Extension.ToLowerInvariant()))
    $blocked = @($blockedPrefixes | Where-Object { $path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    if (($inSourceRoot -or $isRootSource) -and -not $blocked) {
        if ($_.Length -gt 90MB) { throw "Refusing source file over 90 MB: $path" }
        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        $local[$path] = @{ sha = Get-BlobSha $bytes; contents = [Convert]::ToBase64String($bytes) }
    }
}

$owner = $settings.GITHUB_OWNER; $repo = $settings.GITHUB_REPO; $branch = $settings.GITHUB_BRANCH
$headers = @{ Authorization = "Bearer $($settings.GITHUB_TOKEN)"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
$ref = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$owner/$repo/git/ref/heads/$branch"
$head = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$owner/$repo/git/commits/$($ref.object.sha)"
$remote = @{}
if ($head.tree.sha -ne '4b825dc642cb6eb9a060e54bf8d69288fbee4904') {
    (Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$owner/$repo/git/trees/$($head.tree.sha)?recursive=1").tree |
        Where-Object type -eq 'blob' | ForEach-Object { $remote[$_.path] = $_.sha }
}

$changes = @()
foreach ($path in $local.Keys) {
    if ($remote[$path] -ne $local[$path].sha) { $changes += @{ kind = 'add'; path = $path; contents = $local[$path].contents } }
}
foreach ($path in $remote.Keys) {
    if (-not $local.ContainsKey($path)) { $changes += @{ kind = 'delete'; path = $path } }
}
if ($changes.Count -eq 0) {
    [pscustomobject]@{ repository = "$owner/$repo"; branch = $branch; status = 'already_current'; source_files = $local.Count } | ConvertTo-Json -Compress
    exit 0
}

$mutation = 'mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }'
$commits = 0
for ($offset = 0; $offset -lt $changes.Count; $offset += $BatchSize) {
    $batch = @($changes | Select-Object -Skip $offset -First $BatchSize)
    $additions = @($batch | Where-Object kind -eq 'add' | ForEach-Object { @{ path = $_.path; contents = $_.contents } })
    $deletions = @($batch | Where-Object kind -eq 'delete' | ForEach-Object { @{ path = $_.path } })
    $latest = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$owner/$repo/git/ref/heads/$branch"
    $input = @{ branch = @{ repositoryNameWithOwner = "$owner/$repo"; branchName = $branch }; message = @{ headline = 'chore: sync current project source' }; expectedHeadOid = $latest.object.sha; fileChanges = @{ additions = $additions; deletions = $deletions } }
    if ($PSCmdlet.ShouldProcess("$owner/${repo}:$branch", "sync $($batch.Count) source files")) {
        Invoke-GraphQl $headers $mutation @{ input = $input } | Out-Null
        $commits++
    }
}

[pscustomobject]@{ repository = "$owner/$repo"; branch = $branch; status = 'synced'; source_files = $local.Count; additions_or_updates = @($changes | Where-Object kind -eq 'add').Count; deletions = @($changes | Where-Object kind -eq 'delete').Count; commits = $commits } | ConvertTo-Json -Compress
