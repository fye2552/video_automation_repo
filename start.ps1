Set-Location "E:\n8n-video-gemini"

Get-Content ".env" | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith("#")) { return }

  $parts = $line -split "=", 2
  if ($parts.Count -eq 2) {
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

New-Item -ItemType Directory -Force "E:\n8n-video-gemini\local_products" | Out-Null
New-Item -ItemType Directory -Force "E:\n8n-video-gemini\video_jobs" | Out-Null
New-Item -ItemType Directory -Force "E:\n8n-video-gemini\video_jobs\inbox" | Out-Null
New-Item -ItemType Directory -Force "E:\n8n-video-gemini\video_output" | Out-Null
New-Item -ItemType Directory -Force "E:\n8n-video-gemini\workers" | Out-Null

Write-Host "NODE_FUNCTION_ALLOW_BUILTIN=$env:NODE_FUNCTION_ALLOW_BUILTIN"
Write-Host "OPENAI_CHAT_COMPLETIONS_URL=$env:OPENAI_CHAT_COMPLETIONS_URL"
Write-Host "OPENAI_MODEL=$env:OPENAI_MODEL"

n8n start