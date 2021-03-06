# initialize
$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent    
pushd $PSScriptRoot
if (Get-Module MapInfoTools)
{
    Remove-Module MapInfoTools
}
Import-Module -name "$PSScriptRoot\MapInfoTools" -verbose

# remove old data
del .\testdata\*.tab 
del seamless.*
del .\Oversiktskartan\seamless.*

# test tfw2tab
dir .\testdata\*.tfw | Convert-WorldFile2Tab -CoordSys "CoordSys Earth Projection 8, 112, `"m`", 15.8082777778, 0, 1, 1500000, 0"

# test create seamless
dir .\testdata\*.tab | New-SeamlessTable -Target .\seamless.tab

# test create seamless for oversiktskartan
dir .\Oversiktskartan\*.tab | New-SeamlessTable -Target .\Oversiktskartan\seamless.tab -nocleanup

# deinitialize
popd

Write-Host "Done!"
