param(
  [Parameter(Mandatory=$true)][string]$ProductId,
  [string]$Skill = "skill_c",
  [string]$CustomSkillPath = "",
  [int]$GenerateCount = 1,
  [string]$N8nUrl = "http://localhost:5678"
)
$body = @{
  product_id = $ProductId
  active_skill = $Skill
  custom_skill_path = $CustomSkillPath
  generate_count = $GenerateCount
  dry_run = $false
  auto_start_main = $true
} | ConvertTo-Json
Invoke-RestMethod -Uri "$N8nUrl/webhook/local-product-upload-github" -Method Post -ContentType "application/json" -Body $body
