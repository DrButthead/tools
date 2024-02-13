# Get the current directory where the script is being called from
$inputPath = (Get-Location).Path
$outputPath = Join-Path -Path $inputPath -ChildPath "output"

# Get a list of all .flac files in the input path and its subfolders, excluding "output" directories
$files = Get-ChildItem -Path $inputPath -Filter *.flac -Recurse | Where-Object { $_.DirectoryName -notlike "*\\output\\*" }
if ($files.Count -eq 0) {
    Write-Host "No FLAC files found, nothing to convert."
    Exit
}

$numFlacFiles = $files.Count

# Ignore files that already have a corresponding .mp3 file in the output directory
$files = $files | Where-Object { -not (Test-Path ((Join-Path -Path $outputPath -ChildPath ($_.FullName.Substring($inputPath.Length))) -replace '\.flac$','.mp3')) }
if ($files.Count -eq 0) {
    Write-Host "All $numFlacFiles/$numFlacFiles FLAC files already converted to MP3"
    Exit
}

$numFlacFiles = $files.Count

# Get the full path to the ffmpeg executable
$ffmpegPath = (Get-Command ffmpeg).Source
if ([string]::IsNullOrEmpty($ffmpegPath) -or -not (Test-Path $ffmpegPath -PathType Leaf)) {
    Write-Error "ffmpeg not found or not in the system's PATH"
    Exit 1
}


# Now we can start converting files


# Create the output folder if it doesn't exist
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null


try {
    # Iterate through the list of files and start a job for each file
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($inputPath.Length + 1)
        $outputDirectory = Join-Path -Path $outputPath -ChildPath $relativePath | Split-Path
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
        $outputFile = Join-Path -Path $outputDirectory -ChildPath ($file.Name -replace '\.flac$','.mp3')

        $job = Start-ThreadJob -ScriptBlock {
            param($ffmpegPath, $file, $outputFile)
            & $ffmpegPath -i $file.FullName -c:a libmp3lame -q:a 0 -map_metadata 0 $outputFile
        } -ArgumentList $ffmpegPath, $file, $outputFile
    }

    # Display a progress bar and keep running until all jobs are completed
    $jobs = Get-Job
    while ($jobs.State -contains 'Running') {
        $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
        $total = $jobs.Count
        Write-Progress -Activity "Converting to MP3" -Status "$completed/$total Conversions completed" -PercentComplete ($completed / $total * 100)
        Start-Sleep -Milliseconds 10 
        $jobs = Get-Job
    }

    # All jobs are completed, remove the progress bar
    Write-Progress -Activity "Converting to MP3" -Completed

    Write-Host "$numFlacFiles/$numFlacFiles FLAC files converted to MP3"
} finally {
    # Clear all completed jobs
    Get-Job | Stop-Job
    Get-Job | Remove-Job  
}