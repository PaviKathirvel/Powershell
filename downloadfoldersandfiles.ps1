$url = "http://buildserver-dev.jnj.com/jnj-opcx-scm/packages/database/mssql/PS/sqlserver_PS_module/21.1.18080"
$outputDirectory = "D:\Users\PKathirv\OneDrive - JNJ\Desktop\Documents\PSScripts\TestFolder\PS\sqlserver_PS_module\21.1.18080"
if(!(Test-Path -path $outputDirectory))
{
    New-Item -Path $outputDirectory -ItemType Directory
}
$responsetest = Invoke-WebRequest -uri $url 
$values = $responsetest.links.href | ? {$_.contains(".")}
foreach($value in $values)
{
    $downloadurl = "$url/$value" 	
	$outputPath = "$outputDirectory/$value"
	$request = [System.Net.HttpWebRequest]::Create($downloadurl)
	$response = $request.GetResponse()
	$stream = $response.GetResponseStream()
	$fileStream = [System.IO.File]::Create($outputPath)
	$buffer = New-Object byte[] 1024
	$bytesRead = 0
	while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
		$fileStream.Write($buffer, 0, $bytesRead)
	}
	$fileStream.Close()
	$response.Close()
}
$folders = $responsetest.links.href | ? {(!($_.contains(".") -or $_.contains("=") -or $_.contains("_")))}
foreach($folder in $folders)
{
    $folder = $folder.replace("/","")
    $foldercreation = "$outputDirectory\$folder"
    if(!(Test-Path -path $foldercreation))
    {
        New-Item -path $foldercreation -ItemType Directory
    }
    $folderurl = "$url/$folder"
    $responsetest = Invoke-WebRequest -uri $folderurl
    $values = $responsetest.links.href | ? {$_.contains(".") -and (!($_.contains("_")))}
    foreach($value in $values){
        $downloadurl = "$folderurl/$value" 	
	    $outputPath = "$foldercreation/$value"
	    $request = [System.Net.HttpWebRequest]::Create($downloadurl)
	    $response = $request.GetResponse()
	    $stream = $response.GetResponseStream()
	    $fileStream = [System.IO.File]::Create($outputPath)
	    $buffer = New-Object byte[] 1024
	    $bytesRead = 0
	    while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
	    	$fileStream.Write($buffer, 0, $bytesRead)
	    }
	    $fileStream.Close()
	    $response.Close()
    }
}