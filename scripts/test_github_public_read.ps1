# Focused transport proof. Local cases use real HTTP over a disposable loopback server;
# only the fixed API origin is replaced in a temporary copy, never in production code.
param([switch]$Live)
$ErrorActionPreference = 'Stop'
$script:pass=0; $script:fail=0
function Check($Name,[bool]$Ok,$Detail='') { if($Ok){$script:pass++;"PASS $Name"}else{$script:fail++;"FAIL $Name $Detail"} }
function Refuses([scriptblock]$Action,[string]$Pattern) { try { $null=&$Action; return $false } catch { return $_.Exception.Message -match $Pattern } }
$work=Join-Path ([IO.Path]::GetTempPath()) ('ov-read-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[void][IO.Directory]::CreateDirectory($work)
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Net; using System.Net.Sockets; using System.Text;
using System.Threading; using System.Collections.Concurrent;
public sealed class OrvionHttpFixture : IDisposable {
 public ConcurrentQueue<string> Replies=new ConcurrentQueue<string>();
 public ConcurrentQueue<string> Requests=new ConcurrentQueue<string>();
 public TcpListener Listener; public Thread Worker; public int Port; volatile bool Done;
 public OrvionHttpFixture(){Listener=new TcpListener(IPAddress.Loopback,0);Listener.Start();Port=((IPEndPoint)Listener.LocalEndpoint).Port;Worker=new Thread(Loop);Worker.IsBackground=true;Worker.Start();}
 void Loop(){while(!Done){try{using(var c=Listener.AcceptTcpClient()){c.ReceiveTimeout=2000;var s=c.GetStream();var reader=new StreamReader(s,Encoding.ASCII,false,1024,true);string line=reader.ReadLine(),h;var req=line+"\n";while(!String.IsNullOrEmpty(h=reader.ReadLine())) req+=h+"\n";Requests.Enqueue(req);string reply;if(!Replies.TryDequeue(out reply))reply="HTTP/1.1 500 Missing fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";if(reply.StartsWith("BODYDELAY")){reply=reply.Substring(9);int k=reply.IndexOf("\r\n\r\n")+4;byte[] hbytes=Encoding.UTF8.GetBytes(reply.Substring(0,k));s.Write(hbytes,0,hbytes.Length);Thread.Sleep(1800);reply=reply.Substring(k);}byte[] b=Encoding.UTF8.GetBytes(reply);s.Write(b,0,b.Length);}}catch{if(Done)return;}}}
 public void Dispose(){Done=true;Listener.Stop();Worker.Join(3000);}
}
'@
$server=[OrvionHttpFixture]::new()
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'github_public_read.ps1'))
$original=$source.Replace('https://api.github.com',"http://127.0.0.1:$($server.Port)")
$probe=Join-Path $work 'adapter.ps1'; [IO.File]::WriteAllText($probe,$original)
. $probe
function Reply($Body,[int]$Status=200,[string]$Headers='', [string]$Type='application/json') {
    $server.Replies.Enqueue("HTTP/1.1 $Status Fixture`r`nContent-Type: $Type`r`nContent-Length: $([Text.Encoding]::UTF8.GetByteCount($Body))`r`nConnection: close`r`n$Headers`r`n$Body")
}
function Payload($Rows,[int]$Total=-1) { if($Total-lt0){$Total=@($Rows).Count}; ConvertTo-Json -Depth 12 -Compress -InputObject @{total_count=$Total;workflow_runs=@($Rows)} }
function Row([int]$Id=1) { @{id=$Id;workflow_id=3;name='Expected';path='.github/workflows/expected.yml';head_sha=('a'*40);head_branch='main';event='push';run_attempt=2;status='completed';conclusion='success';created_at='2026-10-16T00:00:00Z';repository=@{full_name='owner/repo'}} }
function Runs { @(Get-OrvionPublicRuns 'owner/repo' -Sha ('a'*40) -Branch main -Event push) }
try {
    Reply (Payload @((Row))); $r=Runs
    Check 'HTTP positive normalizes current attempt and exact identity without judgments' ($r.Count-eq1-and$r[0].attempt-eq2-and$r[0].workflowName-eq'Expected'-and$r[0].headSha-eq('a'*40))
    Reply '{"total_count":0,"workflow_runs":[]}'; Check 'empty population remains empty evidence' ((Runs).Count-eq0)
    $rows=@(1..205|ForEach-Object {Row $_})
    Reply (Payload $rows[0..99] 205); Reply (Payload $rows[100..199] 205); Reply (Payload $rows[200..204] 205)
    $r=Runs; Check 'complete three-page 205-row population' ($r.Count-eq205-and$r[-1].databaseId-eq205)
    Reply (Payload $rows[0..99] 205); Reply (Payload $rows[100..103] 205)
    Check 'truncated second page refused without returning partial evidence' (Refuses {Runs} 'INCOMPLETE_PAGE')
    Reply (Payload $rows[0..99] 205); Reply (Payload $rows[0..99] 205)
    Check 'overlapping pages refused' (Refuses {Runs} 'DUPLICATE_ROW')
    Reply (Payload $rows[0..99] 205); Reply (Payload $rows[100..199] 206)
    Check 'moving pagination population refused' (Refuses {Runs} 'POPULATION_CHANGED')
    Reply (Payload @() 1001); Check 'GitHub search result cap fails closed' (Refuses {Runs} 'RESULT_BOUND')
    Reply (Payload @() 1000); Check 'ambiguous exact search cap also fails closed' (Refuses {Runs} 'RESULT_BOUND')
    Reply (Payload @((Row))) 200 "Link: <https://evil.invalid/page>; rel=`"next`"`r`n"
    Check 'next link contradicting total is refused without following it' (Refuses {Runs} 'CONTRADICTORY_NEXT_PAGE')
    Reply '{"total_count":"0","workflow_runs":[]}'; Check 'count type validated' (Refuses {Runs} 'RESULT_BOUND')
    Reply '{"total_count":1,"workflow_runs":{}}'; Check 'array shape validated' (Refuses {Runs} 'ARRAY_REQUIRED')
    foreach($field in @('id','workflow_id','name','path','head_sha','head_branch','event','run_attempt','status','conclusion','created_at','repository')) {
        $r=Row; $r.Remove($field); Reply (Payload @($r)); Check "required run field $field" (Refuses {Runs} "MISSING_FIELD:$field")
    }
    foreach($case in @(@('run_attempt',0),@('id','1'),@('head_sha','short'),@('created_at','invalid'),@('conclusion',$null),@('name',''))) {
        $r=Row; $r[$case[0]]=$case[1]; Reply (Payload @($r)); Check "invalid field $($case[0])" (Refuses {Runs} 'PUBLIC_READ:')
    }
    $r=Row; $r.repository.full_name='other/repo'; Reply (Payload @($r)); Check 'foreign repository refused' (Refuses {Runs} 'RUN_IDENTITY')
    foreach($s in @('success','failure','skipped','neutral','cancelled','timed_out','action_required','future_value')) {
        $r=Row; $r.conclusion=$s; Reply (Payload @($r)); Check "transport preserves literal conclusion $s" ((Runs)[0].conclusion-ceq$s)
    }
    $r=Row; $r.status='in_progress'; $r.conclusion=$null; Reply (Payload @($r)); Check 'pending current attempt is not rewritten as old success' ((Runs)[0].status-eq'in_progress')
    foreach($status in @(401,403,404,429,500,503)) {
        Reply '{"message":"inaccessible"}' $status; Check "real loopback HTTP $status refuses" (Refuses {Runs} "HTTP_$status")
    }
    Reply '{}' 429 "Retry-After: 9`r`n"
    try {Runs; Check '429 structured retry evidence' $false} catch {Check '429 structured retry evidence' ($_.Exception.Data['RetryAfterSeconds']-eq9)}
    $reset=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+120
    Reply '{}' 403 "X-RateLimit-Remaining: 0`r`nX-RateLimit-Reset: $reset`r`n"
    try {Runs; Check 'primary exhaustion reset evidence' $false} catch {Check 'primary exhaustion reset evidence' ($_.Exception.Data['RetryAfterSeconds']-ge115)}
    Reply 'not-json'; Check 'real HTTP malformed JSON' (Refuses {Runs} 'MALFORMED_JSON')
    Reply '[]'; Check 'real HTTP wrong root shape' (Refuses {Runs} 'OBJECT_REQUIRED')
    Reply '<html>login</html>' 200 '' 'text/html'; Check 'real HTTP login HTML refused' (Refuses {Runs} 'CONTENT_TYPE')
    Reply '{}' 302 "Location: https://evil.invalid/`r`n"; Check 'API redirect not followed' (Refuses {Runs} 'HTTP_302')
    $server.Replies.Enqueue("HTTP/1.1 200 OK`r`nContent-Length: 5000`r`nContent-Type: application/json`r`nConnection: close`r`n`r`n{}"); Check 'real HTTP truncated body refused' (Refuses {Runs} 'TRANSPORT_UNREADABLE')
    $server.Replies.Enqueue('garbage'); Check 'real HTTP malformed status/headers refused' (Refuses {Runs} 'TRANSPORT_UNREADABLE')
    Reply '{}' 403; Check 'inaccessible job log explicitly refused' (Refuses {Get-OrvionPublicLog 'owner/repo' 1} 'LOG_HTTP_403')
    Reply '{}' 302 "Location: http://127.0.0.1/secret`r`n"; Check 'unsafe signed-log redirect refused' (Refuses {Get-OrvionPublicLog 'owner/repo' 1} 'LOG_REDIRECT')
    $j=@{id=4;run_id=1;run_attempt=2;name='job';status='completed';conclusion='failure';steps=@(@{name='failed step';status='completed';conclusion='failure'})}
    Reply (ConvertTo-Json -Depth 10 -Compress @{total_count=1;jobs=@($j)}); $got=@(Get-OrvionPublicJobs 'owner/repo' 1 2)
    Check 'attempt jobs and failed-step evidence preserved' ($got.Count-eq1-and$got[0].steps[0].name-eq'failed step')
    $j.run_attempt=1; Reply (ConvertTo-Json -Depth 10 -Compress @{total_count=1;jobs=@($j)}); Check 'foreign jobs attempt refused' (Refuses {Get-OrvionPublicJobs 'owner/repo' 1 2} 'JOB_IDENTITY')
    Reply (ConvertTo-Json -Depth 10 -Compress (Row)); Check 'wrong run attempt endpoint result refused' (Refuses {Get-OrvionPublicAttempt 'owner/repo' 1 1} 'ATTEMPT_MISMATCH')
    $server.Replies.Enqueue("HTTP/1.1 200 OK`r`nContent-Length: 999999999`r`nContent-Type: application/json`r`nConnection: close`r`n`r`n")
    Check 'declared oversized HTTP body refused before buffering' (Refuses {Runs} 'BODY_LIMIT')
    $server.Replies.Enqueue("HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nConnection: close`r`n`r`n"+('x'*(16MB+1)))
    Check 'streamed body without declared length is bounded' (Refuses {Runs} 'BODY_LIMIT')
    $server.Replies.Enqueue("BODYDELAYHTTP/1.1 200 OK`r`nContent-Length: 2`r`nContent-Type: application/json`r`nConnection: close`r`n`r`n{}")
    Check 'real HTTP response body timeout fails closed' (Refuses {Invoke-OrvionPublicHttp ([uri]"http://127.0.0.1:$($server.Port)/slow") 1} 'TRANSPORT_UNREADABLE')
    $closed=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$closed.Start();$port=([Net.IPEndPoint]$closed.LocalEndpoint).Port;$closed.Stop()
    Check 'real HTTP inaccessible port fails closed' (Refuses {Invoke-OrvionPublicHttp ([uri]"http://127.0.0.1:$port/") 1} 'TRANSPORT_UNREADABLE')
    # Actual watcher subprocess: supplied fixture origin only, same adapter and authority functions.
    $scripts=Join-Path $work 'scripts';[void][IO.Directory]::CreateDirectory($scripts)
    Copy-Item (Join-Path $PSScriptRoot 'watch_ci.ps1'),(Join-Path $PSScriptRoot 'check_agent_continuity.ps1') -Destination $scripts
    [IO.File]::WriteAllText((Join-Path $scripts 'github_public_read.ps1'),$original)
    Reply (ConvertTo-Json -Depth 10 -Compress (Row))
    $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -RunId 1 -Attempt 2 -Repo owner/repo -RepoRoot $work 2>&1
    Check 'actual watcher reads requested attempt successfully' ($LASTEXITCODE-eq0-and($o|Out-String)-match'attempt 2.*completed/success') ($o|Out-String)
    $r=Row;$r.conclusion='failure';$j.run_attempt=2
    Reply (ConvertTo-Json -Depth 10 -Compress $r);Reply (ConvertTo-Json -Depth 10 -Compress @{total_count=1;jobs=@($j)});Reply '{}' 403
    $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -RunId 1 -Attempt 2 -Repo owner/repo -RepoRoot $work 2>&1
    Check 'actual watcher names failed step and returns unreadable for inaccessible log' ($LASTEXITCODE-eq2-and($o|Out-String)-match'failed step: failed step'-and($o|Out-String)-match'UNREADABLE log: PUBLIC_READ:LOG_HTTP_403') ($o|Out-String)
    # Polling uses a real local Git history and the authority's unchanged workflow deriver.
    $hooks=Join-Path $work 'hooks';[void][IO.Directory]::CreateDirectory($hooks)
    git init --quiet $work;git -C $work config core.hooksPath $hooks;git -C $work config user.name Fixture;git -C $work config user.email fixture@example.invalid
    $wf=Join-Path $work '.github/workflows';[void][IO.Directory]::CreateDirectory($wf)
    [IO.File]::WriteAllText((Join-Path $wf 'expected.yml'),"name: Expected`non:`n  push:`n")
    git -C $work add .;git -C $work commit --quiet -m baseline;$base=(git -C $work rev-parse HEAD).Trim()
    [IO.File]::WriteAllText((Join-Path $work 'probe.txt'),'changed');git -C $work add .;git -C $work commit --quiet -m candidate;$head=(git -C $work rev-parse HEAD).Trim()
    $count=$server.Requests.Count
    Reply '{}' 429 "Retry-After: 120`r`n"
    $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo owner/repo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
    Check 'actual watcher honors long rate-limit retry by stopping after one unreadable poll' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: public API retry-after=120'-and$server.Requests.Count-eq$count+1) ($o|Out-String)
    $r=Row;$r.head_sha=$head;Reply (Payload @($r));Reply (Payload @($r))
    $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo owner/repo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
    Check 'actual watcher positive poll retains expected-workflow deriver and literal success summary' ($LASTEXITCODE-eq0-and($o|Out-String)-match'every expected workflow ran and succeeded.*-Certify is the verdict') ($o|Out-String)
    $r.conclusion='failure';Reply (Payload @($r));Reply (ConvertTo-Json -Depth 10 -Compress @{total_count=1;jobs=@($j)});Reply '{}' 403
    $o=& pwsh -NoProfile -File (Join-Path $scripts 'watch_ci.ps1') -Sha $head -Branch main -Base $base -Repo owner/repo -RepoRoot $work -PollSeconds 0 -SettleSeconds 0 2>&1
    Check 'actual watcher polling diagnostic gap exits unreadable immediately' ($LASTEXITCODE-eq2-and($o|Out-String)-match'STOPPED: diagnostics unreadable') ($o|Out-String)
    $authority=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'check_agent_continuity.ps1'),[ref]$null,[ref]$null)
    foreach($fn in $authority.EndBlock.Statements|Where-Object{$_-is[Management.Automation.Language.FunctionDefinitionAst]-and$_.Name-in@('Profiles','Get-ControlSurface','Test-ControlPath','Implementation-Fingerprint')}){. ([scriptblock]::Create($fn.Extent.Text))}
    Check 'adapter and its suite use existing CONTROL classification' ((@(Profiles @('scripts/github_public_read.ps1'))-contains'CONTROL')-and(@(Profiles @('scripts/test_github_public_read.ps1'))-contains'CONTROL'))
    Check 'ordinary neighboring file does not acquire CONTROL' (-not(@(Profiles @('scripts/unrelated-fixture.ps1'))-contains'CONTROL'))
    $Root=$work;$contract=@{Scope=@('scripts/github_public_read.ps1')}
    $before=Implementation-Fingerprint $contract 'changes/fixture.md'
    [IO.File]::AppendAllText((Join-Path $scripts 'github_public_read.ps1'),"`n# mutation fixture`n")
    Check 'existing receipt fingerprint observes adapter bytes' ((Implementation-Fingerprint $contract 'changes/fixture.md')-cne$before)
    [IO.File]::WriteAllText((Join-Path $scripts 'github_public_read.ps1'),$original)
    Check 'existing fingerprint restored with adapter bytes' ((Implementation-Fingerprint $contract 'changes/fixture.md')-ceq$before)
    # Each mutant must install, return forbidden evidence, and be refused again after restoration.
    foreach($m in @(
        @{Name='required run schema';Find='Assert-OrvionPublicRun $r $Repo';Replace='$null = $r';Body={ $r=Row;$r.Remove('path');Payload @($r) };Pattern='MISSING_FIELD'},
        @{Name='HTTP failure';Find='if ($r.Status -ne 200)';Replace='if ($false)';Body={Payload @((Row))};Pattern='HTTP_503';Status=503}
    )) {
        $body=&$m.Body; $status=if($m.Status){$m.Status}else{200}; Reply $body $status; $before=Refuses {Runs} $m.Pattern
        $mut=$original.Replace($m.Find,$m.Replace); $installed=$mut-cne$original
        [IO.File]::WriteAllText($probe,$mut); . $probe
        Reply $body $status
        $escaped=try { $null=Runs; $true } catch { $false }
        [IO.File]::WriteAllText($probe,$original); . $probe
        Reply $body $status; $restored=Refuses {Runs} $m.Pattern
        Check "mutation killed and restoration proven: $($m.Name)" ($installed-and$before-and$escaped-and$restored)
    }
    $first=Payload $rows[0..99] 205
    Reply $first; Reply (Payload @() 205); $before=Refuses {Runs} 'INCOMPLETE_PAGE'
    $mut=$original.Replace('if ($rows.Count -eq $total)', 'if ($true)')
    [IO.File]::WriteAllText($probe,$mut); . $probe
    Reply $first; $escaped=(Runs).Count-eq100
    [IO.File]::WriteAllText($probe,$original); . $probe
    Reply $first; Reply (Payload @() 205); $restored=Refuses {Runs} 'INCOMPLETE_PAGE'
    Check 'mutation killed and restoration proven: pagination completion' ($mut-cne$original-and$before-and$escaped-and$restored)
    $requests=$server.Requests.ToArray()
    Check 'wire has no Authorization, Cookie or Proxy-Authorization' (-not @($requests|Where-Object{$_-match'(?im)^(Authorization|Cookie|Proxy-Authorization):'}).Count)
    Check 'constructed pagination visits pages 1 2 3' (@($requests|Where-Object{$_-match'per_page=100&page=3 '}).Count-gt0)
    if($Live) {
        # Public GitHub reads only; no test runs, dispatches or mutations. Results are current observations.
        . (Join-Path $PSScriptRoot 'github_public_read.ps1')
        $r=@(Get-OrvionPublicRuns 'PlatPlusHub/orvion-sandbox' -Sha '78acc077b69246b1506c64f37c475d0f1245a3ad' -Branch orvion-preflight -Event push)
        Check 'live anonymous sandbox exact run current-attempt read' ($r.Count-eq1-and$r[0].databaseId-eq38876025069-and$r[0].attempt-eq1-and$r[0].conclusion-ceq'success')
        $r=Get-OrvionPublicCollection 'repos/PlatPlusHub/orvion-sandbox/actions/runs' 'workflow_runs' 1
        Check 'live anonymous sandbox pagination is complete and nonempty' ($r.Count-ge4)
        $j=@(Get-OrvionPublicJobs 'PlatPlusHub/orvion-sandbox' 38875779719 1)
        Check 'live anonymous failed job metadata' ($j.Count-eq1-and$j[0].steps.name-contains'Synthetic outcome only')
        $log=try { $null=Get-OrvionPublicLog 'PlatPlusHub/orvion-sandbox' 116890370968; 'READABLE' } catch {$_.Exception.Message}
        "OBSERVED live job log: $log"
        Check 'live log read or explicit fail-closed inaccessibility' ($log-eq'READABLE'-or$log-match'^PUBLIC_READ:LOG_HTTP_(403|404)$')
        Check 'live nonexistent API repository inaccessible' (Refuses {Get-OrvionPublicRuns 'PlatPlusHub/orvion-reader-missing-927debc'} 'HTTP_404')
        $why='';$ok=try { Test-OrvionPublicGithub (Split-Path $PSScriptRoot -Parent); $true } catch { $why=$_.Exception.Message; $false }
        Check 'live public capability uses anonymous API and configuration-isolated native Git' $ok $why
    }
} finally {
    $server.Dispose()
    $target=[IO.Path]::GetFullPath($work)
    if(-not $target.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)){throw 'cleanup escaped temp'}
    Remove-Item -LiteralPath $target -Recurse -Force
}
"PUBLIC READER TESTS: $script:pass passed, $script:fail failed"
if($script:fail){exit 1};exit 0
