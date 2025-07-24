## ##############Disclaimer###############

`This is a sample script. Running this script in your production environment without prior testing is not advisable. Fortanix is not liable or responsible for any damage caused by the execution of the script in your environment.`

## Prerequisite:

### Installation

FortanixKmsClient.msi installs the Fortanix DSM CNG Provider, as well as the EKM provider and the PKCS#11 library.

#### Installation Prerequisites

If Extensible Key Management is not supported or enabled in the SQL server edition, then run the following commands:
```
sp_configure 'show advanced', 1
GO
RECONFIGURE
GO
sp_configure 'EKM provider enabled', 1
GO
RECONFIGURE
GO
```

### Windows Server Client Configuration

The Fortanix KMS Server URL and proxy information are configured in the Windows registry for the local machine or current user with C:\Program Files\Fortanix\KmsClient\FortanixKmsClientConfig.exe.

For example, to configure the Fortanix KMS Server URL for the local machine, run:

FortanixKmsClientConfig.exe machine --api-endpoint {DSM_URL}

To configure the Fortanix KMS Server URL for the current user, run:

FortanixKmsClientConfig.exe user --api-endpoint {DSM_URL}

To configure proxy information, add --proxy http://proxy.com or --proxy none to unconfigure proxy.

### Create Cryptographic Provider

Use the correct location of the EKM DLL.
```
CREATE CRYPTOGRAPHIC PROVIDER EKM_Prov
FROM FILE = 'C:\Program Files\Fortanix\KmsClient\FortanixKmsEkmProvider.dll' ;
```
### Note:

Create a group and an app in {DSM_URL}.

Use login which has sysadmin role & mapped to database you want to alter.

## Script Execution:

To execute this script import module SQLPS in your system using command: `Import-Module sqlps`

```
.\sql_tde.ps1
Enter Instance name: test
Enter username: testuser
Enter password:
or
.\sql_tde.ps1 -instance test -username testuser -password testpassword
```
WARNING: Passing your password via -password is not very secure.It is better to enter your password interactively.

The `sql_tde.ps1` script will ask for the following user inputs:

* **Instance name**
     enter the name of the SQL Server instance they want to connect to.
* **Username**
     enter the username for connecting to the SQL Server instance.
* **Password** (entered securely)
     enter their password securely for authentication.
* **Menu selection**:
     choose an option from the displayed menu (1, 2, 3, or Q).
    * '1' for "check status"
        Displays the encryption status of databases on the specified SQL Server instance.
    * '2' for "Enable TDE"
        Initiates the process to enable Transparent Data Encryption for a chosen database.
    * '3' for "Rotation"
        Initiates the process to rotate the Key Encryption Key (KEK) for an encrypted database.
    * 'Q' to quit
        Exits the script.
* If enabling TDE (menu option '2'):
    * **Database name**
         enter the name of the database on which they want to enable TDE.
    * "Do you have a MEK/master encryption key & want to use the same (y/n)?"
        Asks the user if they want to use an existing Master Encryption Key (MEK) or create a new one.
    * If 'y' or 'Y':
        * "Enter the name of your MEK/master encryption key from above provided set of keys"
            Uses the specified existing MEK to encrypt the Data Encryption Key (DEK).
        * "Enter the algorithm you want to use to create DEK(AES_128/AES_192/AES_256)"
            Uses the chosen algorithm to create the Data Encryption Key (DEK).
    * If 'n' or 'N':
        * "Enter the name to create MEK/master encryption key"
            Creates a new Key Master Encryption Key (MEK) with the provided name.
        * "Enter the name to create Provider key"
            Creates a provider key within the Extensible Key Management (EKM) provider.
        * **API-key** to create credential (entered securely)
            Uses the API key to authenticate with the cryptographic provider when creating credentials.
        * "Enter the name of your cryptographic provider from above provided set of providers"
            Uses the specified cryptographic provider for key management operations.
        * "Enter the name to create credential"
            Creates a SQL Server credential for the cryptographic provider.
        * "Enter Identity to create credential"
            Sets the identity for the SQL Server credential.
        * "Enter login name to map credential"
            Maps the newly created credential to the specified SQL Server login.
        * "Enter the algorithm you want to use to create MEK(RSA_4096/RSA_3072/RSA_2048/RSA_1024/RSA_512 )"
            Uses the chosen RSA algorithm to create the new MEK.
        * "Enter the name to create db engine credential"
            Creates a credential specifically for the database engine to interact with the provider.
        * "Enter Identity to create db engine credential"
            Sets the identity for the database engine credential.
        * "Enter the name to create db engine login"
            Creates a SQL Server login from the asymmetric key for the database engine.
        * "Enter the algorithm you want to use to create DEK(AES_128/AES_192/AES_256 )"
            Uses the chosen algorithm to create the Data Encryption Key (DEK).
* If performing rotation (menu option '3'):
    * **Database name**
         enter the name of the database for which they want to rotate the MEK.
    * **API-key** to create credential (entered securely)
        Uses the API key to authenticate with the cryptographic provider during the rotation process.
    * "Enter the name to create MEK/master encryption key"
        Creates a new Master Encryption Key (MEK) with the provided name for the rotation.
    * "Enter the name to create Provider key"
        Creates a provider key within the EKM provider for the new MEK.
    * "Enter the algorithm you want to use to create MEK(RSA_2048/RSA_1024 )"
        Uses the chosen RSA algorithm to create the new MEK for rotation.
    * "Enter the name to create db engine credential"
        Creates a new database engine credential for the rotation.
    * "Enter Identity to create db engine credential"
        Sets the identity for the new database engine credential.
    * "Enter the name to create db engine login"
        Creates a new SQL Server login from the asymmetric key for the database engine during rotation.
