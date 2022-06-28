Function Backup-RBAC {
    param (
        [String]$SubSource = "",
        [String]$FileName = "RBAC-SubSource_Archives.csv"
    )

    $RbacBackup  = @()

    Try {
        Write-Info -type Info -msg "Connecting: subscription ID: $($SubSource)"
        Select-AzSubscription -SubscriptionId $SubSource -Force | Out-Null
        Write-Info -type Success -msg  "Connected subscription ID: $($SubSource)"
    }
    Catch {
        Write-Info -type Error -msg "[Error] - Connecting tenant and/or selecting subscrition failed. Error: $($_.Exception.Message)"
        throw
    }

    Try {
        Write-Info -type Info -msg "Backup all RBAC assignements in subscription $($SubSource)"
        $RoleAssignement = Get-AzRoleAssignment | Where-Object { $_.Scope -like "*sdc3*"}
        Write-Info -type Info -msg "$($RoleAssignement.count) role assignements found."
        Foreach ($Assignement in $RoleAssignement) {
            if (($Assignement.Scope -notlike "*managementGroups*") -and ($Assignement.Scope -like "/subscriptions/$($SubSource)*")) {
                $RbacBackup += [PSCustomObject]@{
                    Scope = "$($Assignement.Scope)"
                    DisplayName = "$($Assignement.DisplayName)"
                    SignInName = "$($Assignement.SignInName)"
                    RoleDefinitionName = "$($Assignement.RoleDefinitionName)"
                    ObjectType = "$($Assignement.ObjectType)"
                }
            }
        }

        # Backup as file just in case...
        Write-Info -type Info -msg "Exporting role assignements in $($filename) as a second backup"
        $RbacBackup | Export-Csv $FileName -force
        Write-Info -type Success -msg "Role assignements exported in RBAC-CSP.csv"
        Write-Info -type Success -msg "Backup all RBAC assignements in subscription $($SubSource)"
    }
    Catch {
        Write-Info -type Error -msg "Failed to backup RBAC assignements. Error: $($_.Exception.Message)"
        throw
    }
}