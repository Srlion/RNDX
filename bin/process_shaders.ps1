[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$false)][System.UInt32]$Threads
)

if ($Version -notin @("20b", "30", "40", "41", "50", "51")) {
	return
}

$fileList = $File.OpenText()
while ($null -ne ($line = $fileList.ReadLine())) {
	if ($line -match '^\s*$' -or $line -match '^\s*//') {
		continue
	}

	# Create a vmt file from template for each shader if it doesn't exist
	$baseName = [System.IO.Path]::GetFileNameWithoutExtension($line) -replace "_ps2x$", ""
	$templatePath = Join-Path $PSScriptRoot "../../../materials/effects/shaders/template.vmt"
	$vmtPath = Join-Path $PSScriptRoot "../../../materials/effects/shaders/$baseName.vmt"

	if ((Test-Path $templatePath) -and -not (Test-Path $vmtPath)) {
		$content = Get-Content $templatePath -Raw
		$content = $content -replace '\$pixshader\s+"[^"]*"', "`$pixshader `"$baseName`_ps20`""
		Set-Content -Path $vmtPath -Value $content
	}

	if ($Threads -ne 0) {
		& "$PSScriptRoot\ShaderCompile" "/O" "3" "-threads" $Threads "-ver" $Version "-shaderpath" $File.DirectoryName $line
		continue
	}

	& "$PSScriptRoot\ShaderCompile" "/O" "3" "-ver" $Version "-shaderpath" $File.DirectoryName $line
}
$fileList.Close()
