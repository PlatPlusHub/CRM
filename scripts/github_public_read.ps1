# Anonymous transport and schema only. Certification and watcher judgments stay with their callers.
# No gh, credential discovery, cookies, default credentials, retries, cache or verdicts.
function Invoke-OrvionPublicHttp([uri]$Uri, [int]$TimeoutSeconds = 20) {
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.UseDefaultCredentials = $false
    $handler.UseCookies = $false
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
    try {
        $client.DefaultRequestHeaders.Add('User-Agent', 'ORVION-public-reader')
        $client.DefaultRequestHeaders.Add('Accept', 'application/vnd.github+json')
        $client.DefaultRequestHeaders.Add('X-GitHub-Api-Version', '2026-03-10')
        $response = $client.GetAsync($Uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancel.Token).GetAwaiter().GetResult()
        try {
            # Bound memory, including an error body. Do not echo response bodies or redirect URLs.
            if ($response.Content.Headers.ContentLength -gt 16MB) { throw 'PUBLIC_READ:BODY_LIMIT' }
            $stream = $response.Content.ReadAsStream()
            $buffer = [byte[]]::new(8192); $body = [IO.MemoryStream]::new()
            try {
                while (($n = $stream.ReadAsync($buffer, 0, $buffer.Length, $cancel.Token).GetAwaiter().GetResult()) -gt 0) {
                    if ($body.Length + $n -gt 16MB) { throw 'PUBLIC_READ:BODY_LIMIT' }
                    $body.Write($buffer, 0, $n)
                }
                $text = [Text.UTF8Encoding]::new($false, $true).GetString($body.ToArray())
            } finally { $body.Dispose(); $stream.Dispose() }
            $headers = @{}
            foreach ($h in $response.Headers) { $headers[$h.Key] = $h.Value -join ',' }
            [pscustomobject]@{ Status = [int]$response.StatusCode; Headers = $headers; ContentType = "$($response.Content.Headers.ContentType)"; Body = $text }
        } finally { $response.Dispose() }
    } catch {
        if ($_.Exception.Message -like 'PUBLIC_READ:*') { throw }
        throw 'PUBLIC_READ:TRANSPORT_UNREADABLE'
    } finally { $cancel.Dispose(); $client.Dispose() }
}
function Read-OrvionPublicJson([uri]$Uri, [switch]$WithHeaders) {
    $r = Invoke-OrvionPublicHttp $Uri
    if ($r.Status -ne 200) {
        $retry = 0L
        if ($r.Status -in 403,429) {
            $v = 0L
            if ([long]::TryParse("$($r.Headers['Retry-After'])", [ref]$v)) { $retry = [Math]::Max(0,$v) }
            $reset = 0L
            if ($r.Headers['X-RateLimit-Remaining'] -eq '0' -and [long]::TryParse("$($r.Headers['X-RateLimit-Reset'])", [ref]$reset)) {
                $retry = [Math]::Max($retry, $reset - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            }
        }
        $e = [InvalidOperationException]::new("PUBLIC_READ:HTTP_$($r.Status):retry_after=$retry")
        $e.Data['RetryAfterSeconds'] = $retry
        throw $e
    }
    if ($r.ContentType -notmatch '^application/(json|[a-z0-9.+-]+\+json)(;|$)') { throw 'PUBLIC_READ:CONTENT_TYPE' }
    try { $j = ConvertFrom-Json -InputObject $r.Body -AsHashtable -DateKind String -ErrorAction Stop } catch { throw 'PUBLIC_READ:MALFORMED_JSON' }
    if ($j -isnot [Collections.IDictionary]) { throw 'PUBLIC_READ:OBJECT_REQUIRED' }
    if($WithHeaders){[pscustomobject]@{Data=$j;Headers=$r.Headers}}else{$j}
}
function Assert-OrvionPublicFields($Row, [string[]]$Fields) {
    if ($Row -isnot [Collections.IDictionary]) { throw 'PUBLIC_READ:ROW_REQUIRED' }
    foreach ($f in $Fields) { if (-not $Row.Contains($f)) { throw "PUBLIC_READ:MISSING_FIELD:$f" } }
}
function Assert-OrvionPublicRun($r, [string]$Repo) {
    Assert-OrvionPublicFields $r @('id','workflow_id','name','path','head_sha','head_branch','event','run_attempt','status','conclusion','created_at','repository')
    foreach ($f in 'id','workflow_id','run_attempt') { if ($r[$f] -isnot [long] -and $r[$f] -isnot [int] -or $r[$f] -lt 1) { throw "PUBLIC_READ:INVALID_FIELD:$f" } }
    foreach ($f in 'name','path','head_branch','event','status','created_at') { if ($r[$f] -isnot [string] -or -not $r[$f].Trim()) { throw "PUBLIC_READ:INVALID_FIELD:$f" } }
    if ($r.head_sha -isnot [string] -or $r.head_sha -cnotmatch '^[0-9a-f]{40}$' -or $r.repository.full_name -isnot [string] -or $r.repository.full_name -ine $Repo) { throw 'PUBLIC_READ:RUN_IDENTITY' }
    $d = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($r.created_at,[ref]$d)) { throw 'PUBLIC_READ:CREATED_AT' }
    if ($r.status -eq 'completed') { if ($r.conclusion -isnot [string] -or -not $r.conclusion) { throw 'PUBLIC_READ:CONCLUSION' } }
    elseif ($null -ne $r.conclusion -and $r.conclusion -isnot [string]) { throw 'PUBLIC_READ:CONCLUSION' }
}
function Get-OrvionPublicCollection([string]$Path, [string]$Field, [int]$PageSize = 100) {
    if ($PageSize -lt 1 -or $PageSize -gt 100) { throw 'PUBLIC_READ:PAGE_SIZE' }
    $rows = [Collections.Generic.List[object]]::new(); $seen = @{}; $total = -1
    $join = if ($Path.Contains('?')) { '&' } else { '?' }
    # No Link URLs are followed. Fixed origin, monotonically constructed page numbers, hard result cap.
    for ($page = 1; $page -le [Math]::Ceiling(1000.0/$PageSize)+1; $page++) {
        $read = Read-OrvionPublicJson ([uri]("https://api.github.com/$Path${join}per_page=$PageSize&page=$page")) -WithHeaders
        $j = $read.Data
        Assert-OrvionPublicFields $j @('total_count',$Field)
        if (($j.total_count -isnot [int] -and $j.total_count -isnot [long]) -or $j.total_count -lt 0 -or $j.total_count -ge 1000) { throw 'PUBLIC_READ:RESULT_BOUND' }
        if ($total -eq -1) { $total = $j.total_count } elseif ($total -ne $j.total_count) { throw 'PUBLIC_READ:POPULATION_CHANGED' }
        if ($j[$Field] -isnot [array]) { throw 'PUBLIC_READ:ARRAY_REQUIRED' }
        $batch = @($j[$Field]); $expected = [Math]::Min($PageSize,$total-$rows.Count)
        if ($batch.Count -ne $expected) { throw 'PUBLIC_READ:INCOMPLETE_PAGE' }
        foreach ($r in $batch) {
            Assert-OrvionPublicFields $r @('id')
            if ($seen.ContainsKey("$($r.id)")) { throw 'PUBLIC_READ:DUPLICATE_ROW' }
            $seen["$($r.id)"] = $true; $rows.Add($r)
        }
        if ($rows.Count -eq $total) {
            if ("$($read.Headers.Link)" -match 'rel="?next\b') { throw 'PUBLIC_READ:CONTRADICTORY_NEXT_PAGE' }
            return ,$rows.ToArray()
        }
    }
    throw 'PUBLIC_READ:INCOMPLETE_POPULATION'
}
function Get-OrvionPublicRepo([string]$Root) {
    $urls = @(git -C $Root remote get-url --all origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or $urls.Count -ne 1 -or $urls[0] -notmatch '^https://(?:[A-Za-z0-9-]+@)?github\.com/(?<owner>[A-Za-z0-9-]+)/(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?$') { throw 'PUBLIC_READ:ORIGIN' }
    "$($Matches.owner)/$($Matches.repo)"
}
function Get-OrvionPublicRuns([string]$Repo, [string]$Sha = '', [string]$Branch = '', [string]$Event = '', [string]$WorkflowPath = '') {
    if ($Repo -notmatch '^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$') { throw 'PUBLIC_READ:REPOSITORY' }
    if ($Sha -and $Sha -cnotmatch '^[0-9a-f]{40}$') { throw 'PUBLIC_READ:SHA' }
    $q = @()
    foreach ($pair in @(@('head_sha',$Sha),@('branch',$Branch),@('event',$Event))) { if ($pair[1]) { $q += "$($pair[0])=$([uri]::EscapeDataString($pair[1]))" } }
    $path = "repos/$Repo/actions/runs"
    if ($WorkflowPath) {
        if ($WorkflowPath -notmatch '^\.github/workflows/([A-Za-z0-9_.-]+\.ya?ml)$') { throw 'PUBLIC_READ:WORKFLOW_PATH' }
        $path = "repos/$Repo/actions/workflows/$([uri]::EscapeDataString($Matches[1]))/runs"
    }
    if ($q.Count) { $path += '?' + ($q -join '&') }
    $rows = Get-OrvionPublicCollection $path 'workflow_runs'
    foreach ($r in $rows) { Assert-OrvionPublicRun $r $Repo }
    foreach ($r in $rows) {
        # Current attempt is the list endpoint's row, never a search through historical attempts.
        [pscustomobject]@{ databaseId=$r.id; workflowName=$r.name; name=$r.name; workflowId=$r.workflow_id; path=$r.path; headSha=$r.head_sha; headBranch=$r.head_branch; event=$r.event; attempt=$r.run_attempt; status=$r.status; conclusion=$r.conclusion; createdAt=$r.created_at }
    }
}
function Get-OrvionPublicAttempt([string]$Repo, [long]$RunId, [int]$Attempt) {
    if ($Repo -notmatch '^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$' -or $RunId -lt 1 -or $Attempt -lt 1) { throw 'PUBLIC_READ:ATTEMPT_ID' }
    $r = Read-OrvionPublicJson ([uri]"https://api.github.com/repos/$Repo/actions/runs/$RunId/attempts/$Attempt")
    Assert-OrvionPublicRun $r $Repo
    if ($r.id -ne $RunId -or $r.run_attempt -ne $Attempt) { throw 'PUBLIC_READ:ATTEMPT_MISMATCH' }
    $r
}
function Get-OrvionPublicJobs([string]$Repo, [long]$RunId, [int]$Attempt) {
    if ($Repo -notmatch '^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$' -or $RunId -lt 1 -or $Attempt -lt 1) { throw 'PUBLIC_READ:ATTEMPT_ID' }
    $rows = Get-OrvionPublicCollection "repos/$Repo/actions/runs/$RunId/attempts/$Attempt/jobs" 'jobs'
    foreach ($r in $rows) {
        Assert-OrvionPublicFields $r @('id','run_id','run_attempt','name','status','conclusion','steps')
        foreach($f in 'id','run_id','run_attempt'){if(($r[$f] -isnot [long] -and $r[$f] -isnot [int]) -or $r[$f]-lt1){throw 'PUBLIC_READ:JOB_IDENTITY'}}
        if ($r.run_id -ne $RunId -or $r.run_attempt -ne $Attempt -or $r.steps -isnot [array]) { throw 'PUBLIC_READ:JOB_IDENTITY' }
        foreach($item in @($r)+@($r.steps)) {
            Assert-OrvionPublicFields $item @('name','status','conclusion')
            if($item.name -isnot [string] -or -not $item.name.Trim() -or $item.status -isnot [string] -or -not $item.status.Trim()) {throw 'PUBLIC_READ:JOB_FIELD'}
            if($item.status-eq'completed') {if($item.conclusion-isnot[string]-or-not$item.conclusion){throw 'PUBLIC_READ:JOB_CONCLUSION'}}
            elseif($null-ne$item.conclusion-and$item.conclusion-isnot[string]){throw 'PUBLIC_READ:JOB_CONCLUSION'}
        }
        $r
    }
}
function Get-OrvionPublicLog([string]$Repo, [long]$JobId) {
    if ($Repo -notmatch '^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$' -or $JobId -lt 1) { throw 'PUBLIC_READ:JOB_ID' }
    $uri = [uri]"https://api.github.com/repos/$Repo/actions/jobs/$JobId/logs"
    $r = Invoke-OrvionPublicHttp $uri
    if ($r.Status -ne 302) { throw "PUBLIC_READ:LOG_HTTP_$($r.Status)" }
    $location = $null
    if (-not [uri]::TryCreate("$($r.Headers.Location)",[UriKind]::Absolute,[ref]$location) -or $location.Scheme -ne 'https' -or $location.UserInfo -or ($location.Host -notmatch '(^|\.)(blob\.core\.windows\.net|actions\.githubusercontent\.com)$')) { throw 'PUBLIC_READ:LOG_REDIRECT' }
    $log = Invoke-OrvionPublicHttp $location
    if ($log.Status -ne 200 -or $log.ContentType -notmatch '^text/plain(;|$)') { throw 'PUBLIC_READ:LOG_UNREADABLE' }
    $log.Body -split '\r?\n'
}
function Test-OrvionPublicGithub([string]$Root) {
    $repo = Get-OrvionPublicRepo $Root
    $j = Read-OrvionPublicJson ([uri]"https://api.github.com/repos/$repo")
    if ($j.full_name -ine $repo -or $j.private -isnot [bool] -or $j.private) { throw 'PUBLIC_READ:PUBLIC_REPOSITORY_REQUIRED' }
    $null = Get-OrvionPublicRuns $repo -Sha ((git -C $Root rev-parse HEAD).Trim())
    if ($LASTEXITCODE -ne 0) { throw 'PUBLIC_READ:HEAD' }
    # A fresh process outside any repository excludes local/global/system credential and HTTP config.
    $info=[Diagnostics.ProcessStartInfo]::new((Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source)
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.WorkingDirectory=[IO.Path]::GetTempPath()
    foreach($key in @($info.Environment.Keys)) { if($key -match '^(GIT_CONFIG|GIT_DIR$|GIT_WORK_TREE$|GIT_ASKPASS$|SSH_ASKPASS$|GIT_TRACE)') { $null=$info.Environment.Remove($key) } }
    $info.Environment['GIT_CONFIG_GLOBAL']=if($IsWindows){'NUL'}else{'/dev/null'}
    $info.Environment['GIT_CONFIG_NOSYSTEM']='1'; $info.Environment['GIT_TERMINAL_PROMPT']='0'
    foreach($arg in @('-c','credential.helper=','-c','core.askPass=','ls-remote',"https://github.com/$repo.git",'HEAD')){$info.ArgumentList.Add($arg)}
    $proc=[Diagnostics.Process]::new(); $proc.StartInfo=$info
    try {
        $null=$proc.Start(); $out=$proc.StandardOutput.ReadToEndAsync(); $err=$proc.StandardError.ReadToEndAsync()
        if(-not $proc.WaitForExit(20000)){$proc.Kill($true);throw 'PUBLIC_READ:GIT_TIMEOUT'}
        if($proc.ExitCode-ne0-or$out.GetAwaiter().GetResult()-notmatch'^[0-9a-f]{40}\s+HEAD') { throw 'PUBLIC_READ:GIT_UNREADABLE' }
    } finally {$proc.Dispose()}
}

# ---- the shared anonymous budget ------------------------------------------------------------------------
# GitHub allows 60 anonymous requests an hour per IP address, shared by every reader on this machine and by anything
# else behind the same address. Two watchers polling every 30 s spent it in about 15 minutes and stopped while CI was
# green, and a -Certify run right after then read nothing (2026-10-20). GitHub's own counter is the truth and
# `/rate_limit` reads it without spending (measured: `used` unchanged across the call). Watchers take turns through one
# small machine-local ledger holding the next free poll time, so N watchers split what is left instead of each spending
# all of it, and they never spend the last $script:OrvionPublicReserve requests, which stay for -Certify.
$script:OrvionPublicReserve = 10
$script:OrvionPublicLedger = if ($env:ORVION_PUBLIC_BUDGET) { $env:ORVION_PUBLIC_BUDGET } else { Join-Path ([IO.Path]::GetTempPath()) 'orvion-github-public-budget.json' }
function Get-OrvionPublicBudget {
    $j = Read-OrvionPublicJson ([uri]'https://api.github.com/rate_limit')
    $c = $j.resources.core
    if ($c -isnot [Collections.IDictionary] -or $c.remaining -isnot [long] -and $c.remaining -isnot [int] -or $c.reset -isnot [long] -and $c.reset -isnot [int]) { throw 'PUBLIC_READ:RATE_LIMIT_SHAPE' }
    [pscustomobject]@{ Remaining = [long]$c.remaining; Reset = [long]$c.reset }
}
# Blocks until this caller may spend one request. Emits one PAUSED line before any wait for the reset (pipe it to the log).
# Throws PUBLIC_READ:BUDGET_EXHAUSTED when the reset is further away than -MaxWaitSeconds.
function Wait-OrvionPublicSlot([int]$MinSeconds = 60, [int]$MaxWaitSeconds = 3600) {
    while ($true) {
        $lock = $null
        for ($i = 0; -not $lock; $i++) {
            try { $lock = [IO.File]::Open("$script:OrvionPublicLedger.lock", 'OpenOrCreate', 'ReadWrite', 'None') }
            catch { if ($i -ge 300) { throw 'PUBLIC_READ:BUDGET_LOCK' }; Start-Sleep -Milliseconds 100 }
        }
        try {
            $next = 0L
            if (Test-Path -LiteralPath $script:OrvionPublicLedger) { [void][long]::TryParse(([IO.File]::ReadAllText($script:OrvionPublicLedger)).Trim(), [ref]$next) }
            $b = Get-OrvionPublicBudget
            $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()   # milliseconds: whole seconds let two turns land 1.1 s apart
            $spendable = $b.Remaining - $script:OrvionPublicReserve
            if ($spendable -le 0) { $wait = [Math]::Max(1000, $b.Reset * 1000 - $now + 1000) }
            else {
                $spacing = [long][Math]::Max($MinSeconds * 1000, [Math]::Ceiling([Math]::Max(1000, $b.Reset * 1000 - $now) / $spendable))
                $slot = [Math]::Max($now, $next)
                [IO.File]::WriteAllText($script:OrvionPublicLedger, "$($slot + $spacing)")
                $wait = $slot - $now
            }
        } finally { $lock.Dispose() }
        if ($spendable -gt 0) { if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }; return }
        $waitSeconds = [long][Math]::Ceiling($wait / 1000)
        if ($waitSeconds -gt $MaxWaitSeconds) { $e = [InvalidOperationException]::new("PUBLIC_READ:BUDGET_EXHAUSTED:retry_after=$waitSeconds"); $e.Data['RetryAfterSeconds'] = $waitSeconds; throw $e }
        "PAUSED: the anonymous GitHub budget is down to its Certify reserve ($($b.Remaining) left); resuming after the reset at $([DateTimeOffset]::FromUnixTimeSeconds($b.Reset).UtcDateTime.ToString('HH:mm')) UTC"
        Start-Sleep -Milliseconds $wait
    }
}
