<#
 .SYNOPSIS
    Gathers Information of your Virtual Center and store it into a *.cvs file
    Including all running VMs with all necessary to know settings.

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

$OutputPathName = "C:\EXPORTS"
$DNSServerName = "ams-ad-dc01-p"
$DNSZone = "dk.flsmidth.net"
$VcNamePattern = "*-VC??-?"

# Dont' change anything below this line if you don't know what you do.

if (!(Test-Path $env:userprofile\$env:username.clixml)) {
    Get-Credential | Export-Clixml $env:userprofile\$env:username.clixml
   }

#Create and switch to Work Directory
if (!(Test-Path $OutputPathName)) {
    New-Item -ItemType Directory -Path $OutputPathName
}
Set-Location $OutputPathName
New-Item -ItemType Directory -Path (Get-Date -format "yyyy-MM-dd_hh-mm-ss")
Set-Location ($OutputPathName + "\" + (Get-Date -format "yyyy-MM-dd_hh-mm-ss"))
$RootPathName =  ($OutputPathName + "\" + (Get-Date -format "yyyy-MM-dd_hh-mm-ss"))

#Select Credentials
$UserCred = Import-clixml $env:userprofile\$env:username.clixml

#Close all open connections
$serverlist = $global:DefaultVIServer
if($serverlist -eq $null) {write-host "No connected servers."} else {
    Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false
}

$outFileHW = Join-Path $RootPathName "Hardware_merged.csv"
$outFileConf = Join-Path $RootPathName "Configuration_merged.csv"
$outFileVMs = Join-Path $RootPathName "VMs_merged.csv"
$outFileAZ = Join-Path $RootPathName "AzureResources_merged.csv"
$InputPatternAZ = "AzureResources*.csv"
$InputPatternHW = "*Hardware.csv"
$InputPatternConf = "*Configuration.csv"
$InputPatternVMs = "*VMs.csv"

Function MergeFiles($dir, $OutFile, $Pattern) {
 # Build the file list
 $FileList = Get-ChildItem $dir -include $Pattern -rec -File
 # Get the header info from the first file
 Get-Content $fileList[0] | Select-Object -First 1 | Out-File -FilePath $outfile -Encoding ascii
 # Cycle through and get the data (sans header) from all the files in the list
 foreach ($file in $filelist)
 {
   Get-Content $file | Select-Object -Skip 1 | Out-File -FilePath $outfile -Encoding ascii -Append
 }
}

#Gathering VCenter Server form DNS
$VCS = Get-DnsServerResourceRecord -ZoneName $DNSZone -ComputerName $DNSServerName | where-object {$_.Hostname -like $VcNamePattern} | Select-Object -ExpandProperty HostName | sort

#Generate reports
ForEach ($VC in $VCS) {
  if (Connect-VIServer -Server $VC.ToString() -Credential $UserCred -Force -WarningAction 0) {
   if (!(Test-Path $VC.ToString())) {
    New-Item -type directory -name $VC.ToString()
   }
   Get-ESXInventory -ExportCSV -folderPath $VC.ToString()

   $report = @()
   ForEach($vm in Get-View -Server $VC.ToString() -ViewType Virtualmachine){
       $vms = "" | Select-Object VMName, Hostname, IPAddress, OS, Boottime, VMState, TotalCPU, CPUAffinity,
            CPUHotAdd, CPUShare, CPUlimit, OverallCpuUsage, CPUreservation, TotalMemory, MemoryShare, MemoryUsage,
            MemoryHotAdd, MemoryLimit, MemoryReservation, Swapped, Ballooned, Compressed, TotalNics, ToolsStatus,
            ToolsVersion, HardwareVersion, TimeSync, CBT, Portgroup, VMHost, ProvisionedSpaceGB, UsedSpaceGB, Datastore,
            Notes, FaultTolerance, SnapshotName, SnapshotDate, SnapshotSizeGB
       $vms.VMName = $vm.Name
       $vms.Hostname = $vm.guest.hostname
       $vms.IPAddress = $vm.guest.ipAddress
       $vms.OS = $vm.Config.GuestFullName
       $vms.Boottime = $vm.Runtime.BootTime
       $vms.VMState = $vm.summary.runtime.powerState
       $vms.TotalCPU = $vm.summary.config.numcpu
       $vms.CPUAffinity = $vm.Config.CpuAffinity
       $vms.CPUHotAdd = $vm.Config.CpuHotAddEnabled
       $vms.CPUShare = $vm.Config.CpuAllocation.Shares.Level
       $vms.TotalMemory = $vm.summary.config.memorysizemb
       $vms.MemoryHotAdd = $vm.Config.MemoryHotAddEnabled
       $vms.MemoryShare = $vm.Config.MemoryAllocation.Shares.Level
       $vms.TotalNics = $vm.summary.config.numEthernetCards
       $vms.OverallCpuUsage = $vm.summary.quickStats.OverallCpuUsage
       $vms.MemoryUsage = $vm.summary.quickStats.guestMemoryUsage
       $vms.ToolsStatus = $vm.guest.toolsstatus
       $vms.ToolsVersion = $vm.config.tools.toolsversion
       $vms.TimeSync = $vm.Config.Tools.SyncTimeWithHost
       $vms.HardwareVersion = $vm.config.Version
       $vms.MemoryLimit = $vm.resourceconfig.memoryallocation.limit
       $vms.MemoryReservation = $vm.resourceconfig.memoryallocation.reservation
       $vms.CPUreservation = $vm.resourceconfig.cpuallocation.reservation
       $vms.CPUlimit = $vm.resourceconfig.cpuallocation.limit
       $vms.CBT = $vm.Config.ChangeTrackingEnabled
       $vms.Swapped = $vm.Summary.QuickStats.SwappedMemory
       $vms.Ballooned = $vm.Summary.QuickStats.BalloonedMemory
       $vms.Compressed = $vm.Summary.QuickStats.CompressedMemory
       $vms.Portgroup = Get-View -Id $vm.Network -Property Name | Select-Object -ExpandProperty Name
       $vms.VMHost = Get-View -Id $vm.Runtime.Host -property Name | Select-Object -ExpandProperty Name
       $vms.ProvisionedSpaceGB = [math]::Round($vm.Summary.Storage.UnCommitted/1GB,2)
       $vms.UsedSpaceGB = [math]::Round($vm.Summary.Storage.Committed/1GB,2)
       $vms.Datastore = $vm.Config.DatastoreUrl[0].Name
       $vms.FaultTolerance = $vm.Runtime.FaultToleranceState
       #$vms.SnapshotName = &{$script:snaps = Get-Snapshot -VM $vm.Name; $script:snaps.Name -join ','}
       #$vms.SnapshotDate = $script:snaps.Created -join ','
       #$vms.SnapshotSizeGB = $script:snaps.SizeGB
       $Report += $vms
       Write-Host $vm.Name
          }
   $report | export-csv -path ($RootPathName + "\" + $VC.ToString() + "\" + "Inventory"+ (Get-Date -format "yyyy-MM-ddThh-mm-ss") + "VMs.csv") -NoTypeInformation -UseCulture

   Disconnect-VIServer -Server $VC.ToString() -Confirm:$false
  }
 }

 MergeFiles -dir $RootPathName -OutFile $outFileHW -Pattern $InputPatternHW
 MergeFiles -dir $RootPathName -OutFile $outFileConf -Pattern $InputPatternConf
 MergeFiles -dir $RootPathName -OutFile $outFileVMs -Pattern $InputPatternVms

#Add Azure Information
#Get-AzureRmResource | Export-CSV -path ($RootPathName + "\" + "AzureResources.csv") -NoTypeInformation -UseCulture

$SubList = Get-AzureRmSubscription

ForEach ($Sub in $SubList) {
    $SubSelected = Select-AzureRmSubscription -Subscription $Sub.Name
    Get-AzureRmResource | Export-CSV -path ($RootPathName + "\" + "AzureResources_" + $Sub.Name + ".csv") -NoTypeInformation -UseCulture
}
  
MergeFiles -dir $RootPathName -OutFile $outFileAZ -Pattern $InputPatternAZ

Get-AzureRmSubscription | Export-Csv Export-CSV -path ($RootPathName + "\" + "AzureSubscriptions.csv") -NoTypeInformation -UseCulture

$acctKey = ConvertTo-SecureString -String "qJUPDm1Nddxw5ZLCrbsFa6rwZFyq1adqeoOnBJnlEbe/qcPfiSqUaWhfYqH2PnCWXBvuaPoRu9CyBhX0r1J/nQ==" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\amsphdemisc01", $acctKey
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\amsphdemisc01.file.core.windows.net\import-csv-files" -Credential $credential -Persist

Copy-Item -Path ($RootPathName + "\*.csv") -Destination Z:\ -Force

Remove-PSDrive -Name Z
# SIG # Begin signature block
# MIIFzQYJKoZIhvcNAQcCoIIFvjCCBboCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVFALHS88kMGTs8HEbqT4aLG4
# k8OgggNXMIIDUzCCAjugAwIBAgIQEttTvOk9o59GIKDy1FPlxDANBgkqhkiG9w0B
# AQsFADArMSkwJwYDVQQDDCBhZG1pbnBoQGZsc21pZHRoLm9ubWljcm9zb2Z0LmNv
# bTAeFw0xODA5MTIyMTA5NTJaFw0xOTA5MTIyMTI5NTJaMCsxKTAnBgNVBAMMIGFk
# bWlucGhAZmxzbWlkdGgub25taWNyb3NvZnQuY29tMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAn6d1MX3Og/HWQMRFbIA0lP6IrS8L6/WjDR5TzcoKWU8j
# W+/3OzD+oqt4B36WzhyJzWkiAwAbLUnYGRhsfpLQYfKQJlZP9RFP1Xadl5PbA9Md
# 2J8909gyT6aXupxMe6PZC3LnFUemYPyHysqUcDZ68rfXjz7/EXSBFnHhypAx+NsQ
# 5Fwu556XxIS7eixl7ClADJOSVVKM+cw/x0IHfMKzm03rulPBDzGSChH8GbS/Xpmj
# HiRCaIWvlHY6jJkkJipWp9w+cpY7Pq8J2mAaINQ5WLbGC111FeSNamGcQ1ZMQZGm
# TWEi9Xnh2H3FT6ftNc/YVkbuod/EoOhtoycRtCVB6QIDAQABo3MwcTAOBgNVHQ8B
# Af8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwKwYDVR0RBCQwIoIgYWRtaW5w
# aEBmbHNtaWR0aC5vbm1pY3Jvc29mdC5jb20wHQYDVR0OBBYEFOw6NYug9kMkviGb
# eaUsHGBa8itHMA0GCSqGSIb3DQEBCwUAA4IBAQAx+FTW5T7t8LZvdRSz5jL7gpwo
# kuga2wgtYKwru3W6jlIHCXJ5bwlmyxk5uLypfljc2cAQg2kGlLPPsXK9fpAtvxAV
# tEpM0iqDi5Ub1UpjhLdBBMKCT4yb+QnbFtKaQX3YTNoEEBqyS0G2zfcVur73cl7+
# +1hj3oY1IT5yTddi9crZ3iCIGHaFDzGqRmI79HH3+I/gX01iu0BOUSgzFXIekrbp
# VJML9ST40u7FXQsChAJxI3tw8JUpm9eE8UMJg7k/u2HXVULgGVNW0zwVhyUYW/XD
# ZMwCYcRJqwVdMFiqwHFxm+t1oDxsJR7EXYIXDYZ/KjJnKVzvGN3j4jpYVUNBMYIB
# 4DCCAdwCAQEwPzArMSkwJwYDVQQDDCBhZG1pbnBoQGZsc21pZHRoLm9ubWljcm9z
# b2Z0LmNvbQIQEttTvOk9o59GIKDy1FPlxDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUaCBhhEJo
# 5wrH8BWJGC4gFzIMyVkwDQYJKoZIhvcNAQEBBQAEggEAVBoNrjMbjmD8YBfp1Nsj
# NSFTsGJuwBYTey/CMak64xz+vm756IaTFHPpqt2LkrHCRynhRGrvTvwUyBWWeDle
# jATUlViNha9t7puwUhsMIUu0rsOPz+P1JkI7xDSG824Wo+xPmQ7fAAIuwH77/oCe
# ZTgs8WyoteTpqj43gbhc6mE+m3cHK8yw/C1dOKoYpjBBv9YEXnk5GkeH3Z7cj2Ue
# lXAlHo76C8ThK4LsHfo7BvCNk1mWi1pzRzwQI4uTODoxr53nGnfYX7iYAyd1IQPz
# jzbYvScLI+zCjlfXntl7GgKbACj4Q+pptdWEWmVCAJMIXbLNJvRXPRcfprS/tCJ8
# zA==
# SIG # End signature block
