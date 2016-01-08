#
# The MIT License (MIT)
#
# Copyright (c) 2016 Tim
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
# files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
# is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF 
# OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
#************************************************
#************************************************
# This script will create an internet facing load balancer with multiple public IP addresses to enable multiple SSL Sites
# running on a single VM using public port 443 and a specified private port
#
#************************************************
#************ Variables *************************
$subscriptionId = ""
$resourceGroupName = "Test"
$locationName = ""

$loadBalancerName = "test-lb"

$ip1name = "frontIp1"
$ip1CfgName = "lb-frontend1"

$ip2name = "frontIp2"
$ip2CfgName = "lb-frontend2"
$ip2HttpPort = "81"
$ip2SslPort = "444"

$ip3name = "frontIp3"
$ip3CfgName = "lb-frontend3"
$ip3HttpPort = "82"
$ip3SslPort = "445"

$lbName = "test-lb"
$lbbendPoolName = "lb-bend"

$nicName = "lbInt1"
$nicPrivateIp = ""

$vmName = ""
#************************************************
#************************************************

##########  Authenticate with Azure
Login-AzureRmAccount

#Set powershell context to use the specified Subscription
Set-AzureRmContext -SubscriptionId $subscriptionId





##########  Create LB with public Addresses

#Get new public IP 1
$ip1 = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName -Name $ip1name -Location $locationName -AllocationMethod Static

#Create first loadbalancer front end address config
$pubIp1Config = New-AzureRmLoadBalancerFrontendIpConfig -Name $ip1CfgName -PublicIpAddress $ip1


#Get a second public IP 
$ip2 = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName -Name $ip2name -Location $locationName -AllocationMethod Static

#Create second loadbalancer front end address config
$pubIp1Config2 = New-AzureRmLoadBalancerFrontendIpConfig -Name $ip2CfgName -PublicIpAddress $ip2


#Get a third public IP 
$ip3 = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName -Name $ip3name -Location $locationName -AllocationMethod Static

#Create third loadbalancer front end address config
$pubIp1Config3 = New-AzureRmLoadBalancerFrontendIpConfig -Name $ip3CfgName -PublicIpAddress $ip3


#setup backend address pool for lb
$bendAddyPool1 = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $lbbendPoolName

#create nat rules for IP 1
$rdpRule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP" -FrontendIpConfiguration $pubIp1Config -Protocol TCP -FrontendPort 3389 -BackendPort 3389
$httpRule = New-AzureRmLoadBalancerRuleConfig -Name "HTTPs" -FrontendIpConfiguration $pubIp1Config -BackendAddressPool $bendAddyPool1 -Protocol Tcp -FrontendPort 443 -BackendPort 443

#Create the load balancer with the components 
$azureLb = New-AzureRmLoadBalancer -ResourceGroupName $resourceGroupName -Name $lbName -Location $locationName -FrontendIpConfiguration $pubIp1Config,$pubIp1Config2,$pubIp1Config3 -InboundNatRule $rdpRule -LoadBalancingRule $httpRule -BackendAddressPool $bendAddyPool1

$azureLb | Add-AzureRmLoadBalancerRuleConfig -Name "HTTP" -FrontendIpConfiguration $azureLb.FrontendIpConfigurations[0] -BackendAddressPool $azureLb.BackendAddressPools[0] -Protocol Tcp -FrontendPort 80 -BackendPort 80

$azureLb | Set-AzureRmLoadBalancer


#create rules for IP 2
$azureLb = Get-AzureRmLoadBalancer -ResourceGroupName $resourceGroupName -Name $lbName

$azureLb | Add-AzureRmLoadBalancerRuleConfig -Name "HTTP2" -FrontendIpConfiguration $azureLb.FrontendIpConfigurations[1] -BackendAddressPool $azureLb.BackendAddressPools[0] -Protocol Tcp -FrontendPort 80 -BackendPort $ip2HttpPort

$azureLb | Set-AzureRmLoadBalancer

$azureLb = Get-AzureRmLoadBalancer -ResourceGroupName $resourceGroupName -Name $lbName

$azureLb | Add-AzureRmLoadBalancerRuleConfig -Name "HTTPs2" -FrontendIpConfiguration $azureLb.FrontendIpConfigurations[1] -BackendAddressPool $azureLb.BackendAddressPools[0] -Protocol Tcp -FrontendPort 443 -BackendPort $ip2SslPort

$azureLb | Set-AzureRmLoadBalancer


#create rules for IP 3
$azureLb = Get-AzureRmLoadBalancer -ResourceGroupName $resourceGroupName -Name $lbName

$azureLb | Add-AzureRmLoadBalancerRuleConfig -Name "HTTP3" -FrontendIpConfiguration $azureLb.FrontendIpConfigurations[2] -BackendAddressPool $azureLb.BackendAddressPools[0] -Protocol Tcp -FrontendPort 80 -BackendPort $ip3HttpPort

$azureLb | Set-AzureRmLoadBalancer

$azureLb = Get-AzureRmLoadBalancer -ResourceGroupName $resourceGroupName -Name $lbName

$azureLb | Add-AzureRmLoadBalancerRuleConfig -Name "HTTPs3" -FrontendIpConfiguration $azureLb.FrontendIpConfigurations[2] -BackendAddressPool $azureLb.BackendAddressPools[0] -Protocol Tcp -FrontendPort 443 -BackendPort $ip3SslPort

$azureLb | Set-AzureRmLoadBalancer


##########  Setup new NIC to work off LB pool, associate to VM


#get existing virtual network for the resource group deployment
$virtualNetwork = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName

#get subnet
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork

$azureLb = Get-AzureRmLoadBalancer -ResourceGroupName $resourceGroupName -Name $lbName

#Create new VM NIC 
$vmNic = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -Location $locationName -PrivateIpAddress $nicPrivateIp -Subnet $subnet -LoadBalancerBackendAddressPool $azureLb.BackendAddressPools[0] -LoadBalancerInboundNatRule $azureLb.InboundNatRules[0]

#remove exising NIC
$existingVM = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
$existingVM = Remove-AzureRmVMNetworkInterface -VM $existingVM -NetworkInterfaceIDs $existingVM.NetworkInterfaceIDs

#assign the new NIC to a VM
$existingVM = Add-AzureRmVMNetworkInterface -VM $existingVM -NetworkInterface $vmNic

#update VM
$existingVM = Update-AzureRmVm -VM $existingVM -ResourceGroupName $resourceGroupName
