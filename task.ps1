<#
--------------------------------------------------------------------------------
| Deploying a Virtual Machine and all required resources to Azure subscription |
--------------------------------------------------------------------------------
#>

# General settings:
$location =                 "uksouth"
$resourceGroupName =        "mate-azure-task-9"

# Network Security Group settings:
$networkSecurityGroupName = "defaultnsg"

# Virtual Network settings:
$virtualNetworkName =       "vnet"
$subnetName =               "default"
$vnetAddressPrefix =        "10.0.0.0/16"
$subnetAddressPrefix =      "10.0.0.0/24"

# Public IP settings:
$publicIpAddressName =      "linuxboxpip"
$publicIpDnsprefix =        "shu-task-9"
$publicIpSku =              "Basic"
$publicIpAllocation =       "Dynamic"

# Network Interface settings:
$nicName =                  "NetInterface"
$ipConfigName =             "ipConfig1"

# SSH settings:
$sshKeyName =               "linuxboxsshkey"
$sshKeyPath =               "$HOME/.ssh/id_rsa.pub"

# Boot Diagnostic Storage Account settings
$bootStorageAccName =       "bdsatask9"
$bootStSkuName =            "Standard_LRS"
$bootStKind =               "StorageV2"
$bootStAccessTier =         "Hot"
$bootStMinimumTlsVersion =  "TLS1_0"

# VM settings:
$vmName =                   "matebox"
$vmSecurityType =           "Standard"
$vmSize =                   "Standard_B1s"

# OS settings:
$osUser =                   "shu"
$osUserPassword =           "MyStrongP@ssw0rd"
$osPublisherName =          "Canonical"
$osOffer =                  "0001-com-ubuntu-server-jammy"
$osSku =                    "22_04-lts-gen2"
$osVersion =                "latest"
$osDiskSizeGB =             64
$osDiskType =               "Premium_LRS"

# Check if the user is logged in to Azure
Write-Host "Checking if you are logged in to Azure ..." -ForegroundColor Cyan
$context = Get-AzContext
if ($null -ne $context) {
    Write-Host "You are logged in to Azure. Proceeding with the script ..." -ForegroundColor Green
} else {
    Write-Host "You are not logged in to Azure. Please run Connect-AzAccount before executing this script." -ForegroundColor Red -BackgroundColor Yellow
    exit
}

