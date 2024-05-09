###################################################################################################
$global:ScriptName = "sddc_sql_SQLInstallBatchScript.PS1"
$global:Scriptver = "10.0"
#Description: Description: Execute all the scripts related to SQL provisioning in one batch 
###################################################################################################
#Version		Date		Author		             Reason for Change
###################################################################################################
#1.0			09/10/2014	Atul Patil	             New Script
#2.0			11/24/2014	Jay Sangam	             Provision for named instance installs
#3.0			Feb/10/2016	Jay Sangam	             Provision for SP aware installs
#4.0            Jan/19/2017	Saketh Valluripalli      Provisioning of SQL 2014 and additional parameter SP3CU11.0.6567 for SQL2012 builds
#5.0            Dec/02/2017	Kishore Kumar            Provisioning of SQL 2014 SP2 with security patch with additional parameter SP4CU12.0.5557.0 and SQL2012 SP4 
#6.0            Jun/25/2018 Kavya/Kishore            Added new license key for MSSQL2012 and MSSQL2014
                                                     #Added logic to exclude creating registry setting for TF1117 & TF1118 for SQL 2016 
                                                     #Added logic to include disabling CEIP in SQL 2016
                                                     #Added SP2 for SQL2016
                                                     #If STANDARD edition, if it is seen more than 4 SOCKETS raise an error(Commented out)   
