# Replays literal Draft file steps; this is not an approval or scope-admission authority.
# Preflight every target, operation and filtered blob before the first implementation write.
param([Parameter(Mandatory)][string]$Draft,[Parameter(Mandatory)][string]$Root)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Invoke-DraftSteps.ps1')
$t=[IO.File]::ReadAllText($Draft)-replace"`r`n","`n"
$section=[regex]::Match($t,'(?s)## Implementation Steps\n\n(.*?)\n## Acceptance Criteria')
if(!$section.Success){throw 'IMPLEMENTATION_SECTION_MISSING'}
$items=@([regex]::Split($section.Groups[1].Value,'(?m)^(?=\d+\. )')|Where-Object{$_-match'^\d+\. Check whether '})
if(!$items.Count){throw 'NO_FILE_STEPS'}
$plans=@();$paths=@{}
foreach($it in $items){
    $pathMatch=[regex]::Match($it,'^\d+\. Check whether `([^`]+)` contains `([^`]+)`')
    $blobMatch=[regex]::Match($it,"The resulting file's Git blob is ([0-9a-f]{40})\.")
    if(!$pathMatch.Success-or!$blobMatch.Success){throw 'FILE_STEP_INVALID'}
    $file=$pathMatch.Groups[1].Value;$want=$blobMatch.Groups[1].Value
    $p=Get-DraftTargetPath $Root $file
    if($paths.ContainsKey($p)){throw "DUPLICATE_TARGET:$file"};$paths[$p]=$true
    $exists=[IO.File]::Exists($p)
    if(Test-Path -LiteralPath $p -PathType Container){throw "TARGET_IS_DIRECTORY:$file"}
    $raw=if($exists){[IO.File]::ReadAllText($p)}else{$null}
    if($exists-and(Get-DraftContentBlob $Root $file $raw)-eq$want){
        $plans+= [pscustomobject]@{File=$file;Path=$p;Skip=$true}
        continue
    }
    $fences=@([regex]::Matches($it,'(?ms)^   ```text\n(.*?)^   ```(?=\n|$)')|ForEach-Object{
        $body=$_.Groups[1].Value
        (@($body.Substring(0,$body.Length-1)-split"`n")|ForEach-Object{if($_.StartsWith('   ')){$_.Substring(3)}else{$_}})-join"`n"
    })
    $creating=$it.Contains('Otherwise create this file with exactly the following UTF-8 content and one final newline ')
    if($creating){
        if($exists){throw "CREATE_DESTINATION_EXISTS:$file"}
        if($fences.Count-ne1){throw "CREATE_FENCE_COUNT:$file"}
        $text=$fences[0]+"`n";$nl="`n"
    }else{
        if(!$exists){throw "EDIT_TARGET_MISSING:$file"}
        $nl=if($raw.Contains("`r`n")){"`r`n"}else{"`n"};$text=$raw-replace"`r`n","`n"
        $ops=@([regex]::Matches($it,'(?m)^   [a-z]\) (immediately after the lines?|replace the lines?)')|ForEach-Object{$_.Groups[1].Value})
        if(!$ops.Count-or$fences.Count-ne2*$ops.Count){throw "EDIT_FENCE_COUNT:$file"}
        for($i=0;$i-lt$ops.Count;$i++){
            $a=$fences[2*$i];$b=$fences[2*$i+1]
            $count=([regex]::Matches($text,[regex]::Escape($a))).Count
            if($count-ne1){throw "ANCHOR_COUNT:${file}:${i}:$count"}
            $at=$text.IndexOf($a,[StringComparison]::Ordinal)
            $text=if($ops[$i].StartsWith('replace')){$text.Remove($at,$a.Length).Insert($at,$b)}else{$text.Insert($at+$a.Length,"`n"+$b)}
        }
        $text=$text-replace"`n",$nl
    }
    $got=Get-DraftContentBlob $Root $file $text
    if($got-ne$want){throw "DRAFT_BLOB_MISMATCH:${file}:expected=$want actual=$got"}
    $plans+=[pscustomobject]@{File=$file;Path=$p;Skip=$false;Create=$creating;Before=$raw;Text=$text;Blob=$got}
}
foreach($plan in $plans){
    if($plan.Skip){"ALREADY_APPLIED: $($plan.File)";continue}
    $checked=Get-DraftTargetPath $Root $plan.File
    if($checked-cne$plan.Path){throw 'TARGET_CHANGED'}
    $bytes=[Text.Encoding]::UTF8.GetBytes($plan.Text)
    if($plan.Create){
        [void][IO.Directory]::CreateDirectory((Split-Path $plan.Path -Parent))
        $stream=[IO.File]::Open($plan.Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    }else{
        $stream=[IO.File]::Open($plan.Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    }
    try{
        if(!$plan.Create){
            $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true,1024,$true)
            try{$present=$reader.ReadToEnd()}finally{$reader.Dispose()}
            if($present-cne$plan.Before){throw "TARGET_CHANGED:$($plan.File)"}
            $stream.Position=0;$stream.SetLength(0)
        }
        $stream.Write($bytes,0,$bytes.Length);$stream.Flush()
    }finally{$stream.Dispose()}
    "APPLIED: $($plan.File) blob=$($plan.Blob)"
}
"files: $($items.Count), mismatches: 0"
exit 0
