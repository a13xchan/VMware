 <#
 .SYNOPSIS
    Gathers Information of your Virtual Center and store it into a *.cvs file

 .DESCRIPTION
    Executable on PowerShell Command Line. 
    Prerequtements: VMware PowerCLI and vDocumentation installed. 
    VMware PowerCLI: https://blogs.vmware.com/PowerCLI/2017/08/updating-powercli-powershell-gallery.html
    vDocumentation: https://github.com/arielsanchezmora/vDocumentation

 .PARAMETER credFileName
    Name of your Credential file.
    You can create this file by using:
    Get-Credential | Export-Clixml [PathToYourFile]\[NameOfTheFile].clixml

 .PARAMETER credPathName
    Path to your Cedential file.

 .PARAMETER OutputPathName
    Output directory for the result of the script.

 .PARAMETER DNSServerName
    DNS Server in your Domain where the script can gather the FQDNs of your Virtual Centers.

 .PARAMETER DNSZone
    DNS Zone where the script should find the FQDNs of your Virtual Centers.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.

  .PARAMETER VcNamePattern
    A naming pattern for your Virutal Centern host names.
    in the examle below it will find all hosts in the DNS Zoone that maches the naming pattern: *-VC??-?
    Example: SCN-VC01-P or VirtualCenter-VC99-T or VMware-VC01-P etc.

#>

$credFileName = "myUser.clixml"
$credPathName = "C:\Scripts\VMware\CREDENTIALS" 
$OutputPathName = "C:\EXPORTS"
$DNSServerName = "myDnsServer"
$DNSZone = "myDNSZone.local"
$VcNamePattern = "*-VC??-?"

# Dont' change anything below this line if you don't know what you do.
$RootPathName = ($OutputPathName + "_" + (Get-Date -format "yyyy-MM-dd_hh-mm-ss"))
$outFileHW = Join-Path $RootPathName ((Get-Date -format "yyyy-MM-dd_hh-mm-ss") + "_" + "merged_Hardware.csv")
$outFileConf = Join-Path $RootPathName ((Get-Date -format "yyyy-MM-dd_hh-mm-ss")+ "_" + "merged_Configuration.csv")
$InputPatternHW = "*Hardware.csv"
$InputPatternConf = "*Configuration.csv"

Function MergeFiles($dir, $OutFile, $Pattern) {
 # Build the file list
 $FileList = Get-ChildItem $dir -include $Pattern -rec -File
 # Get the header info from the first file
 Get-Content $fileList[0] | Select-Object -First 2 | Out-File -FilePath $outfile -Encoding ascii
 # Cycle through and get the data (sans header) from all the files in the list
 foreach ($file in $filelist)
 {
   Get-Content $file | Select-Object -Skip 1 | Out-File -FilePath $outfile -Encoding ascii -Append
 }
}

#Gathering VCenter Server form DNS
$VCS = Get-DnsServerResourceRecord -ZoneName $DNSZone -ComputerName $DNSServerName | where-object {$_.Hostname -like $VcNamePattern} | Select-Object -ExpandProperty HostName | sort

#Switch to work directory
New-Item -ItemType Directory -Path $RootPathName
cd $RootPathName

#Select Credentials
$UserCred = Import-clixml "$credPathName\$credFileName"

#Generate reports
ForEach ($VC in $VCS) {
  if (Connect-VIServer -Server $VC.ToString() -Credential $UserCred -WarningAction 0) {
   if (!(Test-Path $VC.ToString())) {
    New-Item -type directory -name $VC.ToString()
   }
   Get-ESXInventory -ExportCSV -folderPath $VC.ToString()
   Disconnect-VIServer -Server $VC.ToString() -Confirm:$false
  }
 }

 MergeFiles -dir $RootPathName -OutFile $outFileHW -Pattern $InputPatternHW
 MergeFiles -dir $RootPathName -OutFile $outFileConf -Pattern $InputPatternConf