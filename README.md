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
	
	Thanks to Michael B. Smith for the code review.
