

[String]$SubSource
[String]$SubDestination

$DataFile = "Archives_DataFile.psd1"

while ((Get-AzContext).Subscription.id -ne $SubDestination) {
    Select-AzSubscription -SubscriptionId $SubDestination -Force | Out-Null
}

$Values = Import-PowerShellDataFile -Path $DataFile
$Rbac = Import-Csv RBAC-SubSource_Archives.csv


Foreach ($RG in $values.Resourcegroup) {
    Describe "Test ResourceGroup $($RG.Name)" {
        It "Check if $($RG.Name) exists" {
            Get-AzResourceGroup -name $RG.Name -location $RG.location | Should Be $true
        }

        if ($RG.Tag) {
            Context "Validatin Tags" {

                Foreach ($Tag in $RG.Tag) {

                    $resourcegroup = Get-AzResourceGroup -name $RG.Name -location $RG.location

                    It "Tag $($Tag.Name) should have the value $($Tag.value)" {
                        $resourcegroup.tags["$($Tag.Name)"] | Should be $Tag.value
                    }
                }
            }
        }
    }
    
    if ($RG.VirtualMachine) {

        Foreach ($VM in $RG.VirtualMachine) {
            Describe "Test $($VM.Name) in resourcegroup $($RG.Name) " {
                $result = Get-AzVM -name $VM.Name -resourcegroupName $RG.Name
                $nic = ($result.NetworkProfile.NetworkInterfaces.Id).split('/')[-1]
                $nicinfos = Get-AzNetworkInterface -ResourceGroupName $RG.Name -Name $nic
                $sub = $nicInfos.IpConfigurations.Subnet.id.split('/')[-1]
                $vnet = $nicInfos.IpConfigurations.Subnet.id.split('/')[-3]
                $fullsub = "$($vnet)/$($sub)"
                $Azstatus = (get-azvm -name $VM.Name -ResourceGroupName $RG.Name -status).Statuses[-1].DisplayStatus
        
                It "$($VM.Name) virtual machine should exists in $($RG.Name)" {
                    $result.Name | Should Be $VM.Name
                }
        
                It "$($VM.Name) virtual machine should exists in $($RG.Name) and have ip $($VM.ip)" {
                    $($VM.ip) | Should BeLike "*$($nicInfos.IpConfigurations.PrivateIpAddress)*"
                }
        
                It "$($VM.Name) virtual machine should exists in $($RG.Name) and have subnet $($VM.subnet)" {
                    $fullsub | Should Be $VM.subnet
                }
        
                It "$($VM.Name) virtual machine should exists in $($RG.Name) and have status $($VM.status)" {
                    $Azstatus | Should Be $VM.status
                }
                
                $OSDIsk = $VM.disk | Where-Object{ $_.kind -eq "OsDisk"}
                It "$($VM.Name) virtual machine should exists in $($RG.Name) and have an OSDisk" {
                    $result.StorageProfile.OsDisk.ManagedDisk.id | Should belike "*/$($OSDIsk.Name)"
                }

                $OSDiskInfos = Get-AzDisk | Where-Object{ $_.Id -like "*/$($OSDIsk.Name)" }
                It "$($VM.Name) virtual machine OS Disk size should be $($OsDisk.size)" {
                    $OSdiskInfos.DiskSizeGB | Should be $OsDisk.size
                }

                It "$($VM.Name) virtual machine OS Disk sku should be $($OsDisk.sku)" {
                    $OSdiskInfos.Sku.Tier | Should be $OsDisk.sku
                }

                $DataDIsk = $VM.disk | Where-Object{ $_.kind -eq "DataDisk"}

                Foreach ($disk in $DataDIsk) {
                    $AzDIsk = get-azdisk | Where-Object{ $_.id -like "*$($Disk.Name)" }
                    It "$($VM.Name) virtual machine should exists in $($RG.Name) and have $($disk.Name) data disk attached" {
                        $AzDisk.Name | Should be $disk.Name
                    }

                    It "$($VM.Name) virtual machine should exists in $($RG.Name) and have $($disk.Name) data disk attached with a fixed size of $($disk.size)" {
                        $AzDisk.DiskSizeGB | Should be $disk.size
                    }
                }

                if ($VM.availabilitySet) {
                    It "$($VM.Name) virtual machine should exists in $($RG.Name) and associated in availability set $($VM.availabilityset)" {
                        $result.AvailabilitySetReference.Id.split('/')[-1] | Should be $VM.availabilityset
                    }
                }

                if ($VM.Tag) {
                    Context "Validatin Tags" {
                        Foreach ($Tag in $VM.Tag) {
                        
                            It "Tag $($Tag.Name) should have the value $($Tag.value)" {
                                $result.tags["$($Tag.Name)"] | Should be $Tag.value
                            }
                        }
                    }
                }
            }
        }
    }
}


$RoleAssignement = Get-AzRoleAssignment

foreach ($r_assignement in $RBAC) {
    Describe "Test Role Assignements $($r_assignement.scope)" {
        $scope = $r_assignement.scope.replace($SubSource,$SubDestination)
        It "$($r_assignement.DisplayName) should be assigned to $scope" {
            ($RoleAssignement | Where-Object{ $_.Scope -eq $scope -and $_.DisplayName -eq $r_assignement.DisplayName} ).DisplayName | Should Be $r_assignement.DisplayName
        }           
    }
}



