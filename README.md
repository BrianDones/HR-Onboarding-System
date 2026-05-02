# HR Onboarding System
The HR Onboarding System is designed to utilize AWS API Gateway and backend Lambda functions to emulate an environment where newly added employee information is stored in a database (DynamoDB). An event-driven based integration is also configured between the DynamoDB database stream and the company's Slack Workspace to ensure new employees are automatically invited to the Slack Workspace via email at their newly generated unique company email.

## Prerequisites and Set-Up

### 1. Install Terraform
If you already have Terraform installed, move on to the next step. If you need to install Terraform, follow the Terraform [install instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) for your Operation System.

### 2. Create an AWS Account
To set up our system, we will be hosting the infrastructure in the Amazon Web Services (AWS) cloud. If you already have an AWS account, move on to the next step. If you need to sign up for an AWS account, please review the documentation regarding [free tier AWS account](https://aws.amazon.com/free/) and [register](https://signin.aws.amazon.com/signup?request_type=register).

**Important Note**: Please review the [Getting Started](https://docs.aws.amazon.com/accounts/latest/reference/getting-started.html) guide from AWS to ensure you have followed best practices to secure your new AWS account. 

### 3. Create an IAM Policy for Terraform
You should never use your AWS **Root** account. Instead, we are going to set up an IAM SSO user within IAM Identity Center. 
1. Log into the [AWS Management Console](https://console.aws.amazon.com/) and search for **IAM**.
2. Select **Policies** > **Create policy**. 
3. Click on the **JSON** tab, paste in the content of the **Terraform-Permissions.json** file found in this github repo, then select **Next**. 

**Important Note**: Make sure you replace the AWS Account ID with your unique AWS Account ID and you use the name of your S3 bucket where you will host the Terraform State file. Do NOT share these values if you end up storing any of your files in github or some publicly accessible space. 

4. Name your policy *Terraform-Permissions* and click **Create policy**. 

### 4. Create your Terraform AWS Credentials
1. Search for **IAM Identity Center** at the top of the AWS Console.
2. Click **Enable** and set up IAM Identity Center. *Note*: Make sure you are in the appropriate region in the top of the AWS console. I used *us-east-1*. 
3. Select **Users** > **Add user**. Provide a username (.e.g. Terraform-User) and fill in the rest of the user's details. 
4. Select **Next** > **Next** > **Add user**. If you selected the option to setup your password through email, follow those instructions; otherwise, use the password that was provided.
5. Go to **Permission sets** > **Create permission set**. Select **Custom permission set** > **Next**.
6. Click on **Custom managed policies** and type in the **Terraform-Permissions** policy name in the text field. Then click **Next**. 
7. Give your permission set a name, set an appropriate session duration that works for you (I used the default 1 hour), then click **Next**. Select **Create**. 
8. Click on **AWS accounts**. If you already had an AWS account and you have Organizations configured, you may see more AWS accounts listed here. Select the AWS account where Terraform will be deploying the infrastructure and click on **Assign users or groups**. Click the *Users* tab, select your user, and then click **Next**. 
9. Select your permission set, then click **Next** > **Submit**.

### 5. Configure your shell with your Terraform Credentials
1. If you do not already have the AWS CLI installed on your workstation, following the AWS [installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). 

2. Run the following command from your shell: 
```bash
aws configure sso
```
3. Follow the prompt: 
	- **SSO session name**: *terraform-session*
	- **SSO start URL**: (Copy this from the IAM Identity Center dashboard in the AWS Console. It will look like `https://d-xxxx.awsapps.com/start`)
	- **SSO region**: *Your region*
	- **Registration Scopes**: *Hit Enter for the default*
4. You should get a login page to pop up in your default browser. If your browser does not open, open the provided URL then login. 
5. Your shell should update with the AWS Account ID and role name (this will be the name of the permission set we created earlier). Type in your region and hit enter. 
6. Hit enter again if you are okay with json as the default output format. 
7. Type in your profile name for your user. I used *Terraform-User*. Run the following command from your shell to login: 
```bash
aws sso login --profile Terraform-User
```

### 6. Create an S3 bucket for our Terraform State file
While we can keep the Terraform State file saved locally on our workstation, we would realistically need to be able to work on the same code and templates for our infrastructure with other colleagues. For this reason, we will be managing and saving our Terraform State file in an centralized S3 bucket which we can secure with a bucket policy as needed. 
1. Search for **S3** at the top of the AWS Console.
2. Make sure you are in the correct region, then select **Create bucket**. 
3. Give your S3 bucket an appropriate name (I called mine dones-terraform-state). Change the **Bucket namespace** value to *Account Regional namespace*. Leave all the other default settings as is **except** for Bucket Versioning. Make sure versioning is enabled. Click **Create bucket**.

### 7. Create the Slack Token Secret
1. Search for **Secrets Manager** at the top of the AWS Console. 
2. Click **Store a new secret**. 
3. Set the **Secret type** to *Other type of secret* and set the following key/value pair: 
	Key = token
	Value = this-is-your-actual-slack-token

**Important Note**: If we use this solution in Production, we will need to update the value to the actual Slack token for our Company's Slack Workspace.

4. Click **Next**, give your secret credentials a name (I used "slack/token"), then click **Next** > **Next** > **Store**. 

## HR Onboarding System Cloud Architecture and Technical Considerations

For our System's architecture we will be focusing on an **serverless event-driven** type of architecture. By using a serverless event-driven approach, we can prioritize scalability, cost-effiency, and leverage security options. 

### Access Layer: Amazon API Gateway over ALB/ELBs with Auto Scaling Groups
- **Cost Efficiency**: With EC2 instances and Load Balancers, you pay for the uptime of the servers regardless if the system is being used or not. With API Gateway, you only pay for the requests that are made, so by leverage the "pay for what you use" nature of API Gateway, we significantly decrease our cost.

- **Security Features**: 
	1. DDoS Protection - In front of API Gateways we have the AWS edge network that provides protection against common web attacks. EC2 instances need to be protected using Security Groups, NACLs, and AWS Shield increasing the cost and what we need to be managed. 

	2. Cognito Integration - API Gateway has a built-in authorizer for Amazon Cognito simplifying the integration and allows us to use JSON Web (JWT) Tokens for authentication instead of keys for IAM users. Setting up a similar security solution on EC2 instances would require custom code to handle and validate the JWT token. 

	**Note**:We will use this later on in our system after we have set up the fundamental parts first. 

- **Scalability**: Scaling an environment with an ALB/EC2 setup would involve configuring Auto Scaling Groups. This may result in the front end API being slow or unresponsive while the ASG "warms-up" in reponse to sudden, rapid increases in traffic. API Gateway scales instantly and automatically without any additional configuration or warming up needed. 

- **Maintainance/Patching**: With our API Gateway and Lambda solution, we have no maintenance or patching involved! AWS handles the maintenance and patching requirements of the underlining infrastructure -- all we need to worry about is configuring our solution correctly. With the ALB and Auto Scaling Group solution, performing maintenances and OS patching of the EC2 instances in the ASG would be our responsibility. 

- **Complexity**: The complexity of our API Gateway and Lambda solution is very low. Most of the configuration and work goes into defining the resources within Terraform. There is also no need to define VPCs, Subnets, or Security Groups -- our API Gateway is available to us through a publicly accessible endpoint which can be secured with the addition of Cognito. The ALB and Auto Scaling Group solution would be much more involved. Not only are we going to have to define our network resources (VPCs, Subnets, Security Groups, any service endpoints required, etc) but we also need to figure out how we are going to get the EC2 instances in our Auto Scaling Group into our ideal state with our code/application installed. This could mean baking AMIs with our code/application and any dependencies already installed or perhaps using CodeDeploy to handle deploying and configuring our code/application. AMI baking means anytime we need to patch or update our code, we need to run our baking process and create a new AMI. CodeDeploy would increase the deployment time of new EC2 instances when scaling events occur. We would also need to write up deployment scripts to handle installing dependencies and configure the application.

### Compute Layer: AWS Lambda

AWS Lambda is a great choice for our compute layer because we can decouple our solution into seperate lambda functions that handle specific tasks and features (e.g. `hr-processor`, `slack-provisioner`, etc). By breaking up our solution into these split lambda functions, our HR Onboarding System will not fail to add new employee information if the Slack Provisioning API fails. We can always retry the Slack invitation at a later point independent of the other lambda functions. We are also better able to troubleshoot issues with our lambda functions when our functions are designed to focus on one specific task. Similar to API Gateway, Lambda is also a cost-efficient option for us due to the pay for what you use nature of Lambda. 

### Data Layer: Amazon DynamoDB with Streams

We will use DynamoDB for our solution due to the following: 
1. DynamoDB is instantly available and able to handle bursts of traffic without the need to "warm up" connections. There are no persistent conections to manage so Lambda can scale to thousands of concurrent executions. 
2. We can leverage DynamoDB Streams to provide a real-time stream of every change that happens in the table giving us the event-driven integration we need.
3. DynamoDB has schema flexibility so if we need to add new employee information at a later time, we can update those fields in our Lambda function. This is way more flexible and convenient than solutions with strict schemas that would require migrating our data every time we need to change the employee data structure. 

### Security: AWS Secrets Manager and AWS Cognito

AWS Secrets Manager is used to store and encrypt at rest our Slack Token so the token is not visible in plain text as an environment variable for our lambda functions. Our functions will be designed to retreive the secret so if we ever need to update our token we do not have to worry about updating any code or variables -- we only have to swap out the token in Secrets Manager. We can also use IAM policies to restrict access to the token. 

AWS Cognito will be used so we can restrict access to the API only to HR staff or members of the company that need to have access to that API. 

### Infrastructure as Code: Terraform

To help us and manage our solution, we will be using Terraform as our Instracture as Code (IaC) tool for the following reasons: 

1. Terraform can be used to deploy resource on multiple cloud providers unlike proprietary solutions like CloudFormation allowing us more flexibility depending on our needs. 
2. Terraform can also handle deploying resources in parallel significantly reducing the time to deploy. 
3. Terraform is very easy to use. By running `terraform plan` we can see exactly what Terraform will do before making the changes. 
4. Terraform keeps track of resources in the Terraform State file so if someone manually changes resources, Terraform can detect those changes (this is know as drift). 
5. If we want to deploy different environments (such as  production, staging, or development) with the same solution we can easily do so and manage those deployments with Terraform. 
6. When we are ready to remove all our resources for this solution, we can run a `terraform destroy` command and Terraform will delete all resources that Terraform manages. 

**Note**: The resources that were manually created outside of Terraform that was part of our setup does need to be manually deleted.

## Deploying the HR Onboarding System
1. To deploy the infrastructure and resources for our solution, we need to first log in with our Terraform credentials we set up earlier:

```bash
$ aws sso login --profile Terraform-User
```

You should get a long link that starts with `https://odic*` and a tab should open up in your default browser prompting you to login with your Terraform-User credentials. If you do not see this tab open, copy the link into the browser of your choice and login. 

2. Next we need to initialize Terraform which we can do by running the following command from the directory/folder we have our Terraform templates saved for this project: 

```bash
$ pwd
/c/Users/Brian/path/to/the/project/HR-Onboarding-System

$ terraform init -backend-config="backend.conf"
```
**Note**: An example of the backend.conf file can be found in `Example Files/backend-example.txt` of this project repository. Be sure to update the file for your specific S3 bucket ARN and SSO User Profile. 

3. Ensure that the Terraform files are appropriately formatted and verify there are no errors: 

```bash
$ terraform fmt
$ terraform validate
```

You can also run a plan to see a list of the resources and changes Terraform will perform: 
```bash
$ terraform plan
```

4. If there are no error messages with the validate or plan commands, run a terraform apply: 

```bash
$ terraform apply
```
*Answer 'yes' when prompted by terraform*

5. After Terraform finishes building all the resources, you should see a similar output to the below. Log into your AWS console and verify your resources were successfully built.

```bash
Apply complete! Resources: 23 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint = "https://<API ID>.execute-api.us-east-1.amazonaws.com/staging/employees"
client_id = "<Client ID>"
dynamodb_table_arn = "arn:aws:dynamodb:us-east-1:<AWS_Account_ID>:table/EmployeesTable"
dynamodb_table_name = "EmployeesTable"
hr_processor_lambda_name = "hr_processor"
hr_processor_role_arn = "arn:aws:iam::<AWS_Account_ID>:role/hr-processor-role"
user_pool_id = "<Cognito User Pool ID>"
```

**Important Note**: Be sure to save these values, you will need some of those values to interact with the API. 