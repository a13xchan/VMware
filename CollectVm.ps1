$credFileName = "adminph-de.clixml"
$credPathName = "W:\Scripts\VMware\CREDENTIALS" 
$UserCred = Import-clixml "$credPathName\$credFileName"
$VCenterName = "scn-vc01-p.dk.flsmidth.net"

Connect-VIServer -Server $VCenterName -Credential $UserCred -WarningAction 0
$report = @()
foreach($vm in Get-View -Server $VCenterName -ViewType Virtualmachine){
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
    $vms.Portgroup = Get-View -Id $vm.Network -Property Name | select -ExpandProperty Name
    $vms.VMHost = Get-View -Id $vm.Runtime.Host -property Name | select -ExpandProperty Name
    $vms.ProvisionedSpaceGB = [math]::Round($vm.Summary.Storage.UnCommitted/1GB,2)
    $vms.UsedSpaceGB = [math]::Round($vm.Summary.Storage.Committed/1GB,2)
    $vms.Datastore = $vm.Config.DatastoreUrl[0].Name
    $vms.FaultTolerance = $vm.Runtime.FaultToleranceState
    $vms.SnapshotName = &{$script:snaps = Get-Snapshot -VM $vm.Name; $script:snaps.Name -join ','}
    $vms.SnapshotDate = $script:snaps.Created -join ','
    $vms.SnapshotSizeGB = $script:snaps.SizeGB
    $Report += $vms
    Write-Host $Vm.Name
}
$report | export-csv -path ("W:\Temp\" + $VCenterName + "_VmList.csv") -NoTypeInformation -UseCulture
Disconnect-VIServer -Server $VCenterName -Confirm:$false