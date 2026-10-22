# Tracked single-product owner interface. Run this file from trusted main; native engines remain authoritative.
# Owner adapter only. Existing repository publisher/promoter remain the authority.
# Existing workstation authentication; NOT credential isolation or PAT migration.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Root, [string]$Candidate, [switch]$NonInteractive, [string]$EvidenceDirectory)
$ErrorActionPreference = 'Stop'
$operation = 'PUBLISH'
$checkout = [IO.Path]::GetFullPath($Root)
$interactive = !$NonInteractive -and [Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost'
try { $interactive = $interactive -and ![Console]::IsInputRedirected -and ![Console]::IsOutputRedirected } catch { $interactive = $false }
# Host switches precede -File/-Command; do not mistake script arguments for host switches.
foreach ($a in [Environment]::GetCommandLineArgs() | Select-Object -Skip 1) {
    if ($a -match '^-(File|f|Command|c|EncodedCommand|e|ec)$') { break }
    if ($a.StartsWith('-') -and $a.Length -ge 5 -and 'noninteractive'.StartsWith($a.Substring(1).ToLowerInvariant())) { $interactive = $false }
}
$result = 'STARTED'; $classification = 'STARTING'; $exitCode = 1
$saved = $false
$selected = $null; $log = $null; $noHooks = $null
$started = [DateTime]::UtcNow.ToString('o')
function Save-Result {
    # Allowlisted metadata only. No transcripts, command output, exception text or environment dump.
    $record = [ordered]@{ operation=$operation; candidate=$selected; startedUtc=$started;
        recordedUtc=[DateTime]::UtcNow.ToString('o'); repository='PlatPlusHub/CRM'; checkout=$checkout;
        targetRef='refs/heads/orvion-preflight'; result=$result; classification=$classification; exitCode=$exitCode }
    [IO.File]::WriteAllText($log, ($record | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}
function Invoke-ReleaseChild([string]$Script, [string[]]$Arguments) {
    $script:classification = 'AUTHORITATIVE_COMMAND'
    $script:result = 'FAILED'
    # Windows PowerShell 5.1 promotes redirected native stderr (even Git's
    # successful "Everything up-to-date") to error records. Judge the process
    # by its captured exit code and exact verdict, not by that host conversion.
    $priorPreference = $ErrorActionPreference
    [void](Get-Command pwsh -ErrorAction Stop)
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& pwsh -NoProfile -File $Script @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $priorPreference }
    if ($null -eq $code) { throw 'Authoritative command did not return a process exit code.' }
    # Child DONE is provisional until this wrapper also verifies the exact remote ref.
    $lines | Where-Object { "$_" -notmatch '^(PUBLISH|PROMOTE): DONE$' } | ForEach-Object { Write-Host "$_" }
    if ($code -ne 0) {
        $script:exitCode = $code
        if (@($lines | Where-Object { "$_" -match '^(PUBLISH|PROMOTE): REFUSED$' }).Count) { $script:result = 'REFUSED' }
        throw "Authoritative $operation command returned exit $code. Preserve checkouts and receipts."
    }
    # Exit zero alone cannot turn a contradictory/missing child verdict into success.
    $verdicts = @($lines | Where-Object { "$_" -match '^(PUBLISH|PROMOTE):' })
    if ($verdicts.Count -ne 1 -or "$($verdicts[0])" -cne "${operation}: DONE") {
        throw 'Authoritative command did not return one unambiguous DONE result.'
    }
    $script:exitCode = 1; $script:classification = 'REMOTE_REF_VERIFICATION'
}
function Get-OwnerTrustedSource {
    $sourceRoot = Split-Path $PSScriptRoot -Parent
    function Read-SourceGit([string[]]$Arguments) {
        $value = @(& git -C $sourceRoot @Arguments 2>$null)
        if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted source Git read failed.' }
        $value
    }
    foreach ($kind in @(@('remote','get-url','--all','origin'), @('remote','get-url','--push','--all','origin'))) {
        $urls = @(Read-SourceGit $kind)
        if ($urls.Count -ne 1 -or $urls[0] -cnotmatch '^https://(?:PlatPlusHub@)?github\.com/PlatPlusHub/CRM(?:\.git)?$') { throw 'STOP: Wrong trusted source repository.' }
    }
    if ((Read-SourceGit @('branch','--show-current') | Out-String).Trim() -cne 'main' -or @(Read-SourceGit @('status','--porcelain')).Count) { throw 'STOP: Launch this owner interface from a clean trusted main checkout.' }
    # A configuration check only: preserve the existing reset + own-account helper route; never execute or log a token.
    $sourceHelpers = @(Read-SourceGit @('config','--local','--get-all','credential.https://github.com.helper'))
    if ($sourceHelpers.Count -ne 2 -or $sourceHelpers[0] -cne '' -or
        $sourceHelpers[1] -notmatch 'gh auth token --user PlatPlusHub\b' -or
        [regex]::Matches($sourceHelpers[1], 'gh auth token --user ').Count -ne 1) { throw 'STOP: Trusted source credential routing is not pinned to the own account.' }
    & git -C $sourceRoot fetch --quiet origin
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Trusted source fetch failed.' }
    if ((Read-SourceGit @('rev-parse','HEAD') | Out-String).Trim() -cne (Read-SourceGit @('rev-parse','refs/remotes/origin/main') | Out-String).Trim()) { throw 'STOP: Prepare trusted main before launching; no automatic fast-forward.' }
    $sourceRoot
}
function Invoke-Operation {
$sourceRoot = Get-OwnerTrustedSource
$repo = $checkout
function GitRead([string[]]$Arguments) {
    $value = @(& git -C $repo @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "STOP: Git read failed: $($Arguments -join ' ')" }
    return $value
}
if (!(Test-Path -LiteralPath (Join-Path $repo 'scripts\publish_candidate.ps1') -PathType Leaf)) { throw "STOP: Original CRM checkout missing: $repo" }
$top = (GitRead @('rev-parse','--show-toplevel') | Out-String).Trim()
if ([IO.Path]::GetFullPath($top) -ine [IO.Path]::GetFullPath($repo)) { throw 'STOP: Unexpected repository root.' }
foreach ($kind in @(@('remote','get-url','--all','origin'), @('remote','get-url','--push','--all','origin'))) {
    $urls = @(GitRead $kind)
    if ($urls.Count -ne 1 -or $urls[0] -cnotmatch '^https://(?:PlatPlusHub@)?github\.com/PlatPlusHub/CRM(?:\.git)?$') { throw 'STOP: Unexpected CRM fetch/push destination.' }
}
$candidateHelpers = @(GitRead @('config','--local','--get-all','credential.https://github.com.helper'))
if ($candidateHelpers.Count -ne 2 -or $candidateHelpers[0] -cne '' -or
    $candidateHelpers[1] -notmatch 'gh auth token --user PlatPlusHub\b' -or
    [regex]::Matches($candidateHelpers[1], 'gh auth token --user ').Count -ne 1) { throw 'STOP: Candidate credential routing is not pinned to the own account.' }
$head = (GitRead @('rev-parse','HEAD') | Out-String).Trim()
if ($head -cne $Candidate) { throw "STOP: Original HEAD is $head; expected $Candidate. Preserve the checkout and ask the agent to prepare it." }
if (@(GitRead @('status','--porcelain')).Count) { throw 'STOP: Original checkout is dirty.' }
if (!(GitRead @('branch','--show-current') | Out-String).Trim()) { throw 'STOP: Detached HEAD; ask the agent to restore the prepared candidate branch.' }
if (!(Test-Path -LiteralPath (Join-Path $repo ".orvion-certifications\$Candidate.json") -PathType Leaf)) { throw 'STOP: Original exact-SHA certification record is missing.' }
& git -C $repo fetch --quiet origin
if ($LASTEXITCODE -ne 0) { throw 'STOP: Fetch failed.' }
$main = (GitRead @('rev-parse','refs/remotes/origin/main') | Out-String).Trim()
& git -C $repo merge-base --is-ancestor $main $Candidate
if ($LASTEXITCODE -ne 0) { throw 'STOP: Candidate diverges from current main.' }
if ((GitRead @('rev-parse','HEAD') | Out-String).Trim() -cne $Candidate -or @(GitRead @('status','--porcelain')).Count) { throw 'STOP: Checkout changed during preparation.' }
Invoke-ReleaseChild (Join-Path $sourceRoot 'scripts\publish_candidate.ps1') @('-Root',$repo)
$lines = @(GitRead @('ls-remote','--exit-code','origin','refs/heads/orvion-preflight'))
if ($lines.Count -ne 1 -or ($lines[0] -split '\s+')[0] -cne $Candidate) { throw 'STOP: Remote preflight does not match the selected SHA.' }
}
try {
    $logs = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) } else { Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'ORVION-Owner-Review\owner-operations\PlatPlusHub_CRM' }
    [void][IO.Directory]::CreateDirectory($logs)
    $log = Join-Path $logs (('{0}-{1}-{2}.json' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'),$operation,[guid]::NewGuid().ToString('N')))
    Save-Result
    $result = 'REFUSED'; $classification = 'PRECONDITION'
    if (!$Candidate -and $interactive) { $Candidate = Read-Host 'Full 40-character candidate SHA' }
    if (!$Candidate -or $Candidate.Trim() -cnotmatch '^[0-9a-fA-F]{40}$') { throw 'Candidate must be a full 40-character hexadecimal SHA.' }
    $Candidate = $Candidate.Trim().ToLowerInvariant(); $selected = $Candidate
    Write-Host "Operation: $operation"
    Write-Host "Candidate: $Candidate"
    Write-Host 'Repository: https://github.com/PlatPlusHub/CRM'
    Write-Host "Checkout: $checkout"
    Write-Host 'Action: validate the prepared receipt and publish this exact SHA through scripts/publish_candidate.ps1.'
    if (!$interactive) { $classification = 'INTERACTIVE_CONFIRMATION_REQUIRED'; throw 'An interactive console and explicit owner confirmation are required. No release operation was attempted.' }
    $classification = 'OWNER_CONFIRMATION'
    if ((Read-Host "Type $operation to confirm, or press Enter to cancel") -cne $operation) {
        $result = 'CANCELLED'; $classification = 'OWNER_CANCELLED'; $exitCode = 2
    } else {
        $classification = 'PRECONDITION'
        Invoke-Operation
        $result = 'DONE'; $classification = 'EXACT_REMOTE_REF_VERIFIED'; $exitCode = 0
    }
} catch {
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($log) {
        try { Save-Result; $saved = $true } catch {
            $result = 'FAILED'; $classification = 'LOG_WRITE_FAILED'; if ($exitCode -eq 0) { $exitCode = 1 }
            Write-Host 'Operation evidence could not be saved. Do not retry a release blindly; inspect the remote ref.' -ForegroundColor Red
        }
    } else { $result = 'FAILED'; $classification = 'LOG_UNAVAILABLE' }
    Write-Host "${operation}: $result" -ForegroundColor $(if ($result -eq 'DONE') { 'Green' } else { 'Yellow' })
    Write-Host "Classification: $classification; exit code: $exitCode"
    if ($log) { Write-Host "Log: $log" }
    if ($result -eq 'DONE') { Write-Host 'Publication is not acceptance or certification. Wait for exact-SHA PROMOTION READY before Owner-Promote.' }
    if ($interactive) {
        try { [void](Read-Host "$(if ($saved) { 'Result saved.' } else { 'Result could not be saved.' }) Press Enter when you have finished reading") }
        catch { Write-Host 'Console input unavailable; the saved log retains the result.' }
    }
}
exit $exitCode
