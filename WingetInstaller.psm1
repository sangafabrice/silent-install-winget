$WINGET_LATEST_RELEASE = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
$WINGET_DEPENDENCY_PATTERN = 'Microsoft.VCLibs.140.00.UWPDesktop_*__8wekyb3d8bbwe.appx'
$WINGET_VERSION_PATTERN = '(?<Version>\d+\.\d+\.\d+(\.\d+)?)'

function Get-WingetDownloadInfo {
    try {
        (Invoke-WebRequest -Uri $WINGET_LATEST_RELEASE -ErrorAction Stop).Content |
        ConvertFrom-Json |
        Select-Object -Property @{
            Name = 'Version';
            Expression = {
                $_.tag_name -match $WINGET_VERSION_PATTERN | Out-Null
                $Matches.Version
            }
        },@{
            Name = 'Link';
            Expression = {
                $_.assets.browser_download_url |
                ForEach-Object {
                    switch -wildcard ($_) {
                        '*.appx' {$_}
                        '*.appxbundle' {$_}
                        '*.msix' {$_}
                        '*.msixbundle' {$_}
                    }
                }
            }
        } -Unique
    }
    catch {}
}

function Compare-WingetDownloadInfo ($Version) {
    ($(try {winget --version} catch {}) ?? 'v0.0.0') -match $WINGET_VERSION_PATTERN | Out-Null
    ([version] $Version) -gt ([version] $Matches.Version)
}

function Save-Winget ($Link) {
    try {
        $LocalName = ([uri] $Link).Segments[-1]
        Start-BitsTransfer -Source $Link -Destination $LocalName -ErrorAction Stop
        [PSCustomObject] @{
            MsixPath = (Resolve-Path -Path $LocalName 2> $null)?.Path
        }
    }
    catch {}
}

function Install-Winget ($SaveCopyTo) {
    $SaveCopyToExist = ($null -ne $SaveCopyTo) -and (Test-Path -Path $SaveCopyTo)
    Get-WingetDownloadInfo |
    ForEach-Object {
        if (Compare-WingetDownloadInfo -Version $_.Version) {
            if ($SaveCopyToExist) {
                $DlLocalArchive = "$($SaveCopyTo -replace '\\$')\v$($_.Version).*"
                if (Test-Path -Path $DlLocalArchive) {
                    $_.Link = (Resolve-Path -Path $DlLocalArchive).Path
                }
            }
            Save-Winget -Link $_.Link |
            ForEach-Object {
                Import-Module -Name Appx -UseWindowsPowerShell -WarningAction SilentlyContinue
                Add-AppxPackage -Path $_.MsixPath -DependencyPath (Get-ChildItem -Filter $WINGET_DEPENDENCY_PATTERN).FullName -ForceUpdateFromAnyVersion
                Remove-Module -Name Appx -Force
                if ($SaveCopyToExist -and !(Test-Path -Path $DlLocalArchive) -and ($null -ne $_.MsixPath)) {
                    Remove-Item -Path "$SaveCopyTo\*" -Recurse -Force
                    Copy-Item -Path $_.MsixPath -Destination $DlLocalArchive -Force
                }
                Remove-Item -Path $_.MsixPath -Recurse -Force
            }
            New-Item -Path $_.Version -ItemType File | Out-Null
        }
    }
}

Export-ModuleMember -Function 'Install-Winget'