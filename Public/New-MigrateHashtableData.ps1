Function New-MigrateHashtableData {
    param (
        $DataFile = "Archives_DataFile.psd1"
    )

    Begin {
        $RGs = Get-AzResourceGroup | where {$_.ResourceGroupName -like "xxx*"}
    }
    Process {
        Try {
            Write-Info -type Info -msg "Start datas testing generation"
        "@{" | Out-File -FilePath $DataFile
        "    Resourcegroup = @(" | Out-File -FilePath $DataFile -Append
        "        @{" | Out-File -FilePath $DataFile -Append
        
        $RGCount = $RGs.Count
        Write-Info -type Info -msg "Resource groups found: $($RGcount)"
        $RGs | % {
            $ResourceGroup = $_
            Write-Info -type Info -msg "Working on resource group: $($ResourceGroup.ResourceGroupName) - Still have $RGCount RG to analyze."
            $RGCount = $RGCount-1
            "            Name = '$($ResourceGroup.ResourceGroupName)'" | Out-File -FilePath $DataFile -Append
            "            Location = 'westeurope'" | Out-File -FilePath $DataFile -Append
            $TagCount = $ResourceGroup.Tags.count
            if ($TagCount -ge 1) {
                "            Tags = @(" | Out-File -FilePath $DataFile -Append
                $ResourceGroup.Tags.GetEnumerator() | % {
                    $TagCount = $TagCount-1
                    $Tag = $_
                    "            @{" | Out-File -FilePath $DataFile -Append
                    "                Name = '$($Tag.Name)'" | Out-File -FilePath $DataFile -Append
                    "                Value = '$($Tag.Value)'" | Out-File -FilePath $DataFile -Append
                    if ($TagCount -ge 1) {
                        "            }," | Out-File -FilePath $DataFile -Append
                    }
                    else {
                        "            }" | Out-File -FilePath $DataFile -Append
                    }
                }
                "            )" | Out-File -FilePath $DataFile -Append
            }
            $VMs = Get-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName
            $VMCount = $VMs.count
            if ($VMs.count -ge 1) {
                Write-Info -type Info -msg "Found $VMCount Virtual machines in $($ResourceGroup.ResourceGroupName)"
                "        VirtualMachine = @(" | Out-File -FilePath $DataFile -Append
                "            @{" | Out-File -FilePath $DataFile -Append
                $VMs | % {
                    $VM = $_
                    $VMCount = $VMCount-1
                    "                Name = '$($VM.Name)'" | Out-File -FilePath $DataFile -Append
                    $nic = ($VM.NetworkProfile.NetworkInterfaces.Id).split('/')[-1]
                    $nicinfos = Get-AzNetworkInterface -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $nic
                    $sub = $nicInfos.IpConfigurations.Subnet.id.split('/')[-1]
                    $vnet = $nicInfos.IpConfigurations.Subnet.id.split('/')[-3]
                    $fullsub = "$($vnet)/$($sub)"
                    $Azstatus = (get-azvm -name $VM.Name -ResourceGroupName $ResourceGroup.ResourceGroupName -status).Statuses[-1].DisplayStatus
                    "                ip = '$($nicInfos.IpConfigurations.PrivateIpAddress)'" | Out-File -FilePath $DataFile -Append
                    "                subnet = '$($fullsub)'" | Out-File -FilePath $DataFile -Append
                    "                status = '$($Azstatus)'" | Out-File -FilePath $DataFile -Append
                    "                disk = @(" | Out-File -FilePath $DataFile -Append
                    "                    @{" | Out-File -FilePath $DataFile -Append
                    $OsDiskName = $VM.StorageProfile.OsDisk.ManagedDisk.id.split("/")[-1]
                    "                         name = '$($OSDiskName)'" | Out-File -FilePath $DataFile -Append
                    "                         kind = 'OsDisk'" | Out-File -FilePath $DataFile -Append
                    $DiskInfos = get-azdisk | ? { $_.id -like "*$OsDiskName" }
                    "                         sku = '$($DiskInfos.Sku.Tier)'" | Out-File -FilePath $DataFile -Append
                    "                         size = '$($DiskInfos.DiskSizeGB)'" | Out-File -FilePath $DataFile -Append
                    if ($VM.StorageProfile.DataDisks) {
                        "                    }," | Out-File -FilePath $DataFile -Append
                        $DataDiskCount = $VM.StorageProfile.DataDisks.count
                        Foreach ($Disk in $VM.StorageProfile.DataDisks) {
                            $DataDiskCount = $DataDiskCount-1
                            "                    @{"| Out-File -FilePath $DataFile -Append
                            "                         name = '$($Disk.Name)'" | Out-File -FilePath $DataFile -Append
                            "                         kind = 'DataDisk'" | Out-File -FilePath $DataFile -Append
                            $DiskInfos = get-azdisk | ? { $_.id -like "*$($Disk.Name)" }
                            "                         sku = '$($DiskInfos.Sku.Tier)'" | Out-File -FilePath $DataFile -Append
                            "                         size = '$($DiskInfos.DiskSizeGB)'" | Out-File -FilePath $DataFile -Append
                            if ($DataDiskCount -ge 1) {
                                "                    }," | Out-File -FilePath $DataFile -Append
                            }
                            else {
                                "                    }" | Out-File -FilePath $DataFile -Append
                            }
                        }
                    }
                    else {
                        "                    }" | Out-File -FilePath $DataFile -Append
                    }
                    "                )" | Out-File -FilePath $DataFile -Append           
                    if ($VMCount -ge 1) {
                        "            }," | Out-File -FilePath $DataFile -Append 
                        "            @{" | Out-File -FilePath $DataFile -Append 
                    }
                    else {
                        "            }" | Out-File -FilePath $DataFile -Append
                        "        )" | Out-File -FilePath $DataFile -Append
                    }
                }
            }
            # EOF RG
            if ($RGCount -ge 1) {
                "      }," | Out-File -FilePath $DataFile -Append 
                "      @{" | Out-File -FilePath $DataFile -Append
            }
            else {
                "      }" | Out-File -FilePath $DataFile -Append
                "   )" | Out-File -FilePath $DataFile -Append
            }
        }

            $Vnets = Get-AzVirtualNetwork | where { $_.Name -like "xxx*"}
            $VNetCount = $VNets.count
            if ($VNetCount -gt 0) {
                "    VirtualNetwork = @(" | Out-File -FilePath $DataFile -Append
                "        @{" | Out-File -FilePath $DataFile -Append        
            }
            Write-Info -type Info -msg "$VNetCount Virtual Network found in $Subscription."
            Foreach ($VNet in $Vnets) {
                $VNetCount = $VNetCount-1
                Write-Info -type Info -msg "Working on $($Vnet.Name) Virtual Network - Still $VNetCount Virtual Network to analyze."
                "                Name = '$($Vnet.Name)'" | Out-File -FilePath $DataFile -Append
                "                ResourceGroup = '$($Vnet.ResourceGroupName)'" | Out-File -FilePath $DataFile -Append
                "                range = '$($Vnet.AddressSpace.AddressPrefixes)'" | Out-File -FilePath $DataFile -Append
                "                Subnet = @(" | Out-File -FilePath $DataFile -Append
                "                    @{" | Out-File -FilePath $DataFile -Append
                $SubnetCount = $Vnet.subnets.count
                Foreach ($Subnet in $Vnet.subnets) {
                    $SubnetCount = $SubnetCount - 1
                    "                        Name = '$($subnet.Name)'" | Out-File -FilePath $DataFile -Append
                    "                        Range = '$($subnet.AddressPrefix)'" | Out-File -FilePath $DataFile -Append
                    # Get NSG (if there is)
                    if ($Subnet.NetworkSecurityGroup) {
                        "                        nsg = @{" | Out-File -FilePath $DataFile -Append
                        $nsg = ($Subnet.NetworkSecurityGroup).Id.split('/')[-1]
                        "                            name = '$($nsg)'" | Out-File -FilePath $DataFile -Append
                        "                        }" | Out-File -FilePath $DataFile -Append    
                    }
                    # Get UDR if there is
                    if ($Subnet.RouteTable) {
                        "                        udr = @{" | Out-File -FilePath $DataFile -Append
                        $udr = ($Subnet.RouteTable).Id.split('/')[-1]
                        "                            name = '$($udr)'" | Out-File -FilePath $DataFile -Append
                        "                        }" | Out-File -FilePath $DataFile -Append    
                    }
                    #EPF Subnet
                    if ($SubnetCount -ge 1) {
                        "                    }," | Out-File -FilePath $DataFile -Append
                        "                    @{" | Out-File -FilePath $DataFile -Append 
                    }
                    else {
                        "                    }" | Out-File -FilePath $DataFile -Append
                        "                )" | Out-File -FilePath $DataFile -Append
                    }            
                }
                #EOF Vnet
                if ($VNetCount -ge 1) {
                    "       }," | Out-File -FilePath $DataFile -Append 
                    "        @{" | Out-File -FilePath $DataFile -Append 
                }
                else {
                    "        }" | Out-File -FilePath $DataFile -Append
                    "    )" | Out-File -FilePath $DataFile -Append
                }
            }
            # Get All storage Account
            "    StorageAccount = @(" | Out-File -FilePath $DataFile -Append
            "        @{" | Out-File -FilePath $DataFile -Append
            $StorageAccounts = Get-AzStorageAccount | where { $_.StorageAccountName -like "xxx*"}
            $SACount = $StorageAccounts.Count
            Write-Info -type Info -msg "$SACount Storage Account found in $Subscription."
            Foreach ($Storage in $StorageAccounts) {
                $SACount = $SACount-1
                Write-Info -type Info -msg "Working on $($Storage.StorageAccountName) Storage Account - Still $SACount Storage Account to analyze."
                "            Name = '$($Storage.StorageAccountName)'" | Out-File -FilePath $DataFile -Append
                "            ResourceGroup = '$($Storage.ResourceGroupName)'" | Out-File -FilePath $DataFile -Append
                $temp = $Storage.context.ConnectionString.Split(";")[-1].trim()
                [string]$Key = $temp -split "AccountKey="
                "            AccountKey = '$($Key)'" | Out-File -FilePath $DataFile -Append
                #check if there are containers
                $Context = New-AzStorageContext -StorageAccountName $Storage.StorageAccountName -StorageAccountKey $Key
                $Containers = Get-AzStorageContainer -Context $context
                $ContainersCount = $Containers.Count
                if ($Containers) {
                    "            container = @(" | Out-File -FilePath $DataFile -Append
                    "                @{" | Out-File -FilePath $DataFile -Append
                    Foreach ($Container in $Containers) {
                        $ContainersCount = $ContainersCount-1
                        "                    Name = '$($Container.Name)'" | Out-File -FilePath $DataFile -Append
                        if ($ContainersCount -ge 1) {
                            "                 }," | Out-File -FilePath $DataFile -Append 
                            "                 @{" | Out-File -FilePath $DataFile -Append 
                        }
                        else {
                            "                 }" | Out-File -FilePath $DataFile -Append
                            "            )" | Out-File -FilePath $DataFile -Append  
                        }
                    }
                } 
                # Check if there are file shares
                $Shares = Get-AzStorageShare -context $context
                $SharesCount = $Shares.Count
                if ($Shares) {
                    "            Share = @(" | Out-File -FilePath $DataFile -Append
                    "                @{" | Out-File -FilePath $DataFile -Append
                    Foreach ($Share in $Shares) {
                        $SharesCount = $SharesCount-1
                        "                    Name = '$($Share.Name)'" | Out-File -FilePath $DataFile -Append
                        if ($SharesCount -ge 1) {
                            "                 }," | Out-File -FilePath $DataFile -Append 
                            "                 @{" | Out-File -FilePath $DataFile -Append 
                        }
                        else {
                            "                 }" | Out-File -FilePath $DataFile -Append
                            "            )" | Out-File -FilePath $DataFile -Append  
                        }
                    }
                }

                if ($SACount -ge 1) {
                    "         }," | Out-File -FilePath $DataFile -Append 
                    "         @{" | Out-File -FilePath $DataFile -Append 
                }
                else {
                    "         }" | Out-File -FilePath $DataFile -Append
                    "     )" | Out-File -FilePath $DataFile -Append  
                }    
            }    
        "}" | Out-File -FilePath $DataFile -Append
        }
        Catch {
            Write-Info -type Error -msg "Fail to create hashtable. Error: $($_.Exception.Message)"
            throw
        }
    }
}