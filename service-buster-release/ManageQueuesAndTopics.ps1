Trace-VstsEnteringInvocation $MyInvocation

$ResourceGroupName= Get-VstsInput -Name "ResourceGroupName"
$Namespace= Get-VstsInput -Name "Namespace"
$DefinitionFile= Get-VstsInput -Name "DefinitionFile"
$RemoveUndefinedObjects= Get-VstsInput -Name "RemoveUndefinedObjects"

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
        Write-VstsTaskVerbose "TOPIC: The service bus topic $($Topic.name) already exists in the $Namespace namespace."
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
            Write-Output "TOPIC: The $($topic.name) topic in Resource Group $ResourceGroupName in the namespace $namespace has been successfully created."
        }
        else {
            Write-VstsTaskError "*** ERROR ***: The $($topic.name) topic in Resource Group $ResourceGroupName in the namespace $namespace was not created."
        }
    }

    foreach ($subscription in $topic.subscription) {

        # Create subscription if it doesn't exist
        if (Get-AzureRmServiceBusSubscription -ResourceGroupName $ResourceGroupName -Namespace $Namespace -Topic $topic.name -Name $subscription.name -ErrorAction SilentlyContinue) {
            Write-VstsTaskVerbose "SUBSCRIPTION: Subscription $($subscription.name) exists in the namespace $namespace."
        }
        else {
            New-AzureRmServiceBusSubscription `
                -ResourceGroupName $ResourceGroupName `
                -Namespace $Namespace `
                -Topic $topic.name `
                -Name $subscription.name `
                -DeadLetteringOnMessageExpiration $TRUE | Out-Null

            if ($? -eq $true) {
                Write-Output "SUBSCRIPTION: The $($subscription.name) subscription within the topic $($topic.name) has been successfully created."
            }
            else {
                Write-VstsTaskError "*** ERROR ***: The $($subscription.name) subscription within the topic $($topic.name) was not created."
            }
        }
        
        # Create rule if it doesn't exist
        foreach ($Rule in $subscription.rule) {
            if (Get-AzureRmServiceBusRule -ResourceGroupName $ResourceGroupName -Namespace $Namespace -Topic $topic.name -Subscription $subscription.name -Name $Rule -ErrorAction SilentlyContinue) {
                Write-VstsTaskVerbose "RULE: Service bus rule $rule exists in the namespace $namespace."
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
                    Write-Output "RULE: The $rule rule in the subscription $($subscription.name) has been successfully created."
                }
                else {
                    Write-VstsTaskError "*** ERROR ***: The $rule rule in the subscription $($subscription.name) was not created."
                }
                 
            }
        }
    }
}

##############################
###  Create Queues         ###
##############################

foreach ($queueName in $Data.queues) {

    # Check if queue already exists
    $CurrentQ = Get-AzureRmServiceBusQueue -ResourceGroup $ResourceGroupName -Namespace $Namespace -QueueName $QueueName -ErrorAction SilentlyContinue

    if($CurrentQ)
    {
        Write-VstsTaskVerbose "QUEUE: The queue $QueueName already exists in the $Namespace namespace."
    }
    else
    {
        Write-VstsTaskVerbose "QUEUE: The $QueueName queue does not exist."
        Write-VstsTaskVerbose "QUEUE: Creating the $QueueName queue in the $Namespace namespace..." 
        New-AzureRmServiceBusQueue `
            -ResourceGroup $ResourceGroupName `
            -Namespace $Namespace `
            -QueueName $QueueName `
            -EnablePartitioning $True | Out-Null

        if ($? -eq $true) {
            Write-Output "QUEUE: The $QueueName queue in Resource Group $ResourceGroupName in the $Namespace namespace has been successfully created."
        }
        else {
            Write-VstsTaskError "*** ERROR ***: The $QueueName queue in Resource Group $ResourceGroupName in the $Namespace namespace was not created."
        }
    }
}

if ($RemoveUndefinedObjects -eq $true) {

    #################################
    ###  Delete Undefined Queues  ###
    #################################

    Write-VstsTaskVerbose "Removing undefined queues, topics and subscriptions..."

    $queues = Get-AzureRmServiceBusQueue -ResourceGroupName $ResourceGroupName -Namespace $Namespace
    foreach ($queueName in $queues.name) {

        # Check if queue shouldn't exist
        if ($queueName -notin $Data.queues) {

            # Remove Queue
            Write-VstsTaskVerbose "QUEUE: The queue $queueName exists in the $Namespace namespace, but it is not defined in the configuration file."

            Remove-AzureRmServiceBusQueue `
            -ResourceGroup $ResourceGroupName `
            -Namespace $Namespace `
            -QueueName $queueName `
            -Confirm:$false | Out-Null

            if ($? -eq $true) {
                Write-Output "QUEUE: The $QueueName queue in Resource Group $ResourceGroupName in the $Namespace namespace has been successfully removed."
            }
            else {
                Write-VstsTaskError "*** ERROR ***: The $QueueName queue in Resource Group $ResourceGroupName in the $Namespace namespace was not removed."
            }

        }
    }

    ###################################################
    ###  Delete Undefined Topics and Subscriptions  ###
    ###################################################

    $topics = Get-AzureRmServiceBusTopic -ResourceGroupName $ResourceGroupName -Namespace $Namespace
    foreach ($topicName in $topics.name) {

        $subscriptions = Get-AzureRmServiceBusSubscription -ResourceGroupName $ResourceGroupName -Namespace $Namespace -topic $topicName
        $allowedSubscriptions = $($data.topics | where {$_.name -eq $topicName} | Select-Object -ExpandProperty subscription).name
        Write-VstsTaskVerbose "SUBSCRIPTION: The allowed subscriptions in the $topicName topic as defined in the configuration file are $allowedSubscriptions"

        foreach ($subscription in $subscriptions.name) {

            # Check if subscription shouldn't exist
            if ($subscription -notin $allowedSubscriptions) {

                # Remove subscription
                Write-VstsTaskVerbose "SUBSCRIPTION: The subscription $subscription exists in the $topicName topic, but it is not defined in the configuration file."

                Remove-AzureRmServiceBusSubscription `
                -ResourceGroupName $ResourceGroupName `
                -Namespace $Namespace `
                -Topic $topicName `
                -Name $subscription `
                -Confirm:$false | Out-Null

                if ($? -eq $true) {
                    Write-Output "SUBSCRIPTION: The $subscription subscription within the topic $topicName has been successfully removed."
                }
                else {
                    Write-VstsTaskError "*** ERROR ***: The $subscription subscription within the topic $topicName was not removed."
                }
            }
        }

        # Check if topic shouldn't exist
        if ($topicName -notin $Data.topics.name) {

            # Remove topic
            Write-VstsTaskVerbose "TOPIC: The topic $topicName exists in the $Namespace namespace, but it is not defined in the configuration file."

            Remove-AzureRmServiceBusTopic `
            -ResourceGroup $ResourceGroupName `
            -Namespace $Namespace `
            -TopicName $topicName `
            -Confirm:$false | Out-Null

            if ($? -eq $true) {
                Write-Output "TOPIC: The $topicName topic in Resource Group $ResourceGroupName in the $Namespace namespace has been successfully removed."
            }
            else {
                Write-VstsTaskError "*** ERROR ***: The $topicName topic in Resource Group $ResourceGroupName in the $Namespace namespace was not removed."
            }
        }
    }
}
else {
    Write-VstsTaskVerbose "Option set to Skip removal of undefined queues, topics and subscriptions."
}
Trace-VstsLeavingInvocation $MyInvocation
