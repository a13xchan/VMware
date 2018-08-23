<#
 .SYNOPSIS
    Simple script to copy Virtaul Center roles beween differen Virutal Centers.
    Based on: https://psvmware.wordpress.com/2012/07/19/clone-roles-between-two-virtual-center-servers/

 .DESCRIPTION
    Executable on PowerShell Command Line. 
    Prerequtements: VMware PowerCLI and vDocumentation installed. 
    VMware PowerCLI: https://blogs.vmware.com/PowerCLI/2017/08/updating-powercli-powershell-gallery.html

    During the executen there might some error (red) messages.
    The script dosen't buffer preveliges which are not found in the destination Virtaul Center.
    As example, if you installed DELL extentins (addin) in the source Virtual Center
    and the destination Virutal Center dosen't have this extentions (addin) installed.
    The Script will come with erros, like:

    Get-VIPrivilege : 2/20/2018 11:03:52 AM	Get-VIPrivilege		VIPrivilege with id 'Dell.Deploy-Provisioning.Deploy' was not found using the specified filter(s).	
    At line:11 char:86
    + ... dPrivilege (Get-VIPrivilege -id (Get-VIPrivilege -Role (Get-VIRole -N ...
    +                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (:) [Get-VIPrivilege], VimException
    + FullyQualifiedErrorId : Core_OutputHelper_WriteNotFoundError,VMware.VimAutomation.ViCore.Cmdlets.Commands.PermissionManagement.GetVIPrivilege
    
    All previlages which are default or also found at the destination Virutal Center will get created.
    Only the once which are not found in the destination Virutal Center will not get applied.

 .PARAMETER credFileName
    Name of your Credential file.
    You can create this file by using:
    Get-Credential | Export-Clixml [PathToYourFile]\[NameOfTheFile].clixml

 .PARAMETER credPathName
    Path to your Cedential file.

 .PARAMETER VcNameCopyFrom
    Source Virutal Center FQDN.

 .PARAMETER VcNameCopyTo
    Destination Virtual Center FQDN.

 .PARAMETER RoleToCopy
    Role in the source Virutal Center you like to copy to destination.
#>

$credFileName = "adminph-de.clixml"
$credPathName = "W:\Scripts\VMware\CREDENTIALS" 
$VcNameCopyFrom = "scn-vc01-p.dk.flsmidth.net"
$VcNameCopyTo = "cph-vc03-p.dk.flsmidth.net"
$RoleToCopy = "FLS_READ-VM-CUSTOMIZATION"

# Don't change anything below this line if you don't know what you do.
$UserCred = Import-clixml "$credPathName\$credFileName"
Connect-VIServer -Server $VcNameCopyFrom, $VcNameCopyTo -Credential $UserCred -WarningAction 0
New-VIRole -name $RoleToCopy -Server $VcNameCopyTo
Set-VIRole -role (Get-VIRole -Name $RoleToCopy -Server $VcNameCopyTo) -AddPrivilege (Get-VIPrivilege -id (Get-VIPrivilege -Role (Get-VIRole -Name $RoleToCopy -server $VcNameCopyFrom) | %{$_.id}) -server $VcNameCopyTo)
Disconnect-VIServer -Server $VcNameCopyFrom,$VcNameCopyTo -Confirm:$false