#7.0 			Sept/2/2019		Sanjiv				 #Adding 2017 Installation logic and Baseline Performance framework 
#8.0 			FEB/26/2020		Sanjiv				 #Adding 2019 Installation logic	
#9.0 			APR/15/2021		Sanjiv				 #Promoting SQL2019  
#10.0           Jan//2024       Pavithra             #Making scripts dynamic and work for all the sql version releases
###################################################################################################
function CheckParameters()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Process,
        [Parameter(Mandatory)]
        [string]$Tier,
        [Parameter(Mandatory)]
        [string]$Env,
        [Parameter(Mandatory)]
        [string]$Edition,
        [Parameter(Mandatory)]
        [string]$strCollation,
        [Parameter(Mandatory)]
        [string]$SQLVersion,
        [Parameter(Mandatory)]
        [string]$SPVersion,
        [Parameter(Mandatory)]
        [hashtable]$SQLVer_SPVer,
        [Parameter(Mandatory)]
        [String[]]$arrCollation

    )
    try
    {
        if(($Process -ine "SDDC") -and ($Process -ine "NON_SDDC")) #@pavithra...change here as per the new requirement
        {
            Write-Host "`nProcess not Valid. Please pass SDDC or NON_SDDC as 1st parameter`n" -f red
            EXIT 0
        }

        if(($Tier -ine "Small") -and ($Tier -ine "Medium") -and ($Tier -ine "Large"))
        {
            Write-Host "`nSize not Valid. Please pass SMALL or MEDIUM or LARGE as 2nd parameter`n" -f red
            EXIT 0
        }

        if(($Env -ine "DEV") -and ($Env -ine "QA") -and ($Env -ine "PROD"))
        {
            Write-Host "`nEnvironment not Valid. Please pass DEV or QA or PROD as 3rd parameter`n" -f red
            EXIT 0
        }

        if(!($SQLVer_SPVer.ContainsKey($SQLVersion))) 
        {
            Write-Host "`nInvalid SQLServer version. Please pass any of the avaliable SQL versions as 4th parameter : $($SQLVer_SPVer.Keys)`n" -f red
            Exit 0
        }
        else
        {
            $values = $SQLVer_SPVer[$SQLVersion]
            if($values -notcontains $SPVersion)
            {
                Write-Host "Service pack version not valid for $key. Please pass any of the available Server Pack Versions as 5th parameter : $values`n" -f red
                EXIT 0
            }
        }

        if(($Edition -ine "E") -and ($Edition -ine "S"))
        {
            Write-Host "`nInvalid SQLServer Edition. Please pass any of the avaliable SQL versions as 6th parameter :  E(express) or S(standard)`n" -f red
            Exit 0
        }

        if($arrCollation -notcontains $strCollation)
        {
            Write-Host "`nPlease pass a valid collation name as 7th parameter`n" -f red
            EXIT 0
        }
        
    }
    catch
    {
        Write-Output "Error Occurred : $_.Message" 
    }
    
}
function Executeallscripts
{
    Param(
       [string] $dmllocation,
       [string] $prc,
       [string] $tr,
       [string] $envr,
       [string] $sqlver,
       [string] $edtn,
       [string] $instnc,
       [string] $spver,
       [string] $collation
    )
    try 
    {
        $Time = Get-Date -UFormat "%y%m%d%H%M"
        $pathforLogs = "C:\SQLInstall_Logs"
        if(!(Test-Path $pathforLogs))
        {
            New-Item -path $pathforLogs -ItemType Directory
        }
        $BatchLog = "$pathforLogs\sddc_sql_SQLInstallBatchScript_$Time.txt"
        $Exec_Time = Get-Date

        Write-Host "###################################################################################################"
        Write-Host "Script Name: $ScriptName`nScript Version: $Scriptver`nExecuted On: $Exec_Time`nServer Host: $ENV:computername"
        Write-Host "###################################################################################################"

        "###################################################################################################" >> $BatchLog
        "Script Name: $ScriptName`nScript Version: $Scriptver`nExecuted On: $Exec_Time`nServer Host: $ENV:computername" >> $BatchLog
        "Execution string: $ScriptName $prc $tr $envr $sqlver $spver $edtn $instnc $collation" >> $BatchLog
        "###################################################################################################" >> $BatchLog
        "" >> $BatchLog

        $ResultFilePath = "C:\IQOQ\Status.txt"

        #----------------------------Execute OS Verfication Script --------------------------#
        $OSVerificationScript = "$dmllocation\sddc_sql_Pre-Req_OS_Verification.ps1"
        powershell.exe -ExecutionPolicy Bypass $OSVerificationScript $prc $tr $envr $sqlver
        $PreReqOSVerficationResult = Get-Content $ResultFilePath
        if($PreReqOSVerficationResult -ne "FAILED")
        {
            "Script sddc_sql_Pre-Req_OS_Verification.ps1 : Executed successfully" >> $BatchLog

            #----------------------Execute SQL Installation Script --------------------------#
            $SQLInstallationScript = "$dmllocation\SDDC_sql_InstallSQLServer.ps1"
            powershell.exe -ExecutionPolicy Bypass $SQLInstallationScript $prc $sqlver $edtn $spver $collation $instnc
            $SQLInstallationResult = Get-Content $ResultFilePath
            if($SQLInstallationResult -ne "FAILED")
            {
                "Script SDDC_sql_InstallSQLServer.ps1 : Executed successfully" >> $BatchLog

                #----------------------Execute SQL Post Installation Script --------------------------#
                $SQLPostInstallationScript = "$dmllocation\sddc_sql_Post_Installation.ps1"
                powershell.exe -ExecutionPolicy Bypass $SQLPostInstallationScript $prc $sqlver $instnc
                $SQLPostInstallationResult = Get-Content $ResultFilePath
                if($SQLPostInstallationResult -ne "FAILED")
                {
                    "Script sddc_sql_Post_Installation.ps1 : Executed successfully" >> $BatchLog

                    #---------------------Execute Post Verification ----------------------#
                    if($Process -eq "NON_SDDC")
                    {
                        $scripttorun = "sddc_sql_Post_Installation_Verification.ps1"
                    }
                    elseif($Process -eq "SDDC")
                    {
                        $scripttorun = "sddc_sql_Post_Installation_Verification_SDDC.ps1"
                    }
                    $SQLPostInstallVerificationScript = "$dmllocation\$scripttorun"
                    powershell.exe -ExecutionPolicy Bypass $SQLPostInstallVerificationScript $sqlver $spver $instnc
                    if($SQLInstallationResult -eq "REBOOT")
                    {
                        Write-Host "Please reboot the server"
                    }
                    $SQLPostInstallVerificationResult = Get-Content $ResultFilePath
                    if($SQLPostInstallVerificationResult -ne "FAILED")
                    {
                        "Script $scripttorun : Executed successfully" >> $BatchLog
                    }
                    else
                    {
                        "Script $scripttorun : FAILED. View the log files and address the failed steps" >> $BatchLog
                    }
                }
                else
                {    
                    Write-host "Error during Post Installation script sddc_sql_Post_Installation"
		            "Script sddc_sql_Post_Installation.ps1 : Error during Post Installation script sddc_sql_Post_Installation" >> $BatchLog
                }
            }
            else
            {
                Write-host "Reboot required OR Error during SQL Installation"
                "Script sddc_sql_InstallSQLServer.ps1 : Reboot required OR Error during SQL Installation" >> $BatchLog 
            }
        }
        else
        {
            Write-host "`n Resolve the failed tasks and then run the script.`n"
            "Script sddc_sql_Pre-Req_OS_Verification.ps1 : Resolve the failed tasks and then run the script." >> $BatchLog 
        }
        Write-Host "The passed parameters are valid...good to proceed further..."
    }
    catch 
    {
        Write-Output "Error Occurred : $_.Message"
    }
}

