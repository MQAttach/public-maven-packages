# MQAttach Maven Public Repo #
Public Repo used by MQAttach Development Team to store and share Maven artifacts that require Public access.

This repository is also used to store and share artifacts for the IntegratD Logging Connector for Boomi that 
cannot be shared via the Boomi Component Exchange to due to security restrictions.

# IntegratD Boomi Connector Libraries #

### Additional MQ Messaging Server Libraries ###

Please download the following zip files, unzip them and upload the contents to your Boomi account library to use the IntegratD Logging Connector with the appropriate MQ Messaging Server.
* [Azure Service Bus](https://mqattach.github.io/public-maven-packages/standalone/azure-servicebus-jms-1.0.2.zip)

1. Unzip the file 
2. Add all files into your Boomi Integration account library (Setup > Account Libraries),
3. Using the Boomi Integration Interface, create a new Custom Library component called Azure Service Bus
4. Add all these files to that component and save it  
5. Deploy the component to the appropriate Atom, Molecule, Atom Cloud, or environment.
6. You should now have support for Azure Service Bus in your IntegratD for Boomi Logging Connector

the JAR files that it references are
deployed to the /{atom installation_directory}/userlib/
