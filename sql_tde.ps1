param ($instance = $( Read-Host "Enter Instance name" ),
       $username = $( Read-Host "Enter username" ),
       $password = $( Read-Host -AsSecureString "Enter password" )
       )

$pw=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))


$status_query="SELECT DB_NAME(database_id) AS DatabaseName, encryption_state, encryption_state_desc =
                CASE encryption_state
                   WHEN '0' THEN 'No database encryption key present, no encryption'
                   WHEN '1' THEN 'Unencrypted'
                   WHEN '2' THEN 'Encryption in progress'
                   WHEN '3' THEN 'Encrypted'
                   WHEN '4' THEN 'Key change in progress'
                   WHEN '5' THEN 'Decryption in progress'
                   WHEN '6' THEN 'Protection change in progress (The certificate or asymmetric key that is encrypting the database encryption key is being changed.)'
                   ELSE 'No Status'
                   END,
                   percent_complete,encryptor_thumbprint, encryptor_type,create_date,regenerate_date FROM sys.dm_database_encryption_keys
                   WHERE database_id>4"


function status
{
    try{
        $status1= Invoke-Sqlcmd -Query "SELECT  sys.databases.name AS DatabaseName, sys.asymmetric_keys.name AS KEK, sys.databases.is_encrypted
                                        FROM ((sys.dm_database_encryption_keys
                                        INNER JOIN sys.asymmetric_keys ON sys.asymmetric_keys.thumbprint = sys.dm_database_encryption_keys.encryptor_thumbprint)
                                        INNER JOIN sys.databases ON sys.databases.database_id = sys.dm_database_encryption_keys.database_id)
                                        WHERE is_encrypted=1" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop | format-table

        $status2=Invoke-Sqlcmd -Query "SELECT name AS DatabaseName, is_encrypted
                                       FROM sys.databases
                                       WHERE database_id>4 AND is_encrypted=0" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop | format-table
     }

    catch{
        Write-Host $_.Exception.message
    }

    Write-Output $status1, $status2

}


function enable_tde
{
    try{
        $DB=$( Read-Host "Enter database name" )

        $status=Invoke-Sqlcmd -Query "$status_query" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


        foreach($item in $status)
        {
            if($item.Databasename -like $DB -and $status.encryption_state -eq '1')
                {
                    Invoke-Sqlcmd -Query "ALTER DATABASE $DB
                                          SET ENCRYPTION ON ;
                                          GO"-ServerInstance $instance -username $username -password $pw -ErrorAction Stop
                    Write-Host "Enabled TDE for $DB"
                    return
                }
        }

        $status2=Invoke-Sqlcmd -Query "SELECT name, is_encrypted
                                       FROM sys.databases
                                       WHERE database_id>4" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop

        foreach($item in $status2)
        {
            if($item.name -like $DB -and $item.is_encrypted -eq 0)
            {
                $MK = $( Read-Host "Do you have a KEK/master key & want to use the same(y/n)?" )
                if($MK -eq 'y' -or $MK -eq 'Y')
                {
                    $keys = Invoke-Sqlcmd -Query "Use master
                                                  Select name  FROM sys.asymmetric_keys" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop | format-table
                    Write-Output $keys

                    $KEK = $( Read-Host "Enter the name of your KEK/master-key from above provided set of keys" )
                    $AES = $( Read-Host "Enter the algorithm you want to use to create DEK(AES_128/AES_192/AES_256 )" )

                    Invoke-Sqlcmd -Query "USE $DB
                                          CREATE DATABASE ENCRYPTION KEY
                                          WITH ALGORITHM  = $AES
                                          ENCRYPTION BY SERVER ASYMMETRIC KEY $KEK ;" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    Invoke-Sqlcmd -Query "ALTER DATABASE $DB
                                          SET ENCRYPTION ON ;
                                          GO"-ServerInstance $instance -username $username -password $pw -ErrorAction Stop

                    Write-Host "Enabled TDE for $DB"
                    return

                }
                elseIf($MK -eq 'n' -or $MK -eq 'N')
                {
                    $KEK = $( Read-Host "Enter the name to create KEK/master-key" )
                    $SO = $( Read-Host "Enter the name to create Provider key" )
                    $apikey=$( Read-Host -AsSecureString "Enter api-key to create credential" )
                    Write-Host "Api-Key entered"
                    $provs = Invoke-Sqlcmd -Query "Use master
                                                   Select name  FROM sys.cryptographic_providers" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop | format-table
                    Write-Output $provs
                    $prov=$( Read-Host "Enter the name of your cryptographic provider from above provided set of providers" )

                    $api_key=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apikey))

                    $cred = $( Read-Host "Enter the name to create credential" )
                    $Id = $( Read-Host "Enter Identity to create credential" )

                    Invoke-Sqlcmd -Query "CREATE CREDENTIAL $cred
                                          WITH IDENTITY = '$Id',
                                          SECRET = '$api_key'
                                          FOR CRYPTOGRAPHIC PROVIDER $prov ;
                                          GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop

                    $login_name = $( Read-Host "Enter login name to map credential" )
                    $login_name= '"' + $login_name +'"'

                    Invoke-Sqlcmd -Query "ALTER LOGIN $login_name
                                          ADD CREDENTIAL $cred;
                                          GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    $RSA = $( Read-Host "Enter the algorithm you want to use to create KEK(RSA_4096/RSA_3072/RSA_2048/RSA_1024/RSA_512 )" )

                    Invoke-Sqlcmd -query "USE master ;
                                          GO
                                          CREATE ASYMMETRIC KEY $KEK
                                          FROM PROVIDER $prov
                                          WITH ALGORITHM = $RSA,
                                          PROVIDER_KEY_NAME = '$SO';
                                          GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    $db_cred = $( Read-Host "Enter the name to create db engine credential" )
                    $db_id = $( Read-Host "Enter Identity to create db engine credential" )
                    Invoke-Sqlcmd -Query "USE master ;
                                          GO
                                          CREATE CREDENTIAL $db_cred
                                          WITH IDENTITY = '$db_id',
                                          SECRET = '$api_key'
                                          FOR CRYPTOGRAPHIC PROVIDER $prov" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    $login = $( Read-Host "Enter the name to create db engine login" )
                    Invoke-Sqlcmd -Query "CREATE LOGIN $login
                                          FROM ASYMMETRIC KEY $KEK ;
                                          GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    Invoke-Sqlcmd -Query "ALTER LOGIN $login
                                          ADD CREDENTIAL $db_cred ;
                                          GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    $AES = $( Read-Host "Enter the algorithm you want to use to create DEK(AES_128/AES_192/AES_256 )" )

                    Invoke-Sqlcmd -Query "USE $DB
                                          CREATE DATABASE ENCRYPTION KEY
                                          WITH ALGORITHM  = $AES
                                          ENCRYPTION BY SERVER ASYMMETRIC KEY $KEK ;" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                    Invoke-Sqlcmd -Query "ALTER DATABASE $DB
                                          SET ENCRYPTION ON ;
                                          GO"-ServerInstance $instance -username $username -password $pw -ErrorAction Stop

                    Write-Host "Enabled TDE for $DB"
                    return

                }

                else
                {
                    Write-Host "Please make an appropriate choice(y/n)"
                    return
                }
            }

            ElseIf($item.name -like $DB -and $item.is_encrypted -eq 1)
            {
                Write-Host “Database is already encrypted”
                return
            }

        }

        Write-Host “No such database exist”
    }

    catch{
        Write-Host $_.Exception.message
    }

}


