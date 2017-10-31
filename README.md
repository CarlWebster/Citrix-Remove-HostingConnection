# Remove-HostingConnection
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
	
	Supports WhatIf and Confirm thanks to @adbertram for his clear and simple articles.
	https://4sysops.com/archives/the-powershell-whatif-parameter/
	https://4sysops.com/archives/confirm-confirmpreference-and-confirmimpact-in-powershell/
	
	Thanks to Michael B. Smith for the code review. @essentialexch on Twitter
	
	******************************************************************************
	*   WARNING             WARNING      	       WARNING             WARNING   *
	******************************************************************************
	
	Do not run this script when there are valid active provisioning tasks processing.

	Because of the way the Get-ProvTask cmdlet works, this script retrieves the
	first task where the Active property is TRUE, regardless of whether the task
	is a current task or an old task left in the system.

	This script will remove the first active task it finds and then, depending on
	the -ResourceConnectionOnly switch, will attempt to delete all resource 
	connections in the specified hosting connection and then attempt to delete the 
	specified hosting connection.
	
	******************************************************************************
	*   WARNING             WARNING      	       WARNING             WARNING   *
	******************************************************************************
	
