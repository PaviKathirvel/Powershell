# Define the URL of the folder you want to download
$url = "http://buildserver-dev.jnj.com/jnj-opcx-scm/packages/database/mssql/PS"

# Specify the local directory where you want to save the downloaded folder
$destination = "D:\Users\PKathirv\OneDrive - JNJ\Desktop\folder\testfolder\"

# Create the destination directory if it doesn't exist
if (-not (Test-Path -Path $destination)) {
    New-Item -ItemType Directory -Force -Path $destination
}

# Create a WebClient object
$webClient = New-Object System.Net.WebClient

# Function to recursively download folder
function Download-Folder {
    param(
        [string]$source,
        [string]$destination
    )

    # Get the contents of the source directory
    $content = $webClient.DownloadString($source)
    $links = $content -split '<a href="' | Where-Object {$_ -match '^http.*\/$'}

    # Download each file or subfolder
    foreach ($link in $links) 
    {
        $linkUrl = $link -replace '">.*$'
        $linkName = $linkUrl -replace '.*/'
        $fullUrl = $source + $linkUrl

        # If it's a subfolder, create a corresponding local directory and recurse
        if($linkName -ne '../') 
        {
            $newDestination = Join-Path -Path $destination -ChildPath $linkName
            New-Item -ItemType Directory -Force -Path $newDestination
            Download-Folder -source $fullUrl -destination $newDestination
        }
        else 
        {
            $webClient.DownloadFile($fullUrl, (Join-Path -Path $destination -ChildPath $linkName))
        }
    }
}

# Call the function to start the download
Download-Folder -source $url -destination $destination
