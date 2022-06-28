Function Get-VirtualNetworkDependencies {
    param ()

    Begin {
        Try {
            $Networks = Get-AzVirtualNetwork | Where-Object { $_.Name -like "xxx*"}
        }
        Catch {
            Write-Error "Impossible to list Virtual Networks"
        }

        Try {
            $AllVms = Get-AzVM
        }
        Catch {
            Write-Error "Impossible to list all VMs"
        }

        $SubnetArray = @()
        $Output = @()
        
    }    
    
    Process {
        $AllVMs |Foreach-Object{
            $Parent = $_
            $NicName = $Parent.NetworkProfile.NetworkInterfaces.Id.split('/')[-1]
            $nic = Get-AzNetworkInterface -name $NicName
            $Output += [PSCustomObject]@{
                VirtualMachineName = "$($Parent.Name)"
                Nic                = "$($Parent.NetworkProfile.NetworkInterfaces.Id)"
                IpConfig           = $Nic.IpConfigurations.Id
            }
        }

        Foreach ($Network in $Networks) {
            $Network.Subnets |Foreach-Object{
                $Service = $null
                $Subnet = $_
                $ipConfig = @()
                $Subnet.IpConfigurations |Foreach-Object{
                    $ipConfig += [PSCustomObject]@{
                        ID = "$($_.Id)"
                    }
                }

                $ipconfig |Foreach-Object{
                    $ipc = $_.Id
                    if ($ipc -like "*/providers/Microsoft.Network/loadBalancers/*") {
                        $lbName = (Get-AzLoadBalancer | Where-Object{ $_.FrontendIpConfigurations.Id -eq $ipc }).Name
                        $service = "$Service" + ";" + "$($lbName)"
                    }
                    elseif ($ipc -like "*/providers/Microsoft.Network/networkInterfaces/*") {
                        $temp = $Output | Where-Object{ $_.Ipconfig -eq $ipc }
                        $Service = "$Service" + ";" + "$($temp.VirtualMachineName)"
                    } 
                    elseif ($ipc -like "*/providers/Microsoft.Network/applicationGateways/*") {
                        $appGwName = (Get-AzApplicationGateway | Where-Object{ $_.FrontendIpConfigurations.Id -eq $ipc }).Name
                        $service = "$Service" + ";" + "$($appGwName)"
                    }
                    elseif ($ipc -like "*/providers/Microsoft.Network/virtualNetworkGateways/*") {
                        $VNetGwName = (Get-AzResourceGroup | Get-AzVirtualNetworkGateway | Where-Object{ $_.IpConfigurations.Id -eq $ipc }).Name
                        $service = "$Service" + ";" + "$($VNetGwName)"
                    }
                }

                if ($Subnet.ResourceNavigationLinks.Link -like "*/providers/Microsoft.ApiManagement/*") {
                    $ApiName = (Get-AzAPIManagement | Where-Object{ $_.VirtualNetwork.SubnetResourceId -eq $subnet.Id}).Name
                    $service = "$Service" + ";" + "$($ApiName)"
                } 

                if ($Subnet.RouteTable) {
                    $RouteTableID = $Subnet.RouteTable.Id
                }
                $ServiceEndpoint = $null
                $Subnet.ServiceEndpoints |Foreach-Object{
                    $ServiceEndpoint = "$($ServiceEndpoint)" + ";" + "$($_.Service)"  
                }

                $Delegation = "$($Subnet.Delegation.ServiceName)"

                $NSG = "$($Subnet.NetworkSecurityGroup.id)"
                $SubnetArray += [PSCustomObject]@{
                    VNetName   = "$($Network.Name)"
                    Name       = "$($Subnet.Name)"
                    Services   = $service
                    RouteTable = $RouteTableID
                    NSG        = $NSG
                    Endpoints  = $ServiceEndpoint
                    Delegation = $Delegation
                }
            }
        }
    }
    End {
        $SubnetArray | Export-Csv Dependecies-network.csv
    }
}