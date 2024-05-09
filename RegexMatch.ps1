$build_server_url = "http://buildserver-dev.jnj.com/jnj-opcx-scm/packages/database/mssql" 
    $regexpattern = "SQL20[0-9][0-9]"   
    $htmlContent = Invoke-RestMethod -Uri $build_server_url
    $SQLmatches = $htmlContent -split '\n' | Select-String -Pattern $regexpattern | ForEach-Object { $_.Matches.Value }
    $SQLVer_SPVer = @{}
    $rtmregexpattern = "en_sql_server_20[0-9][0-9]_([a-z]+_[a-z]+|[a-z]+)_rtm.ISO"
    $sp_hf_regexpattern = "\d+.\d.\d+.exe"
    foreach($match in $SQLmatches)
    {
        $rtmUrl = "$build_server_url/$match/binaries"
        $rtmHtmlContent = Invoke-RestMethod -Uri $rtmUrl
        $RTMmatches = $rtmHtmlContent -split '\n' | Select-String -Pattern $rtmregexpattern | ForEach-Object { $_.Matches.Value }
        $SQLVer_SPVer[$match] = $RTMmatches

        if(!($match -eq "SQL2022"))
        {
        $match
        Write-Host "********************here"
        $sp_hf_url = "$build_server_url/sp_hf/$match"
        $sp_hf_htmlcontent = Invoke-RestMethod -Uri $sp_hf_url
        $sp_hf_matches = $sp_hf_htmlcontent -split '\n' | Select-String -Pattern $sp_hf_regexpattern | ForEach-Object { $_.Matches.Value }
        $SQLVer_SPVer[$match] += $sp_hf_matches
        $sp_hf_matches
        }
    }