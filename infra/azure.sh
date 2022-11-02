resourceGroup=rg_rosmith1
location=westeurope
vm_name=ccf4
vm_dns=rosmith-ccf4
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

# az ssh config \
#     --resource-group $resourceGroup \
#     --name $vm_name \
#     --file ../ccf-sshconfig

az vm extension set \
    --publisher Microsoft.Azure.ActiveDirectory \
    --name AADSSHLoginForLinux \
    --resource-group $resourceGroup \
    --vm-name $vm_name

signed_in_user=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
    --role "virtual machine administrator login" \
    --resource-group $resourceGroup \
    --assignee $signed_in_user

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

# az network bastion create \
#     --name "ccf-bastion" \
#     --public-ip-address "BastionIp" \
#     --resource-group $resourceGroup \
#     --vnet-name $vnetName

# az network bastion tunnel \
#     --name "ccf-bastion" \
#     --resource-group $resourceGroup \
#     --target-resource-id $vmId \
#     --resource-port 22 \
#     --port 9090


# az ssh vm --resource-group $resourceGroup --name $vm_name

# az ssh config --resource-group rg_rosmith1 --name ccf2 --file ../ccf-sshconfig