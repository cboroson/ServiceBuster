
# Azure Service Buster

Configure Service Bus Topics, Queues and subscriptions from VSTS.

## Getting Started

Azure's Message Queueing solution, Service Bus, is easily deployed using ARM templates.  However, maintaining a complex or dynamic configuration of queues, topics and subscriptions in ARM templates quickly becomes unwieldy.  The problem often occurs when the development group requests Service Bus changes and must wait for the Azure admins to modify the template/parameters to deploy the change.

This solution uses Visual Studio Team Services to manage an Azure Service Bus through a specially formatted json file.  It can be configured for CI/CD where changes to the json file trigger a release that deploys the changes to the Service Bus.  This eliminates the middle-man and gives developers more control over the configuration. 

### Prerequisites

This extension assumes that the Service Bus namespace already exists in the specified subscription and resource group.  It will not create the namespace if it doesn't already exist (however this would probably be an easy change to implement).

## Configuration

Add this extenion in the usual way as a release task.  The only option is whether to delete any namespace resources that are not specifically defined in the configuration file.  Selecting the option to `Remove Undefined Objects` will enforce the deletion of any queues, topics and subscriptions that are not in the json configuration file. 

### Configuration file structure

The json configuration file should be configured using standard json syntax and structure.  A sample is shown below.

```
{
  "topics": [
    {
      "name": "topic-1",
      "subscription": [
        {
          "name": "foo"
      	},				
        {
          "name": "bar",
          "rule": "bar-Rule",
          "sqlFilter": "MessageType = 'someString'",
          "action": "set FilterTag = 'true'"
        }
      ]
    },
    {
      "name": "topic-2",
      "subscription": [
        {
          "name": "foo"
        }
      ]
    },
  ],
  "queues": [
    "queue-1",
    "queue-2"
  ]
}

```

### Topic resource settings

All topics will be created with default settings and the following options enabled.  There is currently no way to override these settings.
* Partitioning
* Batched operations
* Duplicate detection

### Subscription resource settings

All subscriptions will be created with default settings and the following options enabled.  There is currently no way to override these settings.
* Deadlettering on message expiration

### Queue resource settings

All topics will be created with default settings and the following options enabled.  There is currently no way to override these settings.
* Partitioning


## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* Craig Boroson 

See also the list of [contributors](https://github.com/cboroson/ServiceBuster/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Pascal Naber at Xpirit for VSTS code samples
