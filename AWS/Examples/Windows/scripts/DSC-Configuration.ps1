param
(
    $ServerName,
    $DSCOutputPath
)

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = $ServerName
        }
    )
}

Configuration DSC-Configuration
{
    # Install Required Modules
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName cChoco

    $env:chocolateyUseWindowsCompression = 'true'

    Node $ServerName
    {
        # Install Chocolatey
        cChocoInstaller installChoco { 
            InstallDir = "C:\ProgramData\Chocolatey"
        }
        # Set Chocolatey Source
        cChocoSource Repo {
            Name   = 'YourRepo'
            Source = 'https://chocolatey.org/api/v2'
            
        }

        # Install Roles

        # Install Applications
        cChocoPackageInstaller notepadplusplus {            
            Name      = "notepadplusplus" 
            Version   = "7.5.7" 
            Source    = "Repo" 
            DependsOn = '[cChocoInstaller]installChoco', '[cChocoSource]Repo'
        }
    }
}

DSC-Configuration -ConfigurationData $ConfigurationData -OutputPath $DSCOutputPath
Start-DscConfiguration -Path $DSCOutputPath -ComputerName $ServerName -Force -Verbose -Wait