function rotation
{
    try{
        $DB=$( Read-Host "Enter database name" )

        $status= Invoke-Sqlcmd -Query "SELECT name, is_encrypted
                                FROM sys.databases
                                WHERE database_id>4" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop

        foreach($item in $status)
        {
            if($item.name -like $DB -and $item.is_encrypted -eq 1)
            {

                $prov = (Invoke-Sqlcmd -Query "SELECT sys.cryptographic_providers.name
                                              FROM (((sys.dm_database_encryption_keys
                                              INNER JOIN sys.asymmetric_keys ON sys.asymmetric_keys.thumbprint = sys.dm_database_encryption_keys.encryptor_thumbprint)
                                              INNER JOIN sys.databases ON sys.databases.database_id = sys.dm_database_encryption_keys.database_id AND sys.databases.name='$DB')
                                              INNER JOIN sys.cryptographic_providers ON sys.cryptographic_providers.guid = sys.asymmetric_keys.cryptographic_provider_guid)" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop)[0]

                $apikey=$( Read-Host -AsSecureString "Enter api-key to create credential" )
                Write-Host "Api-Key entered"
                $api_key=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apikey))

                $KEK = $( Read-Host "Enter the name to create KEK/master-key" )
                $SO = $( Read-Host "Enter the name to create Provider key" )
                $RSA = $( Read-Host "Enter the algorithm you want to use to create KEK(RSA_2048/RSA_1024 )" )

                Invoke-Sqlcmd -Query "USE master ;
                                      GO
                                      CREATE ASYMMETRIC KEY $KEK
                                      FROM PROVIDER $prov
                                      WITH ALGORITHM = $RSA,
                                      PROVIDER_KEY_NAME = '$SO' ;
                                      GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop

                $db_cred = $( Read-Host "Enter the name to create db engine credential" )
                $db_id = $( Read-Host "Enter Identity to create db engine credential" )

                Invoke-Sqlcmd -Query "USE master ;
                                      GO
                                      CREATE CREDENTIAL $db_cred
                                      WITH IDENTITY = '$db_id',
                                      SECRET = '$api_key'
                                      FOR CRYPTOGRAPHIC PROVIDER $prov" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                $login = $( Read-Host "Enter the name to create db engine login" )

                Invoke-Sqlcmd -Query "CREATE LOGIN $login
                                      FROM ASYMMETRIC KEY $KEK ;
                                      GO" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                Invoke-Sqlcmd -Query "ALTER LOGIN $login
                                      ADD CREDENTIAL $db_cred;" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop


                Invoke-Sqlcmd -Query "USE $DB;
                                      ALTER DATABASE ENCRYPTION KEY
                                      ENCRYPTION BY SERVER ASYMMETRIC KEY $KEK;" -ServerInstance $instance -username $username -password $pw -ErrorAction Stop

                Write-Host "Rotation completed for $DB"
                return

            }

            ElseIf($item.name -like $DB -and $item.is_encrypted -eq 0)
            {
                Write-Host “Database is not encrypted”
                return
            }

        }

        Write-Host “No such database exist”
    }

    catch{
        Write-Host $_.Exception.message
    }

}

function Show-Menu
{
     param (
           [string]$Title = ‘Menu’
     )
     cls
     Write-Host “================ $Title ================”

     Write-Host “1: Press ‘1’ to check status.”
     Write-Host “2: Press ‘2’ to Enable TDE.”
     Write-Host “3: Press ‘3’ for Rotation.”
     Write-Host “Q: Press ‘Q’ to quit.”
}

do
{
     Show-Menu
     $input = Read-Host “Please make a selection”
     switch ($input)
     {
           ‘1’ {
                status
           } ‘2’ {
                enable_tde
           } ‘3’ {
                rotation
           } ‘q’ {
                return
           }
     }
     pause
}
until ($input -eq ‘q’)