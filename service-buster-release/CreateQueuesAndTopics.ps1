Trace-VstsEnteringInvocation $MyInvocation

$ResourceGroupName= Get-VstsInput -Name "ResourceGroupName"
$Namespace= Get-VstsInput -Name "Namespace"
$Location= Get-VstsInput -Name "Location"
$DefinitionFile= Get-VstsInput -Name "DefinitionFile"

$data = Get-Content -Raw -LiteralPath $DefinitionFile | ConvertFrom-Json

if (!($data)) { 
	Write-VstsTaskError "No data able to be imported from $DefinitionFile.  Exiting."
	Exit
}

################# Initialize Azure. #################
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Initialize-Azure

#######################
###  Topics         ###
#######################

foreach ($topic in $Data.topics) {
    
    # Create topic if it doesn't exist
    if (get-AzureRmServiceBusTopic -ResourceGroupName $ResourceGroupName -Namespace $Namespace -name $topic.name -ErrorAction SilentlyContinue) {
        Write-VstsTaskVerbose "The service bus topic $($Topic.name) already exists in the $Namespace namespace."
    }
    else {
        New-AzureRmServiceBusTopic `
            -ResourceGroupName $ResourceGroupName `
            -Namespace $Namespace `
            -name $topic.name `
            -EnablePartitioning $true `
            -EnableBatchedOperations $true `
            -RequiresDuplicateDetection $true | Out-Null

        if ($? -eq $true) {
            Write-Output "The $($topic.name) topic in Resource Group $ResourceGroupName in the namespace $namespace has been successfully created."
        }
        else {
            Write-VstsTaskError "ERROR: The $($topic.name) topic in Resource Group $ResourceGroupName in the namespace $namespace was not created."
        }
    }

    foreach ($subscription in $topic.subscription) {

        # Create subscription if it doesn't exist
        if (Get-AzureRmServiceBusSubscription -ResourceGroupName $ResourceGroupName -Namespace $Namespace -Topic $topic.name -Name $subscription.name -ErrorAction SilentlyContinue) {
            Write-VstsTaskVerbose "Subscription $($subscription.name) exists in the namespace $namespace."
        }
        else {
            New-AzureRmServiceBusSubscription `
                -ResourceGroupName $ResourceGroupName `
                -Namespace $Namespace `
                -Topic $topic.name `
                -Name $subscription.name `
                -DeadLetteringOnMessageExpiration $TRUE | Out-Null

            if ($? -eq $true) {
                Write-Output "The $($subscription.name) subscription within the topic $($topic.name) has been successfully created."
            }
            else {
                Write-VstsTaskError "ERROR: The $($subscription.name) subscription within the topic $($topic.name) was not created."
            }
        }
        
        # Create rule if it doesn't exist
        foreach ($Rule in $subscription.rule) {
            if (Get-AzureRmServiceBusRule -ResourceGroupName $ResourceGroupName -Namespace $Namespace -Topic $topic.name -Subscription $subscription.name -Name $Rule -ErrorAction SilentlyContinue) {
                Write-VstsTaskVerbose "Service bus rule $rule exists in the namespace $namespace."
            }
            else {
                New-AzureRmServiceBusRule `
                    -ResourceGroupName $ResourceGroupName `
                    -Namespace $Namespace `
                    -Topic $topic.name `
                    -Subscription $subscription.name `
                    -Name $Rule `
                    -SqlExpression $subscription.sqlFilter | out-null

                if ($? -eq $true) {
                    Write-Output "The $rule rule in the subscription $($subscription.name) has been successfully created."
                }
                else {
                    Write-VstsTaskError "ERROR: The $rule rule in the subscription $($subscription.name) was not created."
                }
                 
            }
        }
    }
}

#######################
###  Queues         ###
#######################

foreach ($queueName in $Data.queues) {

    # Check if queue already exists
    $CurrentQ = Get-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -Namespace $Namespace -QueueName $QueueName -ErrorAction SilentlyContinue

    if($CurrentQ)
    {
        Write-VstsTaskVerbose "The queue $QueueName already exists in the $Location region:"
    }
    else
    {
        Write-VstsTaskVerbose "The $QueueName queue does not exist."
        Write-VstsTaskVerbose "Creating the $QueueName queue in the $Location region..." 
        New-AzureRmServiceBusQueue `
            -ResourceGroup $ResourceGroupName `
            -Namespace $Namespace `
            -QueueName $QueueName `
            -EnablePartitioning $True | Out-Null

        if ($? -eq $true) {
            Write-Output "The $QueueName queue in Resource Group $ResourceGroupName in the $Location region has been successfully created."
        }
        else {
            Write-VstsTaskError "ERROR: The $QueueName queue in Resource Group $ResourceGroupName in the $Location region was not created."
        }
    }

}
Trace-VstsLeavingInvocation $MyInvocation
