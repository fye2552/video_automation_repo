param(
  [string]$Root = 'E:\n8n-video-gemini',
  [string]$GithubUrl = 'https://github.com/fye2552/video_automation_repo/tree/main/products/grout_cleaner_kit_with_stand-up_brush_clean_tile_floors_without_kneeling_profess'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Report = Join-Path $Root 'validation_report.txt'
$LogDir = Join-Path $Root ('test_logs\full_validation_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$Lines = New-Object System.Collections.Generic.List[string]
$FailureLayer = 'none'

function Log([string]$Text) { $Lines.Add($Text); Write-Host $Text }
function Save-Report { $Lines | Set-Content -LiteralPath $Report -Encoding UTF8 }
function Tail([string]$Path, [int]$Count = 25) {
  if (Test-Path -LiteralPath $Path) { return @(Get-Content -LiteralPath $Path -Tail $Count) }
  return @()
}
function Load-Env([string]$Path) {
  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -match '^\s*([^#=\s]+)\s*=\s*(.*)$') {
      $key = $matches[1]; $value = $matches[2].Trim()
      if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[$value.Length-1] -eq '"') -or ($value[0] -eq "'" -and $value[$value.Length-1] -eq "'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
  }
}
function Wait-Web([int]$Seconds) {
  $end = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $end) {
    try { if ((Invoke-WebRequest 'http://127.0.0.1:5678/' -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200) { return $true } } catch {}
    Start-Sleep 2
  }
  return $false
}
function Post-Json([string]$Url, [hashtable]$Body, [int]$Timeout) {
  try {
    $r = Invoke-WebRequest $Url -Method Post -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 20) -UseBasicParsing -TimeoutSec $Timeout
    $j = $null; try { $j = $r.Content | ConvertFrom-Json } catch {}
    return [pscustomobject]@{ Code=[int]$r.StatusCode; Json=$j; Raw=$r.Content; Error='' }
  } catch {
    return [pscustomobject]@{ Code=0; Json=$null; Raw=''; Error=$_.Exception.Message }
  }
}
function Failure-From([string]$Text) {
  if ($Text -match 'OpenAI|chat/completions|rate limit|socket hang up') { return 'OpenAI' }
  if ($Text -match 'GitHub|sha mismatch|api.github.com') { return 'GitHub' }
  if ($Text -match 'Moyin Create|/api/v1/videos|missing task id') { return 'Moyin create' }
  return 'n8n webhook'
}

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
Log 'FULL VALIDATION REPORT'
Log ('Started: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Log "Project: $Root"
Log "Logs: $LogDir"

# STATIC_AND_RUNTIME
try {
  Load-Env (Join-Path $Root '.env')
  if (-not $env:N8N_LOCAL_JOBS_DIR) { $env:N8N_LOCAL_JOBS_DIR = Join-Path $Root 'video_jobs' }
  if (-not $env:N8N_LOCAL_OUTPUT_DIR) { $env:N8N_LOCAL_OUTPUT_DIR = Join-Path $Root 'video_output' }
  if (-not $env:N8N_LOCAL_PRODUCTS_DIR) { $env:N8N_LOCAL_PRODUCTS_DIR = Join-Path $Root 'local_products' }
  $env:N8N_PORT='5678'; $env:WEBHOOK_URL='http://127.0.0.1:5678/'
  $env:NODE_FUNCTION_ALLOW_BUILTIN='*'; $env:N8N_BLOCK_ENV_ACCESS_IN_NODE='false'

  $mainPath = Join-Path $Root 'workflows\main_generate_video.workflow.json'
  $mainRaw = Get-Content -LiteralPath $mainPath -Raw -Encoding UTF8
  $main = $mainRaw | ConvertFrom-Json
  Get-Content -LiteralPath (Join-Path $Root 'workflows\local_product_upload_to_github.workflow.json') -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
  $norm = ($main.nodes | Where-Object name -eq 'Normalize Input').parameters.jsCode
  $bm = ($main.nodes | Where-Object name -eq 'Build Moyin Jobs').parameters.jsCode
  $bl = ($main.nodes | Where-Object name -eq 'Build Local Worker Job').parameters.jsCode
  $resp = ($main.nodes | Where-Object name -eq 'Build Submitted Response').parameters.jsCode
  $start = Get-Content -LiteralPath (Join-Path $Root 'start_and_run_all_skill_c.bat') -Raw
  $submit = Get-Content -LiteralPath (Join-Path $Root 'submit_all_products.ps1') -Raw
  $watch = Get-Content -LiteralPath (Join-Path $Root 'workers\worker_watcher.py') -Raw
  $worker = Get-Content -LiteralPath (Join-Path $Root 'workers\moyin_worker.py') -Raw
  $Static = [ordered]@{
    workflow_json = $true
    create_videos = $norm.Contains('"path":"/videos"')
    query_videos = $norm.Contains('"path_template":"/videos/{task_id}"')
    old_paths_absent = -not ($mainRaw -match '/runwayml/v1/image_to_video|/v1/video/query\?id=\{task_id\}|image_to_video')
    one_job_write = (([regex]::Matches($mainRaw,'fs\.writeFileSync')).Count -eq 1) -and -not ($resp -match 'writeFileSync')
    timeout_900 = $bl.Contains('Number($env.MOYIN_TIMEOUT_SECONDS || 900)')
    poll_8 = $bl.Contains('Number($env.MOYIN_POLL_INTERVAL_SECONDS || 8)')
    moyin_dedup = ($bm -match 'scene_id') -and ($bm -match 'output_file') -and ($bm -match 'duplicate')
    local_dedup = ($bl -match 'scene_id') -and ($bl -match 'output_file') -and ($bl -match 'duplicate')
    builtin_all = $start.Contains('set NODE_FUNCTION_ALLOW_BUILTIN=*')
    external_chain = $submit.Contains('local-product-upload-github') -and $submit.Contains('auto_start_main = $false') -and $submit.Contains('main-generate-video')
    watcher_lock = $watch.Contains('utf-8-sig') -and $watch.Contains('os.close(fd)') -and $watch.Contains('600')
    worker_query = $worker.Contains('/videos/{task_id}') -and $worker.Contains('resultUrls')
    signed_download = $worker.Contains('request = urllib.request.Request(url)')
    query_retry = $worker -match 'SSLEOFError|UNEXPECTED_EOF|ConnectionResetError|TimeoutError'
  }
  $StaticPass = -not ($Static.Values -contains $false)
  Log ("1. STATIC_CHECK " + $(if($StaticPass){'PASS'}else{'FAIL'}))
  foreach ($e in $Static.GetEnumerator()) { Log "   $($e.Key)=$($e.Value)" }

  $old = @(Get-CimInstance Win32_Process | Where-Object { ($_.Name -match 'node|cmd|python') -and ($_.CommandLine -match 'node_modules\\n8n\\bin\\n8n|n8n\.cmd start|worker_watcher\.py|moyin_worker\.py') })
  foreach ($p in $old) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
  Start-Sleep 3

  $syncSpecs = @(
    @{ Source=(Join-Path $Root 'workflows\main_generate_video.workflow.json'); Id='hqj0P1dbvqyPEh18' }
  )
  foreach ($spec in $syncSpecs) {
    $workflow = Get-Content -LiteralPath $spec.Source -Raw -Encoding UTF8 | ConvertFrom-Json
    $workflow | Add-Member -NotePropertyName id -NotePropertyValue $spec.Id -Force
    $workflow.active = $false
    $importPath = Join-Path $LogDir ($spec.Id + '.import.json')
    [IO.File]::WriteAllText($importPath, ($workflow | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
    & n8n.cmd import:workflow --input=$importPath | Out-File -FilePath (Join-Path $LogDir 'workflow_sync.log') -Append -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw "workflow import failed: $($spec.Source)" }
    & n8n.cmd publish:workflow --id=$($spec.Id) | Out-File -FilePath (Join-Path $LogDir 'workflow_sync.log') -Append -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw "workflow publish failed: $($spec.Id)" }
  }
  $inbox = Join-Path $env:N8N_LOCAL_JOBS_DIR 'inbox'
  New-Item -ItemType Directory -Path $inbox -Force | Out-Null
  if (-not ([IO.Path]::GetFullPath($inbox).StartsWith([IO.Path]::GetFullPath($env:N8N_LOCAL_JOBS_DIR),[StringComparison]::OrdinalIgnoreCase))) { throw 'Unsafe inbox path' }
  Get-ChildItem -LiteralPath $inbox -File | Where-Object { $_.Name -ne '.gitkeep' -and ($_.Name -like '*.json' -or $_.Name -like '*.lock') } | Remove-Item -Force

  $n8nOut=Join-Path $LogDir 'n8n.stdout.log'; $n8nErr=Join-Path $LogDir 'n8n.stderr.log'
  $np=Start-Process cmd.exe -ArgumentList @('/d','/c','n8n.cmd start') -WorkingDirectory $Root -RedirectStandardOutput $n8nOut -RedirectStandardError $n8nErr -WindowStyle Hidden -PassThru
  $N8nOk=Wait-Web 120
  Log ("2. N8N_START " + $(if($N8nOk){'PASS'}else{'FAIL'}) + " pid=$($np.Id)")
  if(-not $N8nOk){$FailureLayer='n8n webhook';throw 'n8n startup timeout'}
  if($N8nOk){Start-Sleep -Seconds 10}
  $url='http://127.0.0.1:5678/webhook/main-generate-video'
  $body=@{github_url=$GithubUrl;active_skill='skill_c';custom_skill_path='';generate_count=1;dry_run=$true}
  $dry=Post-Json $url $body 1200; $dry.Raw|Set-Content (Join-Path $LogDir 'dry.json') -Encoding UTF8
  $DryOk=$dry.Code -eq 200
  Log ("3. MAIN_DRY_RUN_HTTP_200 " + $(if($DryOk){'PASS'}else{'FAIL'}) + " status=$($dry.Code)")
  if(-not $DryOk){$FailureLayer=Failure-From($dry.Error+' '+$dry.Raw+' '+((Tail $n8nOut 80)-join ' '));throw 'dry run failed'}

  $body.dry_run=$false
  $real=Post-Json $url $body 1800; $real.Raw|Set-Content (Join-Path $LogDir 'real.json') -Encoding UTF8
  $Submitted=$real.Code -eq 200 -and $real.Json.status -eq 'submitted'
  Log ("4. MAIN_REAL_SUBMITTED " + $(if($Submitted){'PASS'}else{'FAIL'}) + " http=$($real.Code) status=$($real.Json.status)")
  if(-not $Submitted){$FailureLayer=Failure-From($real.Error+' '+$real.Raw+' '+((Tail $n8nOut 100)-join ' '));throw 'real run failed'}

  $jobId=[string]$real.Json.job_id; $jobFile=[string]$real.Json.job_file
  if(-not $jobFile){$jobFile=Join-Path $inbox ($jobId+'.json')}
  $InboxOk=Test-Path -LiteralPath $jobFile
  Log ("5. INBOX_JOB_JSON " + $(if($InboxOk){'PASS'}else{'FAIL'}) + " path=$jobFile")
  if(-not $InboxOk){$FailureLayer='n8n webhook';throw 'job file missing'}
  $job=Get-Content -LiteralPath $jobFile -Raw -Encoding UTF8|ConvertFrom-Json; $scenes=@($job.scenes)
  $SceneOk=$scenes.Count -eq 2
  $TaskOk=@($scenes|Where-Object{-not $_.moyin_task_id}).Count -eq 0
  $outs=@($scenes|ForEach-Object{$_.output_file});$UniqueOk=@($outs|Sort-Object -Unique).Count -eq $outs.Count
  Log ("6. JOB_SCENES_COUNT " + $(if($SceneOk){'PASS'}else{'FAIL'}) + " count=$($scenes.Count)")
  Log ("7. SCENE_TASK_IDS " + $(if($TaskOk){'PASS'}else{'FAIL'}))
  Log ("8. OUTPUT_FILE_UNIQUE " + $(if($UniqueOk){'PASS'}else{'FAIL'}))
  foreach($s in $scenes){Log "   scene=$($s.scene_id) task_id=$($s.moyin_task_id) output=$($s.output_file)"}

  $watchOut=Join-Path $LogDir 'watcher.stdout.log';$watchErr=Join-Path $LogDir 'watcher.stderr.log'
  $wa = @("`"$(Join-Path $Root 'workers\worker_watcher.py')`"", '--jobs-dir', "`"$env:N8N_LOCAL_JOBS_DIR`"", '--worker', "`"$(Join-Path $Root 'workers\moyin_worker.py')`"", '--max-parallel', '1', '--scan-interval-seconds', '5', '--idle-timeout-seconds', '30')
  $wp=Start-Process python -ArgumentList $wa -WorkingDirectory $Root -RedirectStandardOutput $watchOut -RedirectStandardError $watchErr -WindowStyle Hidden -PassThru
  $jobDir=Join-Path $env:N8N_LOCAL_JOBS_DIR $jobId;$end=(Get-Date).AddSeconds(90)
  while((Get-Date)-lt $end -and -not(Test-Path -LiteralPath (Join-Path $jobDir 'job.json'))){Start-Sleep 2}
  $Claimed=Test-Path -LiteralPath (Join-Path $jobDir 'job.json')
  Log ("9. WATCHER_CLAIMED_JOB " + $(if($Claimed){'PASS'}else{'FAIL'}) + " pid=$($wp.Id)")
  if(-not $Claimed){$FailureLayer='worker_watcher lock';throw 'watcher claim timeout'}
  $statusPath=Join-Path $jobDir 'status.json';$workerLog=Join-Path $jobDir 'worker.log';$end=(Get-Date).AddSeconds(90)
  while((Get-Date)-lt $end -and (-not(Test-Path $statusPath)-or -not(Test-Path $workerLog))){Start-Sleep 2}
  $StatusFile=Test-Path $statusPath;$WorkerFile=Test-Path $workerLog
  Log ("10. STATUS_AND_WORKER_LOG " + $(if($StatusFile -and $WorkerFile){'PASS'}else{'FAIL'}) + " status_json=$StatusFile worker_log=$WorkerFile")

  $limit=900;if($env:MOYIN_TIMEOUT_SECONDS -match '^\d+$'){$limit=[int]$env:MOYIN_TIMEOUT_SECONDS}
  $end=(Get-Date).AddSeconds($limit+180);$terminal='timeout';$status=$null
  while((Get-Date)-lt $end){if(Test-Path $statusPath){try{$status=Get-Content $statusPath -Raw -Encoding UTF8|ConvertFrom-Json;if($status.status -in @('completed','failed','timeout')){$terminal=$status.status;break}}catch{}};Start-Sleep 5}
  Log "11. MOYIN_STATUS $terminal"
  $mp4=@();if(Test-Path $job.output_dir){$mp4=@(Get-ChildItem -LiteralPath $job.output_dir -File -Filter '*.mp4')}
  Log "12. MP4_COUNT $($mp4.Count) output_dir=$($job.output_dir)";foreach($f in $mp4){Log "   mp4=$($f.FullName) bytes=$($f.Length)"}
  if($terminal -eq 'completed' -and $mp4.Count -ge 2){$FailureLayer='none'}elseif($terminal -eq 'timeout'){$FailureLayer='Moyin query'}elseif($terminal -eq 'failed'){$t=$status|ConvertTo-Json -Depth 20 -Compress;if($t-match'download|video_url'){$FailureLayer='moyin_worker download'}else{$FailureLayer='Moyin query'}}
  try{$wp.WaitForExit(90000)|Out-Null}catch{}
  Log "13. FAILURE_LAYER $FailureLayer"
  Log 'REAL LOG SUMMARY'
  foreach($l in Tail $n8nOut 15){Log "   n8n> $l"};foreach($l in Tail $watchOut 20){Log "   watcher> $l"};foreach($l in Tail $workerLog 20){Log "   worker> $l"}
  $Overall=$StaticPass -and $N8nOk -and $DryOk -and $Submitted -and $InboxOk -and $SceneOk -and $TaskOk -and $UniqueOk -and $Claimed -and $StatusFile -and $WorkerFile -and ($terminal -eq 'completed') -and ($mp4.Count -ge 2)
  Log ("OVERALL_RESULT " + $(if($Overall){'PASS'}else{'FAIL'}))
} catch {
  if($FailureLayer -eq 'none'){$FailureLayer='n8n webhook'}
  Log "ERROR: $($_.Exception.Message)";Log "13. FAILURE_LAYER $FailureLayer";Log 'OVERALL_RESULT FAIL'
  foreach($l in Tail (Join-Path $LogDir 'n8n.stdout.log') 40){Log "   n8n> $l"}
} finally {
  Log ('Finished: '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'));Save-Report;Write-Host "Report: $Report"
}



