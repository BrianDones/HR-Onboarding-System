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

**Important Note**: Make sure you replace the AWS Account ID with your unique AWS Account ID. Do NOT share this value if you end up storing any of your files in github or some publicly accessible space. 

4. Name your policy *Terraform-Permissions* and click **Create policy**. 

### 4. Create your Terraform AWS Credentials
1. Search for **IAM Identity Center** at the top of the AWS Console.
2. Click **Enable** and set up IAM identity Center. *Note*: Make sure you are in the appropriate region in the top of the AWS console. I used *us-east-1*. 
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

### 7. Create a Terraform Lock Table in DynamoDB
1. Search for **DynamoDB** at the top of the AWS Console.
2. Click **Create table**. 
3. Set the **Table name** to *terraform-lock-table*. Type in *LockID* as the **Partition key** with the type set to *String*. 
4. Click **Create table**. 

## HR Onboarding System Cloud Architecture and Technical Considerations