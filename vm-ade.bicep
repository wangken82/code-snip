param vnetResourceGroup string
param vnetName string
param vmName string
param location string
param subnetName string
param adminUsername string
@secure()
param adminPassword string
param vmSize string
param keyVaultResourceGroup string
param keyVaultName string
param keyName string


@description('Destination port range for NSG rule')
param destRDPPort string
param sourceAddressPrefixes array

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  scope: resourceGroup(vnetResourceGroup)
  name: vnetName
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-port'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: destRDPPort
          sourceAddressPrefixes: sourceAddressPrefixes
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  scope: resourceGroup(keyVaultResourceGroup)
  name: keyVaultName
}

resource key 'Microsoft.KeyVault/vaults/keys@2024-04-01-preview' existing = {
  parent: keyVault
  name: keyName
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

@description('add ade encryption extension to the VM')
resource encryptionExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AzureDiskEncryptionForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'AzureDiskEncryption'
    typeHandlerVersion: '2.5'
    autoUpgradeMinorVersion: true
    settings: {
      EncryptionOperation: 'EnableEncryption'
      KeyVaultURL: keyVault.properties.vaultUri
      KeyVaultResourceId: keyVault.id
      KeyEncryptionAlgorithm: 'RSA-OAEP'
      VolumeType: 'OS'
      KeyEncryptionKeyURL: key.properties.keyUriWithVersion
      KekVaultResourceId: keyVault.id
    }
  }
}

