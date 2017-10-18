﻿#Requires -Version 3.0

#region help text

<#
.SYNOPSIS
	Removes a hosting connection in a Citrix XenDesktop 7.xx Site.
.DESCRIPTION
	Removes either:
	
		A hosting connection and all resource connections in a Citrix 
		XenDesktop 7.xx Site if there are any active provisioning tasks, or
		
		A resource connection within a hosting connection that has the active task(s).
	
	This script requires at least PowerShell version 3 but runs best in version 5.

	You do NOT have to run this script on a Controller. This script was developed 
	and run from a Windows 10 VM.
	
	You can run this script remotely using the -AdminAddress (AA) parameter.
	
	This script supports all versions of XenApp/XenDesktop 7.xx. 
	
	Logs all actions to the Configuration Logging database.
	
	If there are no active tasks for the hosting connection selected, 
	then NOTHING is removed from the Site. The script will state there were
	no active tasks found and end.
	
	Supports WhatIf and Confirm. 
	
.PARAMETER AdminAddress
	Specifies the address of a XenDesktop controller the PowerShell snapins will connect to. 
	This can be provided as a host name or an IP address. 
	This parameter defaults to LocalHost.
	This parameter has an alias of AA.
.PARAMETER ResourceConnectionOnly
	Specifies that only the resource connection that has the active tasks 
	should be deleted.
	Do NOT delete the hosting connection or the Broker's hypervisor connection.
	This parameter defaults to False which means all resource and hosting 
	connections are deleted that have an active task.
	This parameter has an alias of RCO.
.EXAMPLE
	PS C:\PSScript > .\Remove-HostingConnection.ps1
	
	Display a lit of all hosting connections in the Site.
	Once a hosting connection is selected, all provisioning tasks are stopped and removed.
	Once all provising tasks are removed, the resource connections and hosting connection are removed.
	The computer running the script for the AdminAddress.
.EXAMPLE
	PS C:\PSScript > .\Remove-HostingConnection.ps1 -AdminAddress DDC715
	
	Display a lit of all hosting connections in the Site.
	Once a hosting connection is selected, all provisioning tasks are stopped and removed.
	Once all provisioning tasks are removed, the resource connections and hosting connection are removed.
	DDC715 for the AdminAddress.
.EXAMPLE
	PS C:\PSScript > .\Remove-HostingConnection.ps1 -ResourceConnectionOnly
	
	Display a lit of all hosting connections in the Site.
	Once a hosting connection is selected, all provisioning tasks are stopped and removed.
	Once all provisioning tasks are removed, only the resource connections are removed.
	The computer running the script for the AdminAddress.
.EXAMPLE
	PS C:\PSScript > .\Remove-HostingConnection.ps1 -RCO -AA DDC715
	
	Display a lit of all hosting connections in the Site.
	Once a hosting connection is selected, all provisioning tasks are stopped and removed.
	Once all provising tasks are removed, only the resource connections are removed.
	DDC715 for the AdminAddress.
.INPUTS
	None.  You cannot pipe objects to this script.
.OUTPUTS
	No objects are output from this script.
.LINK
	http://carlwebster.com/unable-delete-citrix-xenappxendesktop-7-xx-hosting-connection-resource-currently-active-background-action/
.NOTES
	NAME: Remove-HostingConnection.ps1
	VERSION: 1.00
	AUTHOR: Carl Webster
	LASTEDIT: October 18, 2017
#>

#endregion

#region script parameters
[CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = "High")]

Param(
	[parameter(Mandatory=$False)] 
	[ValidateNotNullOrEmpty()]
	[Alias("AA")]
	[string]$AdminAddress="LocalHost",

	[parameter(Mandatory=$False)] 
	[ValidateNotNullOrEmpty()]
	[Alias("RCO")]
	[switch]$ResourceConnectionOnly=$False

	)
#endregion

#region script change log	
#webster@carlwebster.com
#@carlwebster on Twitter
#Sr. Solutions Architect, Choice Solutions, LLC
#http://www.CarlWebster.com
#Created on September 26, 2017

# Version 1.0 released to the community on November 2, 2017
#endregion

#region script setup
Set-StrictMode -Version 2

#force on
$SaveEAPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
$ConfirmPreference = "High"

