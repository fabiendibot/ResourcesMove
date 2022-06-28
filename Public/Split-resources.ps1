Function Split-Resources {
    param (
        [String]$TargetSub,
        [String]$SharedRG,
        $WaveRGs = @('xxx-123456-prod-rg')
    )
    Begin {
        
        $TotalStartTime = $(get-date)
    }
    Process {
        Try {
            Write-Info -type Info -msg "Switch to target subscription $TargetSub"
            while ((Get-AzContext).Subscription.id -ne $TargetSub) {
                Select-AzSubscription -SubscriptionId $TargetSub -Force | Out-Null
            }
            Write-Info -type Success -msg "Switch to target subscription"
        }
        Catch {
            Write-Info -type Error -msg "Fail to switch to target subscription. Error: $($_.Exception.Message)"
            throw
        }

        Try {
            Write-Info -type Info -msg "Split Resources from $($SharedRG) to their respective RGs"
            foreach ($ResourceGroup in $WaveRGs) {
                $RGStartTime = $(get-date)
                #extracting AIP code
                [String]$AppCode = $($ResourceGroup).split('-')[1]
                Write-Info -type Info -msg "RG: $($ResourceGroup) - App Code: $AppCode"
                if ($ResourceGroup -like "xxx-*-prod-rg") { 
                    $pattern = "(xxx)$AppCode(w|l|p|a|s|q|qw|sw|aw)0[0-9]{2}"
                    Write-Info -type Warning -msg "$($pattern) used for production RG"
                }
                elseif ($ResourceGroup -like "xxx-*-preprod-rg") { 
                    $pattern = "(xxx)$AppCode(w|l|p|a|s|q|qw|sw|aw)1[0-9]{2}"
                    Write-Info -type Warning -msg "$($pattern) used for Preprod RG"
                }

                #Get all resources in $SubCSPSharedRG with this AIP Code
                $RGResourcesToMove = Get-AzResource -ResourceGroupName $SharedRG | Where-Object { -not $_.ParentResource} | Where-Object { $_.Name -match $pattern} #
                
                $Moveable = @()
                Foreach ($Resource in $RGResourcesToMove) {
                    #if (($MoveableResourceType -contains $Resource.Type) -and ($Notmigrable -notcontains $Resource.Type)) {
                        $Moveable += "$($Resource.ResourceId)"    
                    #}                            
                }
                Write-Info -type Info -msg "Move $($moveable.count) resources to $($ResourceGroup)"
                
                #Create RG if it not exists
                Try {
                    Get-AzResourceGroup -name $ResourceGroup -Ea silentlycontinue | Out-Null
                }
                Catch {
                    New-AzResourceGroup -Name $ResourceGroup -location 'westeurope'
                }

                if ($moveable.count -gt 0) {
                    Move-AzResource -destinationResourceGroupName $ResourceGroup -ResourceId $Moveable -Force -Ea silentlycontinue
                    $RGelapsedTime = $(get-date) - $RGStartTime
                    $RGTime = "{0:HH:mm:ss}" -f ([datetime]$RGelapsedTime.Ticks)
                    $TotalelapsedTime = $(get-date) - $TotalStartTime
                    $totalTime = "{0:HH:mm:ss}" -f ([datetime]$TotalelapsedTime.Ticks)
                    Write-Info -type Success -msg "Move $($moveable.count) resources to $($ResourceGroup) - Time for this RG: $($RGTime) - Total Time Elapsed: $($totalTime)"
                }
                else {
                    Write-Info -type Warning -msg "No resource to move to $($resourceGroup)"
                }

            }
            Write-Info -type Success -msg "Split Resources from $($SharedRG) done."
        }
        Catch {
            Write-Info -type Error -msg "Fail to split resources in respective resource groups. Error: $($_.Exception.Message)"
            throw
        }
    }
}