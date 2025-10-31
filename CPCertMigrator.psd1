@{
    # Script module (.psm1) or binary module (.dll) associated with this manifest
    RootModule        = 'CPCertMigrator.psm1'

    # Version number of this module
    ModuleVersion     = '1.7.3'

    # ID used to uniquely identify this module
    GUID              = 'd4f2c6b2-8e10-4a63-9a8b-2f8cd5109e6a'

    # Author of this module
    Author            = 'zeroday'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for migrating CryptoPro CSP certificates between user and machine stores with Russian localization and enhanced security.'

    # Minimum PowerShell version required
    PowerShellVersion = '5.1'

    # Functions to export
    FunctionsToExport = @('Export-CryptoProCertificates', 'Import-CryptoProCertificates', 'Get-CryptoProCertificates', 'Start-CryptoProCertMigrator')

    # Cmdlets to export; none in this case
    CmdletsToExport   = @()

    # Variables to export; none
    VariablesToExport = @()

    # Aliases to export; nones
    AliasesToExport   = @()

    # Private data for module metadata like tags, license, project URI
    PrivateData       = @{
        PSData = @{
            Tags         = @('CryptoPro', 'CSP', 'Certificate', 'Migration', 'Console')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/YourOrg/CryptoProCertMigrator'
            ReleaseNotes = 'Version 1.1.0 - Added interactive console menu and enhanced functionality'
        }
    }
}