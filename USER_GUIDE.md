# User Guide

## auth_type to support different authentication mechanisms

In addition to the existing authentication mechanisms, if we want to add new authentication then we will be adding them in the configuration by using auth_type

Example Configuration for basic authentication:

```
output {    
    opensearch {        
          hosts  => ["https://hostname:port"]     
          auth_type => {            
              type => 'basic'           
              user => 'admin'           
              password => 'admin'           
          }             
          index => "logstash-logs-%{+YYYY.MM.dd}"       
   }            
}               
```
### Parameters inside auth_type

- type (string) - We should specify the type of authentication
- We should add credentials required for that authentication like 'user' and 'password' for 'basic' authentication
- We should also add other parameters required for that authentication mechanism like we added 'region' for 'aws_iam' authentication

## Configuration for AWS IAM Authentication

To run the Logstash Output Opensearch plugin using aws_iam authentication, simply add a configuration following the below documentation.

Example Configuration:

```
output {        
   opensearch {     
          hosts => ["https://hostname:port"]              
          auth_type => {    
              type => 'aws_iam'     
              aws_access_key_id => 'ACCESS_KEY'     
              aws_secret_access_key => 'SECRET_KEY'     
              region => 'us-west-2'         
          }         
          index  => "logstash-logs-%{+YYYY.MM.dd}"      
   }            
}
```

### Required Parameters

- hosts (array of string) - AmazonOpensearchService domain endpoint : port number
- auth_type (Json object) - Which holds other parameters required for authentication
    - type (string) - "aws_iam"
    - aws_access_key_id (string) - AWS access key
    - aws_secret_access_key (string) - AWS secret access key
    - region (string, :default => "us-east-1") - region in which the domain is located
    - if we want to pass other optional parameters like profile, session_token,etc. They needs to be added in auth_type
- port (string) - AmazonOpensearchService listens on port 443 for HTTPS
- protocol (string) - The protocol used to connect to AmazonOpensearchService is 'https' 

### Optional Parameters
- The credential resolution logic can be described as follows:
  - User passed aws_access_key_id and aws_secret_access_key in configuration
  - Environment variables - AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (RECOMMENDED since they are recognized by all the AWS SDKs and CLI except for .NET), or AWS_ACCESS_KEY and AWS_SECRET_KEY (only recognized by Java SDK)
  - Credential profiles file at the default location (~/.aws/credentials) shared by all AWS SDKs and the AWS CLI
  - Instance profile credentials delivered through the Amazon EC2 metadata service
- template (path) - You can set the path to your own template here, if you so desire. If not set, the included template will be used.
- template_name (string, default => "logstash") - defines how the template is named inside Opensearch

