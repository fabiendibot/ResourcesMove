Function Merge-Resources {
    param (
        [String]$SubSource,
        #[String]$TargetSub,
        [String]$VirtualNetworkRG,
        [Array]$WaveRGs = @('xxx-123456-prod-rg')
    )

    Begin {
        $TotalStartTime = $(get-date)
    }
    Process {
        Try {
            Write-Info -type Info -msg "Connecting: Source subscription ID: $($SubSource)"
            while ((Get-AzContext).Subscription.id -ne $SubSource) {
                Select-AzSubscription -SubscriptionId $SubSource -Force | Out-Null
            }
            Write-Info -type Success -msg  "Connected Source subscription ID: $($SubSource)"
        }
        Catch {
            Write-Info -type Error -msg "[Error] - Connecting tenant and/or selecting subscrition failed. Error: $($_.Exception.Message)"
            throw
        }


        Write-Info -type Info -msg " Getting all Resource Groups in Source subscription $($SubSource)"

        $i = 0
        Foreach ($RG in $WaveRGs) {
            $i = $i+1
            $Moveable = @()
            $RGStartTime = $(get-date)
            Try {
                Write-Info -type Info -msg "Listing all non parent resources Types in $($RG)"
                $RGResources = Get-AzResource -ResourceGroupName $RG | Where-Object { -not $_.ParentResource}
                
                if ($RGResources.count -gt 0) {
                    Try {
                        Foreach ($Resource in $RGResources) {
                            $Moveable += "$($Resource.ResourceId)"                              
                        }

                        Write-Info -type Success -msg "Found $($Moveable.count) Resources migrables in $($RG)"

                    }
                    Catch {
                        Write-Info -type Error -msg "Impossible to collect all migreables ressource ids. Error: $($_.Exception.Message)"
                        throw
                    }

                    Try {
                        Write-Info -type Info -msg "Move resources from $($RG) to $($VirtualNetworkRG)"
                        Move-AzResource -destinationResourceGroupName $VirtualNetworkRG -ResourceId $Moveable -Force
                        $RGelapsedTime = $(get-date) - $RGStartTime
                        $RGTime = "{0:HH:mm:ss}" -f ([datetime]$RGelapsedTime.Ticks)
                        $TotalelapsedTime = $(get-date) - $TotalStartTime
                        $totalTime = "{0:HH:mm:ss}" -f ([datetime]$TotalelapsedTime.Ticks)
                        Write-Info -type Success -msg "Move resources from $($RG) to $($VirtualNetworkRG) - RG: $($i)/$($WaveRGs.count) - Time for this RG: $($RGTime) - Total Time Elapsed: $($totalTime)"
                    }
                    Catch {
                        if ( $_.Exception.Message -like  "*All*move*in*provider*succeeded*") { 
                            continue 
                        }
                        else {
                            Write-Info -type Error -msg "impossible to move resources to $($VirtualNetworkRG). Error: $($_.Exception.Message)"
                            throw
                        }
                    }
                }
                else {
                    Write-Info -type Warning -msg "No resources in $($RG) Resource Group, skipping"
                }
            }
            Catch {
                Write-Info -type Error -msg "Fail listing resources type in $($RG). Error: $($_.Exception.Message)"
                throw
            }
        }
    
        <#Try {
            Write-Info -type Info -msg "Move ALL resources to $($VirtualNetworkRG) in $($TargetSub)"
            $RGResources = Get-AzResource -ResourceGroupName $VirtualNetworkRG | Where-Object { -not $_.ParentResource}
            Foreach ($Resource in $RGResources) {
                $Moveable += "$($Resource.ResourceId)"                              
            }
            Move-AzResource -destinationResourceGroupName $VirtualNetworkRG -ResourceId $Moveable -DestinationSubscriptionId $TargetSub -Force
        }
        Catch {

        }#>
    } #end process
}