Foreach ($VNet in $values.VirtualNetwork) {
    Describe "Test Virtual Network $($Vnet.Name)" {   
        $Infos = Get-AzVirtualNetwork -resourceGroupName $Vnet.ResourceGroup

        It "Virtual Network: $($Vnet.Name) should exists" {
            $Infos | Should be $true
        }

        It "Virtual Network: $($Vnet.Name) range should be $($Vnet.Range)" {
            $Infos.AddressSpace.AddressPrefixes | Should be $Vnet.Range
        }

        
        Foreach ($subnet in $Vnet.Subnet) {

            Context "Testing $($Subnet.Name) subnet." {

                $AzureSubnet = $Infos.Subnets | Where-Object{ $_.Name -eq $subnet.Name }
    
                It "subnet with name $($subnet.Name) should exists in $($VNet.Name)" {
                    $AzureSubnet | should be $true
                }
    
                It "subnet with name $($subnet.Name) range should be $($subnet.range)" {
                    $AzureSubnet.AddressPrefix | should be $subnet.range
                }
    
                if ($subnet.nsg) {
    
                    It "subnet with name $($subnet.Name) should have $($subnet.nsg.count) nsg" {
                        $AzureSubnet.NetworkSecurityGroup.count | should be $subnet.nsg.count
                    }
                    
                    Foreach ($nsg in $subnet.nsg) {
                        
                        $Azurensg = ($AzureSubnet.NetworkSecurityGroup | Where-Object{ $_.Id -like "*/$($nsg.name)" }).Id.split('/')[-1]
    
                        it "subnet with name $($subnet.Name) should have a nsg named $($nsg.name)" {
                            $Azurensg | should be $nsg.name
                        }
                    }
                }
                if ($subnet.udr) {

                    It "subnet with name $($subnet.name) should have $($subnet.udr.count)" {
                        $AzureSubnet.RouteTable.count | Should be $subnet.udr.count
                    }

                    Foreach ($udr in $subnet.udr) {

                        $AzureUdr = ($AzureSubnet.RouteTable | Where-Object{ $_.Id -like "*/$($udr.name)" }).Id.split('/')[-1]

                        it "subnet with name $($subnet.Name) should have an udr named $($udr.name)" {
                            $AzureUdr | should be $udr.name
                        }

                    }
                }

            }
        }
    }
}


    # No powershell cmdlet existence for theses resources
    # Need to build the resource ID to validate its presence
    
Foreach ($server in $values.PostgreSQL) {
    Describe "Test PostgreSQL $($server.name)" {
        $ResId = "/subscriptions/$($SubDestination)/resourceGroups/$($server.resourcegroup)/providers/Microsoft.DBforPostgreSQL/servers/$($server.name)"

        It "PostgreSQL server: $($server.name) shoudl exists" {
            Get-AzResource -resourceId $ResId | should be $true
        }

    }

}

Foreach ($SA in $Values.StorageAccount) {
    $result = Get-AzStorageAccount -Name $SA.Name -ResourceGroupName $SA.resourcegroup
    $Context = New-AzStorageContext -StorageAccountName $SA.Name -StorageAccountKey $SA.AccountKey
    
    Describe "Test Storage Account: $($SA.Name)" {        

        It "Storage Account $($SA.Name) should exists" {
            $result | should be $true
        }

        Context "Validating Tags" {
            if ($SA.Tag) {

                Foreach ($Tag in $SA.Tag) {
        
                    It "Tag $($Tag.Name) should have the value $($Tag.value)" {
                        $result.tags["$($Tag.Name)"] | Should be $Tag.value
                    }

                }
            }
        }

        Context "Validating Network integration" {
            It "Storage Account $($SA.Name) should have $($SA.VirtualNetwork.count) Subnet attached " {
                $result.NetworkRuleSet.VirtualNetworkRules.count | should be $SA.VirtualNetwork.count
            }

            Foreach ($v in $SA.VirtualNetwork) {
                # build the Subnet id
                $VnetId = "/subscriptions/$($SubDestination)/resourceGroups/$($v.Resourcegroup)/providers/Microsoft.Network/virtualNetworks/$($v.VnetName)/subnets/$($v.Subnetname)"
                $temp = ($result.NetworkRuleSet.VirtualNetworkRules | Where-Object{ $_.VirtualNetworkResourceId -eq $VnetId}).VirtualNetworkResourceId

                It "Virtual Network Resource Id $($VnetId) should be attached to storage account" {
                    $temp | Should be $VnetId
                }

            }
        }

        Context "Validating Containers" {
            $Container = Get-AzStorageContainer -Context $context
            
            It "Storage Account $($SA.Name) should have $($SA.Container.count) containers" {
                $container.count | should be $SA.Container.count
            }

            Foreach ($c in $SA.Container) {
                $temp = ($container | Where-Object{ $_.Name -eq $c.Name}).Name

                It "Container $($c.name) should exists" {
                    $temp | Should be $c.Name
                }
            }
        }

        Context "Validating File Shares" {
            $Share = Get-AzStorageShare -context $context

            It "Storage Account $($SA.Name) should have $($SA.Share.count) File Shares" {
                $Share.count | should be $SA.Share.count
            }

            Foreach ($fs in $SA.share) {
                $temp = ($Share | Where-Object{ $_.Name -eq $fs.Name}).Name

                It "Share $($fs.name) should exists" {
                    $temp | Should be $fs.Name
                }
            }
        }

    }
}