<# 
.SYNOPSIS
    This script creates a seamless table for the input .TAB file(s).
.DESCRIPTION
    This script creates a seamless table for the input .TAB file(s). Seamless tables
    are special mapinfo .TAB files that acts as an index for the contained files.
.LINK 
    This script leans on tab2tab.exe from http://mitab.maptools.org/
    This script was written using information from http://www.mail-archive.com/mapinfo-l@lists.directionsmag.com/msg28998.html
    This script is included in http://mapinfotools.codeplex.com/ 
.EXAMPLE      
    DIR *.tab | & C:\SCRIPTS\NEW-SEAMLESSTABLE.PS1 -Target seamless.tab
    This code snippet will produce a seamless table for all the .TFW files in the current directory.
.PARAMETER target 
    The name of the seamless table (.TAB file).
.PARAMETER nocleanup
    If specified the intermediate .MIF file (and ofcourse .MID file) that are used to produce final
    seamless .TAB file will not be deleted.
#>


param(
    [string[]]$files = @(),
    [string]$target = "out.tab",
    [switch]$nocleanup
)

begin
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent    
    . $PSScriptRoot\external.ps1    
    $tab2tab = join-path $PSScriptRoot "tab2tab.exe"
    
    add-type -assemblyname "System.Drawing"    
    
    filter get-region-definition
    {
        # get content of tab file
        $tabFileName = $_
        $tabContent = Get-Content $tabFileName
        
        # get control points from tab file            
        $controlPoints = $tabContent | % { 
            if ($_ -match "\((\d+),(\d+)\) \((\d+),(\d+)\) Label") { 
                new-object psobject -property @{ GeoX=[double]$matches[1]; GeoY=[double]$matches[2]; ImgX=[double]$matches[3]; ImgY=[double]$matches[4] };
            } 
        }              

        # calculate transormation coefficients, geo = img * s + m
        $controlPointsX = $controlPoints | sort -property ImgX -unique
        $controlPointsY = $controlPoints | sort -property ImgY -unique
                    
        $sx = ($controlPointsX[0].GeoX - $controlPointsX[1].GeoX)  / ($controlPointsX[0].ImgX - $controlPointsX[1].ImgX) 
        $sy = ($controlPointsY[0].GeoY - $controlPointsY[1].GeoY)  / ($controlPointsY[0].ImgY - $controlPointsY[1].ImgY) 
        $mx = ($controlPointsX[0].GeoX - $controlPointsX[0].ImgX * $sx)
        $my = ($controlPointsY[0].GeoY - $controlPointsY[0].ImgY * $sy)

        # get bounds of embedded tif file
        $tifFile = $tabContent | % { if ($_ -match "File `"([^`"]+)`"") { $matches[1] } }
        $tifFile = join-path (split-path $tabFileName) $tifFile 
        $tifImg = new-object System.Drawing.Bitmap -ArgumentList $tifFile 
        $xmin = $mx
        $ymax = $my
        $xmax = ($tifImg.Width-1) * $sx + $mx
        $ymin = ($tifImg.Height-1) * $sy + $my
        
        # return text block defining rectangle
@"
Region 1
  5
$xmin $ymin
$xmin $ymax
$xmax $ymax
$xmax $ymin
$xmin $ymin
 Pen (1,2,0)
 Brush (2,16777215,16777215)        
"@    
    }
}

process
{
    $files += $_
}

end
{
    # check preconditions
    if ($files.Count -eq 0)    
    {
        Write-Warning "No input files"
        return
    }
    
    # init
    $tf = [System.IO.FileInfo]$target
    $coordsys = (Get-Content $files[0]) | ? { $_ -match "CoordSys Earth Projection" }  
    $layername = split-path -leaf $tf.BaseName 
    $targetRootDir = split-path $tf | resolve-path
    
    # create mid file
    $mid = join-path $targetRootDir ($tf.BaseName + ".mid")    
    $files | % { $fn = Get-RelativePath $targetRootDir $_; "`"$fn`",`"$layername`"" } | out-file -encoding ascii $mid
    
    # create mif file
    $mif = join-path $targetRootDir ($tf.BaseName + ".mif")
@"
Version 450
Charset "WindowsLatin1"
Delimiter ","
$coordsys
Columns 2
   Table Char(100)
   Description Char(25)
Data

"@ | out-file -encoding ascii $mif       
    $files | get-region-definition | out-file -encoding ascii -append $mif 
    
    # convert mif/mid to tab
    & $tab2tab $mif $target
    
    # append meta data to tab file
@"
ReadOnly
begin_metadata
"\IsSeamless" = "TRUE"
"\IsReadOnly" = "FALSE"
end_metadata
"@ | out-file -encoding ascii -append $target
           
    # cleanup
    if (!$nocleanup)
    {
        del $mif
        del $mid
    }
}