Function Check-NeededPSSnapins
{
	Param([parameter(Mandatory = $True)][alias("Snapin")][string[]]$Snapins)

	#Function specifics
	$MissingSnapins = @()
	[bool]$FoundMissingSnapin = $False
	$LoadedSnapins = @()
	$RegisteredSnapins = @()

	#Creates arrays of strings, rather than objects, we're passing strings so this will be more robust.
	$loadedSnapins += get-pssnapin | % {$_.name}
	$registeredSnapins += get-pssnapin -Registered | % {$_.name}

	ForEach($Snapin in $Snapins)
	{
		#check if the snapin is loaded
		If(!($LoadedSnapins -like $snapin))
		{
			#Check if the snapin is missing
			If(!($RegisteredSnapins -like $Snapin))
			{
				#set the flag if it's not already
				If(!($FoundMissingSnapin))
				{
					$FoundMissingSnapin = $True
				}
				#add the entry to the list
				$MissingSnapins += $Snapin
			}
			Else
			{
				#Snapin is registered, but not loaded, loading it now:
				Add-PSSnapin -Name $snapin -EA 0 *>$Null
			}
		}
	}

	If($FoundMissingSnapin)
	{
		Write-Warning "Missing Windows PowerShell snap-ins Detected:"
		$missingSnapins | % {Write-Warning "($_)"}
		Return $False
	}
	Else
	{
		Return $True
	}
}

If(!(Check-NeededPSSnapins "Citrix.Broker.Admin.V2",
"Citrix.ConfigurationLogging.Admin.V1",
"Citrix.Host.Admin.V2",
"Citrix.MachineCreation.Admin.V2"))

{
	#We're missing Citrix Snapins that we need
	$ErrorActionPreference = $SaveEAPreference
	Write-Error "`nMissing Citrix PowerShell Snap-ins Detected, check the console above for more information. 
	`nAre you sure you are running this script against a XenDesktop 7.x Controller? 
	`n`nIf you are running the script remotely, did you install Studio or the PowerShell snapins on $($env:computername)?
	`n
	`nThe script requires the following snapins:
	`n
	`n
	Citrix.Broker.Admin.V2
	Citrix.ConfigurationLogging.Admin.V1
	Citrix.Host.Admin.V2
	Citrix.MachineCreation.Admin.V2
	`n
	`n`nThe script will now close.
	`n`n"
	Exit
}
#endregion

#region script part 1
Write-Host
$HostingConnections = (Get-BrokerHypervisorConnection -AdminAddress $AdminAddress).Name

If($? -and $Null -ne $HostingConnections)
{
	Write-Host "List of hosting connections:"
	Write-Host ""
	ForEach($Connection in $HostingConnections)
	{
		Write-Host "`t$Connection"
	}
	#$HostingConnections
	Write-Host ""

	If($ResourceConnectionOnly -eq $True)
	{
		$RemoveThis = Read-Host "Which hosting connection has the resource connection you want to remove"
	}
	Else
	{
		$RemoveThis = Read-Host "Which hosting connection do you want to remove"
	}

	If($HostingConnections -Contains $RemoveThis)
	{
		If($ResourceConnectionOnly -eq $True)
		{
			Write-Host "This script will remove all active tasks and a single resource connection for $RemoveThis"
		}
		Else
		{
			Write-Host "This script will remove all active tasks and hosting connections for $RemoveThis"
		}
	}
	Else
	{
		Write-Host "Invalid hosting connection entered. Script will exit."
		Exit
	}
}
ElseIf($? -and $Null -eq $HostingConnections)
{
	Write-Host "There were no hosting connections found. Script will now close."
	Exit
}
Else
{
	Write-Host "Unable to retrieve hosting connections. Script will now close."
	Exit
}
#endregion

#region script part 2
#clear errors in case of issues
$Error.Clear()

Write-Host -ForegroundColor Yellow "Retrieving Host Connection $RemoveThis"
$HostingUnits = Get-ChildItem -AdminAddress $AdminAddress -path 'xdhyp:\hostingunits' | Where-Object {$_.HypervisorConnection.HypervisorConnectionName -eq $RemoveThis} 

If($? -and $Null -ne $HostingUnits)
{
	#save the HostingUnitUid to use later
	$SavedHostingUnitUid = ""
	#Get-ProvTask with Active -eq True only returns one result regardless of the number of active tasks
	Write-Host -ForegroundColor Yellow "Retrieving Active Provisioning Tasks"
	
	If($HostingUnits -is[array])
	{
		#multiple hosting connections found
		ForEach($HostingUnit in $HostingUnits)
		{
			$ActiveTask = $Null
			$Results = Get-ProvTask -AdminAddress $AdminAddress | Where-Object {$_.HostingUnitUid -eq $HostingUnit.HostingUnitUid -and $_.Active -eq $True} 4>$Null

			#only one hosting connection should have an active task since you can only select one via the Studio wizard
			If($? -and $Null -ne $Results)
			{
				$ActiveTask += $Results
				$SavedHostingUnitUid = $HostingUnit.HostingUnitUid
			}
		}
	}
	Else
	{
		#only one hosting connection found
		$ActiveTask = Get-ProvTask -AdminAddress $AdminAddress | Where-Object {$_.HostingUnitUid -eq $HostingUnits.HostingUnitUid -and $_.Active -eq $True} 4>$Null
		$SavedHostingUnitUid = $HostingUnits.HostingUnitUid
	}
}
ElseIf($? -and $Null -eq $HostingUnits)
{
	#we should never get here
	Write-Host "There were no hosting connections found. You shouldn't be here! Script will close."
	Write-Host "If you get this message, please email webster@carlwebster.com" -ForegroundColor Red
	$error
	Exit
}
Else
{
	#we should never get here
	Write-Host "Unable to retrieve hosting connections. You shouldn't be here! Script will close."
	Write-Host "If you get this message, please email webster@carlwebster.com" -ForegroundColor Red
	$error
	Exit
}
#endregion

