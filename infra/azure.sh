resourceGroup=rg_rosmith
location=westeurope
vm_name=ccf5
vm_dns=rosmith-ccf5
vm_size=Standard_DC1s_v2
vnetName=ccf
subnetName=nodes
vnetAddressPrefix=10.0.0.0/16
nodeAddressPrefix=10.0.0.0/24
bastionAddressPrefix=10.0.1.0/26

az group create --name $resourceGroup --location $location

az network vnet create \
  --name $vnetName \
  --resource-group $resourceGroup \
  --address-prefixes $vnetAddressPrefix \
  --subnet-name $subnetName \
  --subnet-prefixes $nodeAddressPrefix

az network vnet subnet create \
    --address-prefixes $bastionAddressPrefix \
    --name "AzureBastionSubnet" \
    --vnet-name $vnetName \
    --resource-group $resourceGroup

# az network public-ip create \
#     --resource-group $resourceGroup \
#     --name "BastionIp" \
#     --sku Standard \
#     --location $location

# Automatically generates a ssh key if one is not present
# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed#generate-keys-automatically-during-deployment
az vm create \
    --resource-group $resourceGroup \
    --name $vm_name \
    --image canonical:0001-com-ubuntu-server-focal:20_04-lts-gen2:20.04.202210180 \
    --vnet-name $vnetName \
    --subnet $subnetName \
    --generate-ssh-keys \
    --size $vm_size \
    --public-ip-sku Standard \
    --public-ip-address-dns-name $vm_dns \
    --assign-identity \
    --admin-username azureuser \
    --custom-data ccf.cloudinit \
    --output json

# https://learn.microsoft.com/en-us/cli/azure/ssh?view=azure-cli-latest#az-ssh-config
# az ssh config \
#     --resource-group $resourceGroup \
#     --name $vm_name \
#     --file ../ccf-sshconfig

# https://learn.microsoft.com/en-us/azure/active-directory/devices/howto-vm-sign-in-azure-ad-linux
az vm extension set \
    --publisher Microsoft.Azure.ActiveDirectory \
    --name AADSSHLoginForLinux \
    --resource-group $resourceGroup \
    --vm-name $vm_name

# Make your AAD account an Admin on the machine (we don't actually use this!)
# https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest
signed_in_user=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
    --role "virtual machine administrator login" \
    --resource-group $resourceGroup \
    --assignee $signed_in_user

# https://learn.microsoft.com/en-us/rest/api/defenderforcloud/jit-network-access-policies/create-or-update?tabs=HTTP
subscriptionId=$(az account show --query id -o tsv)
jitBody=$(jq -c . << JSON
{
  "name": "${vm_name}",
  "type": "Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01",
  "id": "/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Security/locations/${location}/jitNetworkAccessPolicies/${vm_name}",
  "location": "${location}",
  "kind": "Basic",
  "properties": {
    "virtualMachines": [
      {
        "id": "/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vm_name}",
        "ports": [
          {
            "number": 22,
            "protocol": "TCP",
            "allowedSourceAddressPrefix": "*",
            "maxRequestAccessDuration": "PT3H"
          }
        ]
      }
    ]
  }
}
JSON
)

# echo $jitBody
# echo
# az rest --method POST \
#     --uri https://management.azure.com/subscriptions/${subscriptionId}/providers/Microsoft.Security/jitNetworkAccessPolicies/${vm_name}?api-version=2020-01-01 \
#     --body "${jitBody}"
# vmId="/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Compute/virtualMachines/$vm_name"
#az rest --uri https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Security/locations/${location}/jitNetworkAccessPolicies?api-version=2020-01-01
#az rest --method delete --uri https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Security/locations/${location}/jitNetworkAccessPolicies/default?api-version=2020-01-01

# https://azure.microsoft.com/en-us/blog/customize-your-secure-vm-session-experience-with-native-client-support-on-azure-bastion/#:~:text=Meanwhile%2C%20the%20az%20network%20bastion%20tunnel%20command%20allows,using%20a%20custom%20client%20and%20the%20specified%20port.
# az network bastion create \
#     --name "ccf-bastion" \
#     --public-ip-address "BastionIp" \
#     --resource-group $resourceGroup \
#     --vnet-name $vnetName

# https://learn.microsoft.com/en-us/azure/bastion/connect-native-client-windows#connect-tunnel
# az network bastion tunnel \
#     --name "ccf-bastion" \
#     --resource-group $resourceGroup \
#     --target-resource-id $vmId \
#     --resource-port 22 \
#     --port 9090


# az ssh vm --resource-group $resourceGroup --name $vm_name

# az ssh config --resource-group rg_rosmith1 --name ccf2 --file ../ccf-sshconfig