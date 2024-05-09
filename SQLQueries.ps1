
try
{	
	#get the list of distributed servers
	$listofServers = Get-Content "D:\Users\PKathirv\Documents\serverlist.txt"

	#connect to the database presents in the central server
	$primaryserverInstance = "ITSUSRAWSP10163"
	$primarydatabase = "master"
	$primaryconnectionString = "Server=$primaryserverInstance;Database=$primarydatabase;Integrated Security=True;"

	$primaryconnection = New-Object System.Data.SqlClient.SqlConnection
	$primaryconnection.ConnectionString = $primaryconnectionString
	$primaryconnection.Open()

	#create tables in the database of the primary server
	$createTableQuery = @"
		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SA_is_disabled')
		BEGIN
		CREATE TABLE SA_is_disabled (
			ServerName VARCHAR(25)
		);
		END;
		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'guest_account_enabled')
		BEGIN
		CREATE TABLE guest_account_enabled (
   			ServerName VARCHAR(25)
		);
		END;
		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'policy_is_enforced')
		BEGIN
		CREATE TABLE policy_is_enforced (
   			ServerName VARCHAR(25),
			LoginName VARCHAR(25)
		);
		END;
		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'password_expiry_enabled')
		BEGIN
		CREATE TABLE password_expiry_enabled (
   			ServerName VARCHAR(25),
			LoginName VARCHAR(25)
		);
		END;
"@

	# Execute the SQL Command to Create the Table
	$primarycommand = New-Object System.Data.SqlClient.SqlCommand
	$primarycommand.connection = $primaryconnection
	$primarycommand.commandtext = $createTableQuery
	$tablecreation = $primarycommand.ExecuteNonQuery()

	#list of queries to execute and get results
	$sqlqueries = @(
		#check if sa account is disabled or not   
		"SELECT is_disabled from sys.sql_logins where name = 'sa'", #if 0 proceed

		# check if the guest account is enabled or disabled
		"SELECT hasdbaccess from sys.sql_logins where name = 'guest'", #1 proceed

		#check if password policy is enforced or not   
		"SELECT @@SERVERNAME as ServerName, name as LoginName from sys.sql_logins where is_policy_checked = 0", #0 proceed

		#check if the Password Expiry is enabled or not  
		"SELECT @@SERVERNAME as ServerName, name as LoginName from sys.sql_logins where is_expiration_checked = 1" #1 proceed
	)

	#connect with each server
	foreach($server in $listofServers)
	{
		try{
		    Invoke-Command -computername $server -ScriptBlock{
			    #establish the sql connection 
			    $serverInstance = $server
			    $database = "master"
			    $connectionString = "Server=$serverInstance;Database=$database;Integrated Security=True;"

			    $connection = New-Object System.Data.SqlClient.SqlConnection
			    $connection.ConnectionString = $connectionString
			    $connection.Open()

			    $command = New-Object System.Data.SqlClient.SqlCommand
			    $command.connection = $connection

			    #execute query for sa check
			    $command.commandtext = $($sqlqueries[0])
			    $result_sa_disabled = $command.ExecuteNonQuery()
			    if($result_sa_disabled -eq 0)
			    {
			    	$columnName = "ServerName"
			    	$value = $server
			    	$tableName = "SA_is_disabled"
			    	$insertQuery = @"
			    		INSERT INTO $tableName ($columnName)
			    		VALUES ('$value')
"@  
			    	$primarycommand.commandtext = $insertQuery
			    	$primarycommand.ExecuteNonQuery()
			    }

			#execute query for guest check
			$command.commandtext = $($sqlqueries[1])
			$result_guest_enabled = $command.ExecuteNonQuery()
			if($result_guest_enabled -eq 1)
			{
				$columnName = "ServerName"
				$value = $server
				$tableName = "guest_account_enabled"
				$insertQuery = @"
					INSERT INTO $tableName ($columnName)
					VALUES ('$value')
"@
				$primarycommand.commandtext = $insertQuery
				$primarycommand.ExecuteNonQuery()
			}

# 			#execute query for policy check
# 			$command.commandtext = $($sqlqueries[2])
# 			$result_pwd_enforced = $command.ExecuteNonQuery()			
# 			if($result_pwd_enforced -ne $null)
# 			{
# 				$tableName = "policy_is_enforced"
# 				$insertQuery = @"
# 					INSERT INTO $tableName (Column1, Column2)
# 					VALUES (@Value1, @Value2)
# "@
				
# 				foreach ($row in $result_pwd_enforced) {
#     			$insertParams = @{
#        				 Value1 = $row.Column1
#         			 Value2 = $row.Column2
#     			}
#     			Invoke-SqlCmd -Query $insertQuery -Parameters $insertParams -ServerInstance $primaryserverInstance -Database $primarydatabase -QueryTimeout 3 -EncryptConnection -TrustServerCertificate
# 				}
# 			}

# 			$result_pwdexpiry_enabled = Invoke-SqlCmd -Query $sqlqueries[3] -ServerInstance $serverInstance -Database $database -QueryTimeout 3 -EncryptConnection -TrustServerCertificate
# 			if($result_pwdexpiry_enabled -ne $null)
# 			{
# 				$tableName = "password_expiry_enabled"
# 				$insertQuery = @"
# 					INSERT INTO $tableName (Column1, Column2)
# 					VALUES (@Value1, @Value2)
# "@
				
# 				foreach ($row in $result_pwd_enforced) {
#     			$insertParams = @{
#        				 Value1 = $row.Column1
#         			 Value2 = $row.Column2
#     			}
#     			Invoke-SqlCmd -Query $insertQuery -Parameters $insertParams -ServerInstance $primaryserverInstance -Database $primarydatabase -QueryTimeout 3 -EncryptConnection -TrustServerCertificate
# 				}
# 			}
			    $connection.close()	
		    }	
	    }
        catch
	    {
		    Write-Host "An error occurred: $_" 
	    }
	}


	$primaryconnection.close()
}
catch
{
	Write-Host "An error occurred: $_" 
}