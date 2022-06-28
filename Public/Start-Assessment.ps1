Function Start-Assessment {
    param (
        $OutputFile = "ExcelReport.xlsx"
    ) 

    Begin {
        #Get All ressources
        $AllResources = Get-AzResource
        
        $WebRequest = invoke-webrequest "https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/move-support-resources" -Timeoutsec 1 -MaximumRedirection 1
        #Scrap All providers from website
        $WebSiteProviderList = ($WebRequest.ParsedHtml.getElementsByTagName('H2') | Where-Object { $_.InnerText -like "Microsoft.*"} | ForEach-Object { $_.InnerText} )

        #Now we know the number of provider we should loop on
        $WebSiteTables = @($WebRequest.ParsedHtml.getElementsByTagName('TABLE'))

        #number of tables and resource provider should be exactly the same
        if ($WebSiteProviderList.count -ne $WebSiteTables.count) {
            Write-Warning "Mismatch between number of resources providers and array number, script should be fixed"
            throw
        }

       
    }
    Process {

        # Build empty arrays to store results
        $ScrapedArray = @()
        $Result = @()
        $i = 0

        # Extract for each table the rows
        foreach ($table in $WebSiteTables) {
            
            $Rows = @($table.rows)

            #Filter Each first line as it's the header
            
            Foreach ($row in ($rows | Select-Object -skip 1)) {

                $cells = $row.cells

                # FOr the first one, we concat with provider name
                $ResourceType = $WebSiteProviderList[$i].trim() + "/" + $($cells[0].InnerText).replace(' ','').trim()
                $ScrapedArray += [PSCustomObject]@{
                    ResourceType = $ResourceType
                     ResourceGroup = "$($cells[1].InnerText.trim())"
                    Subscription = "$($cells[2].InnerText.replace(' ','').trim())"
                }

            }
            $i++

        }

        
        # Compare Moveable resources type
        Foreach ($Resource in $AllResources) {

            if ($ScrapedArray.ResourceType -contains $Resource.Type) {
                $Moveable = ($ScrapedArray | Where-Object {$_.ResourceType -eq $Resource.Type}).Subscription
                if ($Moveable -like "Yes-BasicSKU*") { 
                    # check resource type and Sku
                    if ($Resource.Type -eq "Microsoft.Network/loadBalancers") {
                        if ( (Get-AzLoadBalancer -Name $Resource.Name -ResourceGroupName $Resource.ResourceGroupName).Sku.Name -eq "Standard" ) { 
                            $Moveable = "No"
                        }
                        else { 
                            $Moveable = "Yes"
                        }
                    }
                    elseif ($Resource.Type -eq "Microsoft.Network/publicIPAddresses") {
                        if ( (Get-AzPublicIpAddress -Name $Resource.Name -ResourceGroupName $Resource.ResourceGroupName).Sku.Name -eq "Standard" ) { 
                            $Moveable = "No"
                        }
                        else { 
                            $Moveable = "Yes"
                        }
                    }
                    #check if VM is coming from marketplace
                    elseif ($Resource.Type -eq "Microsoft.Compute/virtualMachines") {
                        if ((Get-AzVM -Name $Resource.Name -ResourceGroupName $Resource.ResourceGroupName).Plan) {
                            $Moveable = "No"
                        }
                        else {
                            $Moveable = "Yes"
                        }
                    }
                    # Check DATAFactory
                    # Check if Virtual Network Peerings exist
                } 
            }
            else {
                $Moveable = "N/A"
            } 
            
            $Result += [PSCustomObject]@{
                Name = "$($Resource.Name)"
                Type = "$($Resource.Type)"
                RessourceGroup = "$($Resource.ResourceGroupName)"
                Moveable = $Moveable
                
            }
        }
    }
    End {
        # generate nice report
        # Add a data Worksheet
        $Result | Export-Excel $OutputFile -WorksheetName 'RawData' -AutoSize -AutoFilter
    }
}