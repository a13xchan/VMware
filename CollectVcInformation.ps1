$credFileName = "adminph-de.clixml"
$credPathName = "C:\Scripts\cred" 
$OutputPathName = "C:\EXPORTS"
$DNSServerName = "ams-ad-dc01-p.dk.flsmidth.net"
$DNSZone = "dk.flsmidth.net"
$VcNamePattern = "*-VC??-?"

# Dont' change anything below this line if you don't know what you do.

#Create and switch to Work Directory
if (!(Test-Path $OutputPathName)) {
    New-Item -ItemType Directory -Path $OutputPathName
}
Set-Location $OutputPathName
New-Item -ItemType Directory -Path (Get-Date -format "yyyy-MM-dd_hh-mm-ss")
Set-Location ($OutputPathName + "\" + (Get-Date -format "yyyy-MM-dd_hh-mm-ss"))
$RootPathName =  ($OutputPathName + "\" + (Get-Date -format "yyyy-MM-dd_hh-mm-ss"))

#Select Credentials
$UserCred = Import-clixml "$credPathName\$credFileName"

#Close all open connections
$serverlist = $global:DefaultVIServer
if($serverlist -eq $null) {write-host "No connected servers."} else {
    Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false
}

$outFileHW = Join-Path $RootPathName "Hardware_merged.csv"
$outFileConf = Join-Path $RootPathName "Configuration_merged.csv"
$outFileVMs = Join-Path $RootPathName "VMs_merged.csv"
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
Get-AzureRmResource | Export-CSV -path ($RootPathName + "\" + "AzureResources.csv") -NoTypeInformation -UseCulture

$acctKey = ConvertTo-SecureString -String "qJUPDm1Nddxw5ZLCrbsFa6rwZFyq1adqeoOnBJnlEbe/qcPfiSqUaWhfYqH2PnCWXBvuaPoRu9CyBhX0r1J/nQ==" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\amsphdemisc01", $acctKey
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\amsphdemisc01.file.core.windows.net\import-csv-files" -Credential $credential -Persist

Copy-Item -Path ($RootPathName + "\*.csv") -Destination Z:\ -Force

Remove-PSDrive -Name Z