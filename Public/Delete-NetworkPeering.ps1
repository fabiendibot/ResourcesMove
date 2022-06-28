Function Delete-NetworkPeering {
    param (
        [String]$VirtualNetwork,
        [String]$ResourcegroupName
    )
    Write-Info -type Info -msg "Gathering all peering associated to $VirtualNetwork in $ResourcegroupName"
    $PeeringList = get-AzVirtualNetworkPeering -VirtualNetworkName $VirtualNetwork -ResourceGroupName $ResourcegroupName

    ForEach ($Peering in $PeeringList) {

        Try {
            Write-Info -type Info -msg "Deleting $($Peering.Name)"
            Remove-AzVirtualNetworkPeering -Name $Peering.Name -VirtualNetworkName $VirtualNetwork -ResourceGroupName $ResourcegroupName -Force
            Write-Info -type Success -msg "Deleting $($Peering.Name)"
        }
        Catch {
            Write-Info -type Warning -msg "Deleting $($Peering.Name) failed. Error: $($_.Exception.Message)"
        }

    }


}