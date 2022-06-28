Function Delete-RestorePointCollection {
    param (
        [String]$SubSource
    )
    Write-Info -type Info -msg "Gathering all restorepoints collections"
    $RestorePointCollectionList = Get-AzResource -ResourceGroupName * -ResourceType Microsoft.Compute/restorePointCollections

    Write-Info -type Info -msg "Found $($RestorePointCollectionList.count) in $subsource"

    ForEach ($RestorePointCollection in $RestorePointCollectionList) {

        Try {
            Write-Info -type Info -msg "Deleting $($RestorePointCollection.ResourceId)"
            $tmp = Remove-AzResource -ResourceId $RestorePointCollection.ResourceId -Force
            if ($tmp -eq "True") {
                Write-Info -type Success -msg "Deleting $($RestorePointCollection.ResourceId)"
            }
            else {
                Write-Info -type Warning -msg "Deleting $($RestorePointCollection.ResourceId) failed"
            }
        }
        Catch {
            Write-Info -type Warning -msg "Deleting $($RestorePointCollection.ResourceId) failed. Error: $($_.Exception.Message)"
        }

    }


}