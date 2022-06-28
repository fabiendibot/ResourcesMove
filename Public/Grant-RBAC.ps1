Function Grant-RBAC {
    param (
        [String]$SubSource,
        [String]$SubDestination,
        [String]$FileName = "RBAC-SubSource_Archives.csv"
    )

    $RbacBackup  = @()


    Try {
        Write-Info -type Info -msg "Switch to subscription $($SubDestination)"
        while ((Get-AzContext).Subscription.id -ne $SubDestination) {
            Select-AzSubscription -SubscriptionId $SubDestination -Force | Out-Null
        }
        Write-Info -type Success -msg "Switch to subscription $($SubDestination)"
    }
    Catch {
        Write-Info -type Error -msg "Failing switch to subcription $($SubDestination). Error: $($_.Exception.Message)"
        throw
    }

    Try {
        Write-Info -type Info -msg "Restoring RBAC assignements"
        $RbacBackupImport = Import-Csv $FileName 
        Foreach ($line in $RbacBackupImport) {
            
            if (!($line.DisplayName -like "*Global*EntServ*Solutions*Ireland*Limited*")) { # CSP specific role
                $Scope = $line.scope.replace($SubSource,$SubDestination)
                #If not a user we need ObjectId
                if ($line.ObjectType -eq "Group") {
                    $ObjectId = (Get-AzADGroup -SearchString $line.DisplayName).Id
                }
                elseif ($line.ObjectType -eq "ServicePrincipal") {
                    $ObjectId = (Get-AzADServicePrincipal -SearchString $line.DisplayName).Id
                }
                elseif ($line.ObjectType -eq "User") {
                    $ObjectId = (Get-AzADUser -UserPrincipalName $line.SignInName).Id
                }

                #test if the assignement already exists 
                if (Get-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName "$($line.RoleDefinitionName)" -Scope $Scope -ea SilentlyContinue) {              
                    Write-Info -type Success -msg "Assignement for object $($line.SignInName) already present on $($scope)"
                }
                else {
                    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $line.RoleDefinitionName -Scope $Scope
                }
            }
        }
        Write-Info -type Success -msg "Restoring RBAC assignements done."
    }
    catch {
        Write-Info -type Error -msg "Fail to restore RBAC assignements. Error: $($_.Exception.Message)"
    }
}