# Pre-run hazard check for agent scratch scripts (not repository code). Finds the PowerShell name
# collisions that broke six scratch runs (2026-10-12..19): a function named like an existing command or
# alias (`Git` wrapping git recursed; `H` is Get-History), and a variable reused under another letter
# case or as a loop variable over a parameter (`foreach($id ...)` overwrote `$Id`).
# Usage: pwsh -NoProfile -File Test-ScriptHazards.ps1 <script.ps1> [...]; exit 1 when a hazard is found.
param([Parameter(Mandatory,ValueFromRemainingArguments)][string[]]$Path)
$found=0
foreach($p in $Path){
    $tokens=$null;$errs=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p),[ref]$tokens,[ref]$errs)
    foreach($e in $errs){"$p`:$($e.Extent.StartLineNumber) PARSE $($e.Message)";$found++}
    foreach($fn in $ast.FindAll({$args[0]-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){
        $hit=Get-Command -Name $fn.Name -CommandType Alias,Cmdlet,Application,ExternalScript -ErrorAction SilentlyContinue|Select-Object -First 1
        if($hit){"$p`:$($fn.Extent.StartLineNumber) FUNCTION '$($fn.Name)' shadows or is shadowed by $($hit.CommandType) '$($hit.Name)'";$found++}
    }
    # Every variable spelling per scope block: one name written in two letter cases is one variable.
    $vars=$ast.FindAll({$args[0]-is[Management.Automation.Language.VariableExpressionAst]},$true)|Where-Object{$_.VariablePath.IsUnqualified-and$_.VariablePath.UserPath-notmatch'^(_|args|true|false|null|PSItem|this|input|matches|LASTEXITCODE|PID|env:.*)$'}
    foreach($g in ($vars|Group-Object{$_.VariablePath.UserPath.ToLowerInvariant()})){
        $spell=@($g.Group|ForEach-Object{$_.VariablePath.UserPath}|Sort-Object -Unique -CaseSensitive)
        if($spell.Count-gt1){"$p`:$($g.Group[0].Extent.StartLineNumber) VARIABLE spelled $($spell -join ' / ') - PowerShell treats these as ONE variable";$found++}
    }
    # A parameter or assignment named like an automatic variable: `[int[]]$Pid` is $PID, read-only (2026-10-19).
    # $null= is the idiomatic discard, not a hazard.
    $auto='^(pid|host|home|input|args|error|matches|this|true|false|psitem|pshome|pwd|profile|executioncontext|myinvocation|psscriptroot|pscommandpath|lastexitcode|sender|event|eventargs|foreach|switch)$'
    foreach($v in @($ast.FindAll({$args[0]-is[Management.Automation.Language.ParameterAst]},$true)|ForEach-Object{$_.Name})+@($ast.FindAll({$args[0]-is[Management.Automation.Language.AssignmentStatementAst]},$true)|ForEach-Object{$_.Left}|Where-Object{$_-is[Management.Automation.Language.VariableExpressionAst]})){
        $n=$v.VariablePath.UserPath;if($n-match$auto-and$n-ne'LASTEXITCODE'){"$p`:$($v.Extent.StartLineNumber) AUTOMATIC VARIABLE '`$$n' is reserved by PowerShell - rename it";$found++}
    }
}
if($found){"hazards: $found"}else{'hazards: 0'}
exit [int]($found-gt0)
