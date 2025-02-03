[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory=$false)][System.UInt32]$Threads
)

$validVersions = @("20b", "30", "40", "41", "50", "51")

$fileList = $File.OpenText()
while ($null -ne ($line = $fileList.ReadLine())) {
    if ($line -match '^\s*$' -or $line -match '^\s*//') {
        continue
    }

    $line = $line.Trim()
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($line)
    $version = $null

    # Determine version based on filename suffix
    if ($fileName -match '(2x|30|40|41|50|51)$') {
        $suffix = $matches[1]
        switch ($suffix) {
            '2x'   { $version = '20b' }
            '30'   { $version = '30' }
            '40'   { $version = '40' }
            '41'   { $version = '41' }
            '50'   { $version = '50' }
            '51'   { $version = '51' }
            default {
                Write-Warning "Unrecognized suffix: $suffix in file $fileName. Skipping."
                continue
            }
        }
    } else {
        Write-Warning "Filename $fileName does not have a recognized version suffix. Skipping."
        continue
    }

    if ($version -notin $validVersions) {
        Write-Warning "Invalid version $version for file $fileName. Skipping."
        continue
    }

    # Build and execute the ShaderCompile command
    $compileArgs = @("/O", "3", "-ver", $version, "-shaderpath", $File.DirectoryName, $line)
    if ($Threads -ne 0) {
        $compileArgs = @("/O", "3", "-threads", $Threads, "-ver", $version, "-shaderpath", $File.DirectoryName, $line)
    }

    & "$PSScriptRoot\ShaderCompile" $compileArgs
}
$fileList.Close()