try
{
    $Process = $args[0] #change into aws and az and opcx --> 12/12 
    $Tier = $args[1]
    $Env = $args[2]
    $SQLVersion = $args[3]
    $SPVersion = $args[4] #for 2016&earlier....should pass sp + patch version 
    $Edition = $args[5]
    $strCollation = $args[6]
    $InstanceName = "MSSQLSERVER"	

    $SQLDML= "\\na.jnj.com\ncsusdfsroot\NCSUSGRPDATA\sqlsrvr\MSSQLDML\Scripts\DBaaSDevelopment\TLM_Prov\2023\Provisioning_Scripts\" 
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

        $sp_hf_url = "$build_server_url/sp_hf/$match"
        $sp_hf_htmlcontent = Invoke-RestMethod -Uri $sp_hf_url
        $sp_hf_matches = $sp_hf_htmlcontent -split '\n' | Select-String -Pattern $sp_hf_regexpattern | ForEach-Object { $_.Matches.Value }
        $SQLVer_SPVer[$match] += $sp_hf_matches
    }

    # $SQLVer_SPVer["SQL2005"] = @("SP3", "SP4")
    # $SQLVer_SPVer["SQL2008"] = @("SP3", "SP4", "SP4_10.00.6556")
    # $SQLVer_SPVer["SQL2012"] = @("SP2", "SP3", "SP3CU11.0.6567", "SP4", "SP4_11.0.7462")
    # $SQLVer_SPVer["SQL2014"] = @("SP2", "SP2_12.0.5557", "SP2_12.0.5589", "SP3_12.0.6329")
    # $SQLVer_SPVer["SQL2016"] = @("SP1", "SP2", "SP2_13.0.5201", "SP2_13.0.5426", "SP2_13.0.5830", "CU17", "SP3", "SP3_13.0.6419")
    # $SQLVer_SPVer["SQL2017"] = @("RTM", "CU16", "CU21", "CU25", "CU29")
    # $SQLVer_SPVer["SQL2019"] = @("RTM", "CU16", "CU17") 

    $arrCollation = @("SQL_Latin1_General_CP1_CI_AS",
                      "Latin1_General_CI_AI",
                      "Latin1_General_CI_AS",
                      "Latin1_General_CI_AS_KS_WS",
                      "SQL_Latin1_General_CP850_CI_AI",
                      "Chinese_PRC_CI_AS",
                      "SQL_Latin1_General_CP1_CI_AI",
                      "SQL_Latin1_General_CP850_BIN2",
                      "Chinese_Taiwan_Stroke_CI_AS",
                      "SQL_Latin1_General_CP1_CS_AS",
                      "Cyrillic_General_CI_AS",
                      "Finnish_Swedish_CI_AS",
                      "Japanese_CI_AS",
                      "SQL_Czech_CP1250_CI_AS",
                      "Arabic_BIN",
                      "Czech_BIN",
                      "French_BIN",
                      "Latin1_General_CS_AS",
                      "SQL_Latin1_General_CP850_BIN",
                      "Thai_CI_AS",
                      "Finnish_Swedish_CS_AI",
                      "Hebrew_CI_AS",
                      "Japanese_CI_AI",
                      "Korean_Wansung_CI_AS",
                      "Latin1_General_CS_AI",
                      "Polish_CI_AS",
                      "SQL_1xCompat_CP850_CI_AS",
                      "SQL_Hungarian_CP1250_CS_AS",
                      "SQL_Slovak_CP1250_CI_AS" )   
                      
    CheckParameters -Process $Process -Tier $Tier -Env $Env -SQLVersion $SQLVersion -SPVersion $SPVersion -Edition $Edition -strCollation $strCollation -SQLVer_SPVer $SQLVer_SPVer -arrCollation $arrCollation   
    $SQLServerRegistryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"
    if(Test-Path $SQLServerRegistryPath)
    {
      $instances = (Get-ItemProperty $SQLServerRegistryPath).InstalledInstances
      if($instances -contains $InstanceName)
      {
        Write-host "`nDefault instance $InstanceName already exists.`n"
        Exit 0  
      }
    }
    Executeallscripts $SQLDML $Process $Tier $Env $SQLVersion $Edition $InstanceName $SPVersion $strCollation
}
catch
{
  Write-Output "Error Occured : $_.Message"
}