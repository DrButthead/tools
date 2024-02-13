# Readme

This is a collection of small scripts and tools I have made to help my every day life. While I try to make these scripts as decoupled from my PC environment as I can, it's not a guarantee that any of these will work as expected on anything other than my main computer.

## converttomp3.ps1

This script will use ffmpeg in multiple threads to convert all .flac files inside the directory (and it's children) that the script is run in. ffmpeg and LAME must be installed (see [here](https://ffmpeg.org/download.html) and [here](https://lame.sourceforge.io/download.php)).

#### origins

My old car had an old version of bluetooth which made all audio sound kind of muddy, but it had a USB port you could plug a thumb drive into. I decided to plug an external USB HDD into it, but it turns out the car only supported mp3 files and no flac. I have a few albums in flac format on my computer, which obviously need converting so I created this script to simply convert all flac files in a directory.