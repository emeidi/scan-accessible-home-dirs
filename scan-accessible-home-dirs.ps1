if($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Output "ERROR: This script requires PowerShell Version 5.0 (parameter -Depth for Get-ChildItem). Cannot continue."
    exit
}

# Add all UNCs to the servers and directories you want to check here
$uncs = @()
$uncs += "\\server-01.tld\homes"
$uncs += "\\server-02.tld\homes"
$uncs += "\\server-03.tld\homes"
$uncs += "\\server-04.tld\homes"
$uncs += "\\server-05.tld\homes"

# If this value is set to something other than -1, the script will only look at the first n folders it encounters (good for the first test runs and debugging)
$checkFolderCount = -1
#$checkFolderCount = 15

$numUncs = $uncs.Count
Write-Output "Scanning a total of $numUncs UNC paths ..."

$readable = @()
$totalCount = 0
ForEach($unc in $uncs) {
    Write-Output "Looking at UNC $unc ..."

    $pattern = '\\\\([a-zA-Z0-9\-\.]+)\\'
    $found = $unc -match $pattern
    if($found) {
        $uncServer = $matches[1]
        $relPath = $unc -replace "\\\\$uncServer\\", ""

        #Write-Output $relPath
    }
    else {
        Write-Output "WARNING: '$unc' does not match pattern '$pattern'"
        continue
    }

    $shares = (net view $uncServer) -match '\sDisk\s' -replace '\s+Disk.*'

    #$excludes = @("folder-01","folder-02","folder-03","folder-04","folder-05")
    $excludes = @()

    $share = "$unc"

    Write-Output "Looking at share $share ..."

    $path = "$unc"
    Write-Output "Full Path: $path"

    if($excludes.Contains($share)) {
        Write-Output "WARNING: Skipping share '$share' because it is listed in excludes. Skipping."
        continue
    }

    $shareOut = $share
    $shareOut = $shareOut -replace '\\','-'
    $shareOut = $shareOut -replace '--','-'
    $shareOut = $shareOut -replace '^-',''
    Write-Output "shareOut: $shareOut"

    $random = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})
    $tempDrive = "${random}_mount"

    Write-Output "Mounting at $tempDrive ..."
    New-PSDrive -Name $tempDrive -PSProvider FileSystem -Root $path

    $errors = @()

    $subdirPath = "${tempDrive}:\"
    Write-Output "Get-ChildItem '$subdirPath'"
    Get-ChildItem -recurse $subdirPath -ea silentlycontinue -ErrorVariable +errors -depth 1 | Out-Null

    $numErrors = $errors.Count
    Write-Output "Encountered $numErrors access denied errors (the higher the number the better)"
    Write-Output ""

    $unreadable = @()
    $errors | Foreach-Object {
        #Write-Host $_

        $pattern = "'(.*)'"
        $found = $_ -match $pattern
        if(!$found) {
            Write-Output "WARNING: '$_' does not match pattern '$pattern'"
            continue
        }

        $unreadablePath = $matches[1]
        #Write-Output "unreablePath: $unreadablePath"

        $unreadable += $unreadablePath
    }
    #Write-Output $unreadable

    # Get a listing of all folders in the selected network folder
    $subdirs = Get-ChildItem -Path "${tempDrive}:\" | Where-Object {($_.PsIsContainer)}
    #Write-Output $subdirs

    $folderCount = 0
    foreach($subdirObj in $subdirs) {
        $totalCount = $totalCount + 1

        $folderCount = $folderCount + 1

        if(($checkFolderCount -gt -1) -and ($folderCount -gt $checkFolderCount)) {
            Write-Output "Skipping after $folderCount folders"
            break
        }

        $subdir = $subdirObj.FullName

        #Write-Output "Checking whether unreadable contains '$subdir'"

        if($unreadable.Contains($subdir)) {
            Write-Output "INFO: $subdir not readable"
            continue
        }

        Write-Output "ERROR: $subdir readable"
        Write-Output ""

        $readable += $subdir
    }

    Write-Output "Done with $tempDrive."

    Write-Output "Unmounting ..."
    Remove-PSDrive -Name $tempDrive

    Write-Output "Done unmounting."
    Write-Output ""

    continue
}

$readableCount = $readable.Count

if($readableCount -lt 1) {
    Write-Output "Congratulations: No accessible user directories found"
    Write-Output ""
    exit
}

Write-Output ""
Write-Output "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
Write-Output "ATTENTION: ACCESSIBLE DIRECTORIES FOUND - PLEASE VERIFY"
Write-Output "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
Write-Output $readable
Write-Output "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
Write-Output "Total accessible: $readableCount of $totalCount directories"
Write-Output "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
Write-Output ""
Write-Output ""

exit
