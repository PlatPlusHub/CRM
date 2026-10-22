# Standalone literal Draft authoring/replay helpers for this repository.
function Get-IndentedBlock([string[]]$L){($L|ForEach-Object{if($_-eq''){''}else{"   $_"}})-join"`n"}
function Get-Fence([string[]]$L){"   ``````text`n"+(Get-IndentedBlock $L)+"`n   ``````"}
function Get-DraftTargetPath([string]$Sb,[string]$File){
    $base=[IO.Path]::GetFullPath($Sb).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $segments=@($File-replace'\\','/'-split'/')
    if(!$File-or[IO.Path]::IsPathRooted($File)-or$File-match'[\x00-\x1f<>:"|?*`]'-or@($segments|Where-Object{$_-in@('','.','..','.git')}).Count){throw "DRAFT_PATH_INVALID:$File"}
    if(@($segments|Where-Object{$_-match'[ .]$|^(?:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3])(?:\.|$)'}).Count){throw "DRAFT_PATH_INVALID:$File"}
    $current=$base
    foreach($segment in @('')+$segments){
        if($segment){$current=Join-Path $current $segment}
        $item=Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if($item-and($item.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw "DRAFT_REPARSE_PATH:$File"}
    }
    $current
}
function Get-DraftContentBlob([string]$Sb,[string]$File,[string]$Text){
    $temporary=[IO.Path]::GetTempFileName()
    try{
        [IO.File]::WriteAllText($temporary,$Text,[Text.UTF8Encoding]::new($false))
        $blob=@(git -C $Sb hash-object "--path=$File" -- $temporary)
        if($LASTEXITCODE-or$blob.Count-ne1-or$blob[0]-cnotmatch'^[0-9a-f]{40}$'){throw "DRAFT_HASH_FAILED:$File"}
        $blob[0]
    }finally{[IO.File]::Delete($temporary)}
}
function Get-FileEdits([string]$Sb,[string]$f){
    $original=@(git -C $Sb show "HEAD:$f");if($LASTEXITCODE){throw "BASELINE_READ_FAILED:$f"}
    $cur=[Collections.Generic.List[string]]::new([string[]]@($original-split"`r?`n"));$parts=@();$delta=0
    # Counted as apply-draft-steps.ps1 matches: a substring of the whole text, not whole lines (a block unique as lines
    # matched 5 times as a substring, contract-A rehearsal 2026-10-20).
    function Count-Block([string[]]$B){([regex]::Matches(($cur-join"`n"),[regex]::Escape($B-join"`n"))).Count}
    $diff=@(git -C $Sb -c core.autocrlf=true diff -U0 --no-color -- $f);if($LASTEXITCODE){throw "DIFF_FAILED $f"}
    $i=0
    while($i-lt$diff.Count){
        $m=[regex]::Match($diff[$i],'^@@ -(\d+)(?:,(\d+))? \+\d+(?:,\d+)? @@');$i++
        if(-not$m.Success){continue}
        $a=[int]$m.Groups[1].Value;$k=if($m.Groups[2].Success){[int]$m.Groups[2].Value}else{1}
        $old=@();$new=@()
        while($i-lt$diff.Count-and$diff[$i]-notmatch'^@@ '){if($diff[$i].StartsWith('-')){$old+=$diff[$i].Substring(1)}elseif($diff[$i].StartsWith('+')){$new+=$diff[$i].Substring(1)};$i++}
        if($k-eq0){
            $end=$a+$delta
            $n=1;do{$anc=@($cur.GetRange($end-$n,$n));$hits=Count-Block $anc;$n++}while($hits-ne1-and$n-lt8)
            if($hits-ne1){throw "ANCHOR_NOT_UNIQUE $f @$a"}
            $cur.InsertRange($end,[string[]]$new);$delta+=$new.Count
            $parts+="immediately after the line$(if($anc.Count-gt1){'s'})`n$(Get-Fence $anc)`n   insert`n$(Get-Fence $new)"
        }else{
            $at=$a-1+$delta
            if((@($cur.GetRange($at,$k))-join"`n")-cne($old-join"`n")){throw "SIMULATION_DRIFT $f @$a"}
            # A replaced block that also occurs elsewhere grows by its preceding unchanged lines until unique; a pure
            # deletion grows at least once, since "replace with nothing" would leave an empty line behind.
            $ctx=0;while(((Count-Block $old)-ne1-or$new.Count-eq0)-and$ctx-lt8-and$at-$ctx-gt0){$ctx++;$lead=$cur[$at-$ctx];$old=@($lead)+$old;$new=@($lead)+$new}
            if((Count-Block $old)-ne1-or$new.Count-eq0){throw "BLOCK_NOT_UNIQUE $f @$a"}
            $cur.RemoveRange($at-$ctx,$k+$ctx);$cur.InsertRange($at-$ctx,[string[]]$new);$delta+=$new.Count-$k-$ctx
            $parts+="replace the line$(if($old.Count-gt1){'s'})`n$(Get-Fence $old)`n   with`n$(Get-Fence $new)"
        }
    }
    $parts
}
function Get-DraftFileStep([string]$Sb,[string]$File,[string]$Marker,[string]$What,[string]$ExpectedBlob){
    # the resume marker must be in the edited file, or a resumed run could never say Already Applied (wave-1 review, 2026-10-20)
    $path=Get-DraftTargetPath $Sb $File
    if(!$Marker-or$Marker-match'[`\r\n]'){throw "MARKER_INVALID:$File"}
    $raw=[IO.File]::ReadAllText($path)
    if(-not$raw.Contains($Marker)){throw "MARKER_ABSENT $File :: $Marker"}
    # the steps cannot say "no newline at end of file"; such a file would never reproduce its blob
    if($raw.Length-and-not$raw.EndsWith("`n")){throw "NO_FINAL_NEWLINE $File"}
    $listed=@(git -C $Sb ls-tree -z HEAD -- ":(literal)$File")
    if($LASTEXITCODE){throw "BASELINE_TREE_FAILED:$File"}
    $nb=if($ExpectedBlob){$ExpectedBlob}else{Get-DraftContentBlob $Sb $File $raw}
    if($nb-cnotmatch'^[0-9a-f]{40}$'){throw "BLOB_INVALID:$File"}
    if(!$listed.Count){
        $content=$raw-replace"`r`n","`n"
        if($content-match'(?m)^\s*```'){throw "CREATE_FENCE_UNSUPPORTED:$File"}
        $body="Check whether ``$File`` contains ``$Marker``; if so record Already Applied when its Git blob is $nb, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline ($What), and change nothing else:`n`n"
        return [pscustomobject]@{Text=$body+(Get-Fence @($content.Substring(0,$content.Length-1)-split"`n"))+"`n`n   The resulting file's Git blob is $nb.";Blob=$nb}
    }
    if($listed.Count-ne1-or$listed[0]-notmatch'^100(?:644|755) blob '){throw "BASELINE_NOT_REGULAR:$File"}
    $e=@(Get-FileEdits $Sb $File);if(!$e.Count){throw "NO_EDITS $File"}
    $body="Check whether ``$File`` contains ``$Marker``; if so record Already Applied when its Git blob is $nb, and otherwise stop and report. Otherwise make exactly $(if($e.Count-gt1){"these $($e.Count) edits"}else{'this one edit'}) ($What), each matched once, and change nothing else:`n`n"
    $n=0;foreach($p in $e){$n++;$body+="   $([char](96+$n))) $p`n`n"}
    [pscustomobject]@{Text=$body+"   The resulting file's Git blob is $nb.";Blob=$nb}
}
