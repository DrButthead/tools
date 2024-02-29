$TagLib = "I:\Documents\PowerShell\Modules\taglib\taglib-sharp.dll"
Add-Type -Path $TagLib
[System.Reflection.Assembly]::LoadFile($TagLib) 

# Define source and target directories
$sourceDirectory = 'J:\E\Music'
$targetDirectory = 'H:\Music\Organised\Crash Bandicoot'

Write-Host "Source: '$($sourceDirectory)' -> Target: '$($targetDirectory)'"

# Toggle switch for content comparison
$contentComparisonEnabled = $true

# Define size difference threshold in bytes
$sizeDifferenceThreshold = 200KB


# Get all .mp3 files in the source directory and its subfolders
$mp3Files = Get-ChildItem -Path $sourceDirectory -Filter *.mp3 -Recurse
# Get all .mp3 files in the target directory and its subfolders
$targetMp3Files = Get-ChildItem -Path $targetDirectory -Filter *.mp3 -Recurse


# Initialize progress counter, file hash counter, and current file counter
$global:totalFiles = $mp3Files.Count
$global:currentFileCount = 0
$global:hashedFileCount = 0
$global:hashedAcoustIdCount = 0
$global:currentFileName = ""
$global:checkingFileName = ""
$global:currentArtist = ""
$global:currentAcoustId = ""
$global:checkingAcoustId = ""



# Hashtable to store file hashes
$fileHashes = @{}

# Hashtable to store AcoustID's
$acoustIdHashes = @{}


# Function to calculate MD5 hash of a file and cache it
function Get-FileHash($filePath) {
	if (-not $fileHashes.ContainsKey($filePath)) {
		$fileStream = [System.IO.File]::OpenRead($filePath)
		$hashAlgorithm = [System.Security.Cryptography.MD5]::Create()
		$fileHash = [System.BitConverter]::ToString($hashAlgorithm.ComputeHash($fileStream))
		$fileStream.Close()
		$fileHashes[$filePath] = $fileHash.Replace("-", "").ToLower()

		# Increment counter for files hashed
		$global:hashedFileCount++
	}
	return $fileHashes[$filePath]
}


# Function to get AcoustID from the file and cache it
function Get-AcoustId($file) {
	if (-not $acoustIdHashes.ContainsKey($file.FullName)) {
		$Media = [TagLib.File]::Create($file.FullName)
		$tag = ($Media.tag.tags[0])
		if ($tag) {
			foreach ($t in ($Media.tag.tags[0])) {
				if ($t.Description -eq "Acoustid Id") {
					$acoustIdHashes[$file.FullName] = ($t.text)
					$global:hashedAcoustIdCount++
                    break
				}
			}
		}
	}
	$global:checkingAcoustId = $acoustIdHashes[$file.FullName]
	return $acoustIdHashes[$file.FullName]
}


function Get-FileMetadata {
	[CmdletBinding(PositionalBinding = $false)]
	Param
	(
		[Parameter(Mandatory = $true)][string]$FilePath
	)

	$shell = New-Object -COMObject Shell.Application
	$folder = Split-Path $FilePath
	$file = Split-Path $FilePath -Leaf
	$shellfolder = $shell.Namespace($folder)
	$shellfile = $shellfolder.ParseName($file)

	# There were 320 file properties obtained with this method as of October 2020
	0..320 | ForEach-Object {
		$out = [PSCustomObject]@{
			PropertyNum   = [string]$_
			PropertyName  = [string]($shellfolder.GetDetailsOf($null, $_))
			PropertyValue = [string]($shellfolder.GetDetailsOf($shellfile, $_))
		}

		$out
	}
}


function Write-ProgressCust {
	Write-Progress -Activity "Processing Files" -Status "File $($global:currentFileCount) of $($global:totalFiles) | Files Hashed: $($global:hashedFileCount) | Acoust ID's Hashed: $($global:hashedAcoustIdCount) | Current File: $($global:currentFileName) | Checking File: $($global:checkingFileName) | Current Artist: $($global:currentArtist) | Current AcoustID: $($global:currentAcoustId) | Checking AcoustID: $($global:checkingAcoustId)" -PercentComplete ($global:currentFileCount / $global:totalFiles * 100)
}


# Loop through each mp3 file in the source directory
foreach ($file in $mp3Files) {
    # Make sure the matching file is always cleared
    $matchingFile = $null

	$global:currentFileCount++

	# Extract artist information from source file if available using Get-FileMetadata function
	$tmp = Get-FileMetadata -file $file.FullName | Where-Object { "Authors" -eq $_.PropertyName }
	$global:currentArtist = $tmp.PropertyValue

	# Exctact acoustId information from source file if available
	$global:currentAcoustId = Get-AcoustId $file

	# Display progress with current file name, files hashed count, and total files count
	$global:currentFileName = $file.FullName

	# Reset the checking acoust ID
	$global:checkingAcoustId = ""

	Write-ProgressCust

	# Check if a matching file exists in a folder with the artist's name in the target directory based on content
	if ($global:currentArtist) {
		$artistFolder = Join-Path -Path $targetDirectory -ChildPath $global:currentArtist

		if ($doesExist = Test-Path -Path $artistFolder -PathType Container) {
			$matchingFile = Get-ChildItem -Path $artistFolder -Filter *.mp3 | Where-Object { $_.Length -ge ($file.Length - $sizeDifferenceThreshold) -and $_.Length -le ($file.Length + $sizeDifferenceThreshold) } | ForEach-Object {
                $global:checkingFileName = $_.FullName
                Write-ProgressCust
                if ((Get-FileHash $_.FullName) -eq (Get-FileHash $file.FullName)) {
					$_
				}
				elseif (-not ([string]::IsNullOrEmpty($global:currentAcoustId)) -and $global:currentAcoustId -eq (Get-AcoustId $_)) {
					$_
				}
			}
		}
        
	}

    # Fallback to searching for matches in the entire target directory if no artist tag is available or content comparison is disabled
	if (-not $matchingFile) {
		$matchingFile = $targetMp3Files | Where-Object { $_.Length -ge ($file.Length - $sizeDifferenceThreshold) -and $_.Length -le ($file.Length + $sizeDifferenceThreshold) } | ForEach-Object {
            $global:checkingFileName = $_.FullName
            Write-ProgressCust
			if (((Get-FileHash $_.FullName) -eq (Get-FileHash $file.FullName))) {
				$_
			}
			elseif (-not ([string]::IsNullOrEmpty($global:currentAcoustId)) -and $global:currentAcoustId -eq (Get-AcoustId $_)) {
				$_
			}
		}
	}


	if ($matchingFile) {
		# Display message before deleting the file
		Write-Host "Deleting '$($file.FullName)' as it matches '$($matchingFile.FullName)'"

		# Delete the file if it exists in the target directory or its subfolders using .NET File class
		[System.IO.File]::Delete($file.FullName)
	}
}


# Display completion message
Write-Host "Processing complete. Removed duplicate files from source directory based on content."
