It can be deployed either use json parameter or Bicep paramter

 az deployment group create --resource-group bicep --template-file vm.bicep --parameters .\vm.bicepparam

 or 
  az deployment group create --resource-group bicep --template-file vm.bicep --parameters .\vm.parameter.json