#region script part 3
If($? -and $Null -ne $ActiveTask)
{
	While($? -and $Null -ne $ActiveTask)
	{
		#Get-ProvTask $True only returns one task ragrdless of the number of tasks that exist
		Write-Host -ForegroundColor Yellow "Active task $($ActiveTask.TaskId) found"

		###############
		#STOP THE TASK#
		###############
		
		$Succeeded = $False #will indicate if the high level operation was successful
		
		# Log high level operation start.
		$HighLevelOp = Start-LogHighLevelOperation -Text "Stop-ProvTask TaskId $($ActiveTask.TaskId)" `
		-Source "Remove-HostingConnection Script" `
		-OperationType AdminActivity `
		-TargetTypes "TaskId $($ActiveTask.TaskId)" `
		-AdminAddress $AdminAddress
		
		Try
		{
			If($PSCmdlet.ShouldProcess($ActiveTask.TaskId,'Stop Provisioning Task'))
			{
				Stop-ProvTask -TaskId $ActiveTask.TaskId -LoggingId $HighLevelOp.Id -AdminAddress $AdminAddress -EA 0 4>$Null
			}
			
			If($?)
			{
				$Succeeded = $True
				Write-Host -ForegroundColor Yellow "Stopped task $($ActiveTask.TaskId)"
			}
		}
		
		Catch
		{
			Write-Warning "Unable to stop task $($ActiveTask.TaskId)"
		}
		
		Finally
		{
			# Log high level operation stop, and indicate its success
			Stop-LogHighLevelOperation -HighLevelOperationId $HighLevelOp.Id -IsSuccessful $Succeeded -AdminAddress $AdminAddress			
		}
		
		#################
		#REMOVE THE TASK#
		#################

		$Succeeded = $False #will indicate if the high level operation was successful

		# Log high level operation start.
		$HighLevelOp = Start-LogHighLevelOperation -Text "Remove-ProvTask TaskId $($ActiveTask.TaskId)" `
		-Source "Remove-HostingConnection Script" `
		-OperationType AdminActivity `
		-TargetTypes "TaskId $($ActiveTask.TaskId)" `
		-AdminAddress $AdminAddress
		
		Try
		{
			If($PSCmdlet.ShouldProcess($ActiveTask.TaskId,'Remove Provisioning Task'))
			{
				Remove-ProvTask -TaskId $ActiveTask.TaskId -LoggingId $HighLevelOp.Id -AdminAddress $AdminAddress -EA 0 4>$Null
			}
			
			If($?)
			{
				$Succeeded = $True
				Write-Host -ForegroundColor Yellow "Removed task $($ActiveTask.TaskId)"
			}
		}
		
		Catch
		{
			Write-Warning "Unable to remove task $($ActiveTask.TaskId)"
		}
		
		Finally
		{
			# Log high level operation stop, and indicate its success
			Stop-LogHighLevelOperation -HighLevelOperationId $HighLevelOp.Id -IsSuccessful $Succeeded -AdminAddress $AdminAddress			
		}
		
		#keep looping until all active tasks are found, stopped and removed
		$ActiveTask = Get-ProvTask -AdminAddress $AdminAddress | Where-Object {$_.hostingunit -eq $RemoveThis.HostingUnitUid -and $_.Active -eq $True}
	}
	
	#all tasks have been stopped and removed so now the hosting and resource connections can be removed
	
	#get all resource connections as there can be more than one per hosting connection
	$ResourceConnections = Get-ChildItem -AdminAddress $AdminAddress -path 'xdhyp:\hostingunits' | Where-Object {$_.HypervisorConnection.HypervisorConnectionName -eq $RemoveThis}
	
	If($? -and $Null -ne $ResourceConnections)
	{
		ForEach($ResourceConnection in $ResourceConnections)
		{
			If(($ResourceConnectionOnly -eq $False) -or ($ResourceConnectionOnly -eq $True -and $ResourceConnection.HostingUnitUid -eq $SavedHostingUnitUid))
			{
				################################
				#REMOVE THE RESOURCE CONNECTION#
				################################
				
				$Succeeded = $False #will indicate if the high level operation was successful

				# Log high level operation start.
				$HighLevelOp = Start-LogHighLevelOperation -Text "Remove-Item xdhyp:\HostingUnits\$ResourceConnection" `
				-Source "Remove-HostingConnection Script" `
				-OperationType ConfigurationChange `
				-TargetTypes "xdhyp:\HostingUnits\$ResourceConnection" `
				-AdminAddress $AdminAddress
				
				Try
				{
					If($PSCmdlet.ShouldProcess("xdhyp:\HostingUnits\$ResourceConnection",'Remove resource connection'))
					{
						Remove-Item -AdminAddress $AdminAddress -path "xdhyp:\HostingUnits\$ResourceConnection" -LoggingId $HighLevelOp.Id -EA 0		
					}
					
					If($?)
					{
						$Succeeded = $True
						Write-Host -ForegroundColor Yellow "Removed resource connection item xdhyp:\HostingUnits\$ResourceConnection"
					}
				}
				
				Catch
				{
					Write-Warning "Unable to remove resource connection item xdhyp:\HostingUnits\$ResourceConnection"
				}
				
				Finally
				{
					# Log high level operation stop, and indicate its success
					Stop-LogHighLevelOperation -HighLevelOperationId $HighLevelOp.Id -IsSuccessful $Succeeded -AdminAddress $AdminAddress			
				}
			}
		}
	}
	ElseIf($? -and $Null -eq $ResourceConnections)
	{
		Write-Host "There were no Resource Connections found"
	}
	Else
	{
		Write-Host "Unable to retrieve Resource Connections"
	}
	
	#If $ResourceConnectionOnly is $True then do NOT delete the hosting connection or broker hypervisor connection
	If($ResourceConnectionOnly -eq $False)
	{
		###############################
		#REMOVE THE HOSTING CONNECTION#
		###############################

		$Succeeded = $False #will indicate if the high level operation was successful

		# Log high level operation start.
		$HighLevelOp = Start-LogHighLevelOperation -Text "Remove-Item xdhyp:\Connections\$RemoveThis" `
		-Source "Remove-HostingConnection Script" `
		-OperationType ConfigurationChange `
		-TargetTypes "xdhyp:\Connections\$RemoveThis" `
		-AdminAddress $AdminAddress
		
		Try
		{
			If($PSCmdlet.ShouldProcess("xdhyp:\Connections\$RemoveThis",'Remove hosting connection'))
			{
				Remove-Item -AdminAddress $AdminAddress -path "xdhyp:\Connections\$RemoveThis" -LoggingId $HighLevelOp.Id -EA 0		
			}
			
			If($?)
			{
				$Succeeded = $True
				Write-Host -ForegroundColor Yellow "Removed hosting connection item xdhyp:\Connections\$RemoveThis"
			}
		}
		
		Catch
		{
			Write-Warning "Unable to remove hosting connection item xdhyp:\Connections\$RemoveThis"
		}
		
		Finally
		{
			# Log high level operation stop, and indicate its success
			Stop-LogHighLevelOperation -HighLevelOperationId $HighLevelOp.Id -IsSuccessful $Succeeded -AdminAddress $AdminAddress			
		}
		
		#########################################
		#REMOVE THE BROKER HYPERVISOR CONNECTION#
		#########################################

		$Succeeded = $False #will indicate if the high level operation was successful

		# Log high level operation start.
		$HighLevelOp = Start-LogHighLevelOperation -Text "Remove-BrokerHypervisorConnection $RemoveThis" `
		-Source "Remove-HostingConnection Script" `
		-OperationType ConfigurationChange `
		-TargetTypes "$RemoveThis" `
		-AdminAddress $AdminAddress
		
		Try
		{
			If($PSCmdlet.ShouldProcess($RemoveThis,'Remove broker hypervisor connection'))
			{
				Remove-BrokerHypervisorConnection -Name $RemoveThis -AdminAddress $AdminAddress -LoggingId $HighLevelOp.Id -EA 0	
			}
			
			If($?)
			{
				$Succeeded = $True
				Write-Host -ForegroundColor Yellow "Removed Broker Hypervisor Connection $RemoveThis"
			}
		}
		
		Catch
		{
			Write-Warning "Unable to remove Broker Hypervisor Connection $RemoveThis"
		}
		
		Finally
		{
			# Log high level operation stop, and indicate its success
			Stop-LogHighLevelOperation -HighLevelOperationId $HighLevelOp.Id -IsSuccessful $Succeeded -AdminAddress $AdminAddress			
		}

	}
	##################
	#SCRIPT COMPLETED#
	##################

	Write-Host "Script completed"
	
}
ElseIf($? -and $Null -eq $ActiveTask)
{
	Write-Host "There were no active tasks found"
}
Else
{
	Write-Host "Unable to retrieve active tasks"
}
#endregion