# Create the resource group
Write-Host "Creating a resource group $resourceGroupName ..." -ForegroundColor Cyan
try {
    $newResGroup = @{
      Name     = $resourceGroupName
      Location = $location
}
    New-AzResourceGroup @newResGroup | Out-Null
    Write-Host "Resource group $resourceGroupName created." -ForegroundColor Green
} catch {
    Write-Host "Failed to create resource group $resourceGroupName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

# Create the Network Security Group and rules
Write-Host "Creating a network security group $networkSecurityGroupName ..." -ForegroundColor Cyan
try {
    # SSH Rule
    $nsgRuleSSHParams = @{
        Name                     = "SSH"
        Protocol                 = "Tcp"
        Direction                = "Inbound"
        Priority                 = 1001
        SourceAddressPrefix      = "*"
        SourcePortRange          = "*"
        DestinationAddressPrefix = "*"
        DestinationPortRange     = 22
        Access                   = "Allow"
    }
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig @nsgRuleSSHParams

    # HTTP Rule
    $nsgRuleHTTPParams = @{
        Name                     = "HTTP"
        Protocol                 = "Tcp"
        Direction                = "Inbound"
        Priority                 = 1002
        SourceAddressPrefix      = "*"
        SourcePortRange          = "*"
        DestinationAddressPrefix = "*"
        DestinationPortRange     = 8080
        Access                   = "Allow"
    }
    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig @nsgRuleHTTPParams

    # Network Security Group Params
    $nsgParams = @{
        Name              = $networkSecurityGroupName
        ResourceGroupName = $resourceGroupName
        Location          = $location
        SecurityRules     = $nsgRuleSSH, $nsgRuleHTTP
    }
    New-AzNetworkSecurityGroup @nsgParams | Out-Null
    Write-Host "Network security group $networkSecurityGroupName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create network security group $networkSecurityGroupName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

# Create the Virtual Network and Subnet
Write-Host "Creating a virtual network $virtualNetworkName ..." -ForegroundColor Cyan
try {
    # Get the network security group object
    $nsgParams = @{
        Name              = $networkSecurityGroupName
        ResourceGroupName = $resourceGroupName
    }
    $networkSecurityGroupObj = Get-AzNetworkSecurityGroup @nsgParams

    # Create subnet configuration
    $subnetParams = @{
        Name                 = $subnetName
        AddressPrefix        = $subnetAddressPrefix
        NetworkSecurityGroup = $networkSecurityGroupObj
    }
    $subnetConfig = New-AzVirtualNetworkSubnetConfig @subnetParams

    # Create the virtual network
    $vnetParams = @{
        Name              = $virtualNetworkName
        ResourceGroupName = $resourceGroupName
        Location          = $location
        AddressPrefix     = $vnetAddressPrefix
        Subnet            = $subnetConfig
    }
    New-AzVirtualNetwork @vnetParams | Out-Null

    # Get the virtual network object
    $vnetParamsGet = @{
        Name              = $virtualNetworkName
        ResourceGroupName = $resourceGroupName
    }
    $vnetObj = Get-AzVirtualNetwork @vnetParamsGet

    # Retrieve the subnet ID
    $subnetId = $vnetObj.Subnets[0].Id

    Write-Host "Virtual network $virtualNetworkName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create virtual network $virtualNetworkName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

# Create the Public IP
Write-Host "Creating a Public IP $publicIpAddressName ..." -ForegroundColor Cyan
try {
    # Create the public IP address
    $publicIpParams = @{
        Name              = $publicIpAddressName
        ResourceGroupName = $resourceGroupName
        Location          = $location
        Sku               = $publicIpSku
        AllocationMethod  = $publicIpAllocation
        DomainNameLabel   = $publicIpDnsprefix
    }
    New-AzPublicIpAddress @publicIpParams | Out-Null

    # Get the public IP address object
    $publicIpParamsGet = @{
        Name              = $publicIpAddressName
        ResourceGroupName = $resourceGroupName
    }
    $publicIpObj = Get-AzPublicIpAddress @publicIpParamsGet

    Write-Host "Public IP $publicIpAddressName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create Public IP $publicIpAddressName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

# Create the Network Interface
Write-Host "Creating a Network Interface Configuration $nicName ..." -ForegroundColor Cyan
try {
    # Create the network interface IP configuration
    $ipConfigParams = @{
        Name              = $ipConfigName
        SubnetId          = $subnetId
        PublicIpAddressId = $publicIpObj.Id
    }
    $ipConfig = New-AzNetworkInterfaceIpConfig @ipConfigParams

    # Create the network interface
    $nicParams = @{
        Name              = $nicName
        ResourceGroupName = $resourceGroupName
        Location          = $location
        IpConfiguration   = $ipConfig
    }
    New-AzNetworkInterface @nicParams -Force | Out-Null

    # Get the network interface object
    $nicParamsGet = @{
        Name              = $nicName
        ResourceGroupName = $resourceGroupName
    }
    $nicObj = Get-AzNetworkInterface @nicParamsGet

    Write-Host "Network Interface $nicName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create Network Interface $nicName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

# Create the SSH key resource
Write-Host "Creating an SSH key resource $sshKeyName ..." -ForegroundColor Cyan

try {
    # Check if the SSH public key file exists
    if (Test-Path $sshKeyPath) {
        $sshKeyPublicKey = Get-Content $sshKeyPath
        Write-Host "SSH public key file found. Proceeding with SSH key creation..."  -ForegroundColor Green

        # Create the SSH key resource
        $sshKeyParams = @{
            Name              = $sshKeyName
            ResourceGroupName = $resourceGroupName
            PublicKey         = $sshKeyPublicKey
        }
        New-AzSshKey @sshKeyParams | Out-Null
        
        Write-Host "SSH key resource $sshKeyName created successfully." -ForegroundColor Green
    } else {
        Write-Host "SSH public key file not found at $sshKeyPath. Please make sure the file exists and try again." -ForegroundColor Red -BackgroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "Failed to create SSH key resource $sshKeyName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}


# Create the storage account for boot diagnostics
Write-Host "Creating new standard storage account for boot diagnostics ..." -ForegroundColor Cyan

try {
    # Define the parameters for the storage account
    $storageParams = @{
        ResourceGroupName = $resourceGroupName
        Name              = $bootStorageAccName
        Location          = $location
        SkuName           = $bootStSkuName
        Kind              = $bootStKind
        AccessTier        = $bootStAccessTier
        MinimumTlsVersion = $bootStMinimumTlsVersion
    }
    New-AzStorageAccount @storageParams | Out-Null
    
    Write-Host "Storage account $bootStorageAccName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create storage account $bootStorageAccName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

# Create the Virtual Machine
Write-Host "Creating a Virtual Machine ..." -ForegroundColor Cyan

# Convert the plain text password to a secure string
$securedPassword = ConvertTo-SecureString -String $osUserPassword -AsPlainText -Force

# Create the credential object using the secure password
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $osUser, $securedPassword

try {
    # Initialize the VM configuration
    $vmConfigParams = @{
        VMName        = $vmName
        VMSize        = $vmSize
        SecurityType  = $vmSecurityType
    }
    $vmconfig = New-AzVMConfig @vmConfigParams

    # Set the source image for the VM
    $sourceImageParams = @{
        VM            = $vmconfig
        PublisherName = $osPublisherName
        Offer         = $osOffer
        Skus          = $osSku
        Version       = $osVersion
    }
    $vmconfig = Set-AzVMSourceImage @sourceImageParams

    # Configure the OS disk for the VM
    $osDiskParams = @{
        VM                 = $vmconfig
        Name               = "${vmName}_OSDisk"
        CreateOption       = "FromImage"
        DeleteOption       = "Delete"
        DiskSizeInGB       = $osDiskSizeGB
        Caching            = "ReadWrite"
        StorageAccountType = $osDiskType
    }
    $vmconfig = Set-AzVMOSDisk @osDiskParams

    # Configure the operating system for the VM
    $osConfigParams = @{
        VM                            = $vmconfig
        ComputerName                  = $vmName
        Credential                    = $cred
    }
    $vmconfig = Set-AzVMOperatingSystem @osConfigParams -Linux -DisablePasswordAuthentication

    # Add the network interface to the VM
    $networkInterfaceParams = @{
        VM = $vmconfig
        Id = $nicObj.Id
    }
    $vmconfig = Add-AzVMNetworkInterface @networkInterfaceParams

    # Configure boot diagnostics for the virtual machine
    $bootDiagParams = @{
        VM                 = $vmconfig
        Enable             = $true
        ResourceGroupName  = $resourceGroupName
        StorageAccountName = $bootStorageAccName
    }
    $vmconfig = Set-AzVMBootDiagnostic @bootDiagParams

    # Create the virtual machine
    $createVmParams = @{
        ResourceGroupName = $resourceGroupName
        Location          = $location
        VM                = $vmconfig
        SshKeyName        = $sshKeyName
    }
    New-AzVM @createVmParams | Out-Null

    Write-Host "Virtual Machine $vmName created successfully." -ForegroundColor Green
   # Get-AzResource -ResourceGroupName $resourceGroupName
} catch {
    Write-Host "Failed to create Virtual Machine $vmName. Error: $_" -ForegroundColor Red -BackgroundColor Yellow
    exit 1
}

<#
--------------------------------------------------------
| Deploying the web application to the virtual machine |
--------------------------------------------------------
#>

# SSH connection details
$vmIp = "$publicIpDnsprefix.$location.cloudapp.azure.com"
$sshConnection = "$osUser@$vmIp"
$chownUser = "${osUser}:${osUser}"

# Checking VM state
$azVmState = (Get-AzVm -ResourceGroupName $resourceGroupName -Status).PowerState
while ($azVmState -ne 'VM running') {
  Write-Host "VM state $azVmState. Waiting for 'VM running'..." -ForegroundColor Red -BackgroundColor Yellow
  Start-Sleep -Seconds 10
}
Write-Host "VM state $azVmState. Proceeding with the script ..." -ForegroundColor Green

# Check SSH connection
$checkSshCommand = "ssh -o StrictHostKeyChecking=no $sshConnection 'echo SSH connection successful'"
Invoke-Expression $checkSshCommand

# Create /app folder and set ownership
$createFolderCommand = "ssh -o StrictHostKeyChecking=no $sshConnection 'sudo mkdir -p /app && sudo chown $chownUser /app'"
Invoke-Expression $createFolderCommand

# Copy the contents of the 'app' folder to the VM
$appFolderPath = "$PWD\app\"
$copyCommand = "scp -r $appFolderPath* ${sshConnection}:/app"
Invoke-Expression $copyCommand

# Install python3-pip, move the service file, and start the service
$installCommand = @"
ssh -o StrictHostKeyChecking=no $sshConnection '
    sudo apt update &&
    sudo apt-get -y install python3-pip &&
    cd /app &&
    sudo chmod 755 start.sh &&
    sudo mv todoapp.service /etc/systemd/system/ &&
    sudo systemctl daemon-reload &&
    sudo systemctl start todoapp &&
    sudo systemctl enable todoapp
'
"@
Invoke-Expression $installCommand

# Verify that the web app service is running
$verifyCommand = "ssh -o StrictHostKeyChecking=no $sshConnection 'systemctl status todoapp'"
$output = Invoke-Expression $verifyCommand
Write-Output $output
