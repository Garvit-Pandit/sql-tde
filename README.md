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
```
.\SQL_TDE.ps1
Enter Instance name: test
Enter username: testuser
Enter password:
or
.\sql_tde.ps1 -instance test -username testuser -password testpassword
```
WARNING: Passing your password via -password is not very secure.It is better to enter your password interactively.
