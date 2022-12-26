# ssl_checker

This repository contains code that is intended to check individual domains for SSL certificate expiration. This is intended to work with several AWS components: Lambda, an API gateway, and an SNS topic. I'll explain each step of the way and provide screenshots where applicable. This does include IaC components intended to be deployed with Terraform.

## What are we trying to do?

We want to...
1. Create a python script in AWS Lambda that checks domains for SSL cert expiration. This script needs to be able to accept **"host"** as an input. It also needs to provide JSON output. There's a few other requirements we have as well but they are in script comments -- some output variables that are needed.
2. Create an API Gateway. This *can* be super simple -- just allow HTTP POST only. This needs to connect to the above Lambda function.
3. Create test cases for the Lambda function. In this case, I'm setting up a single "good" test case and a single "bad" test case.
4. Connect the Lambda function to an SNS topic so that I can get emails on alerting.
5. Deploy all of the above with Terraform, allowing someone else to do it.

## 1. The Python Script
Let's start with the python script. I've linked the [final, full version here](https://github.com/GittyUpPartner/ssl_checker/blob/main/ssl_checkerino_lambda.py) (including components that won't work until you have set up the surrounding AWS systems). I've got a lot of comments in the script that explain my thought processes here -- rather than repeat myself out of context, I'd recommend reviewing the comments there.

*Note that right now, the script won't do much except generate an error if you test it. You don't have an SNS topic yet!*

## 2. The API Gateway
The API Gateway is what gives you access into the Lambda function from outside. In this case, we are making it public -- you could make it private or secure it, but that's not part of this exercise. To create the API manually:

* Go to your AWS console and search for (and click) API Gateway, then click **Create API**.
* Under HTTP API, click **Build**.
* Under Integrations, click **Add integration**, then select **Lambda**. Select your lambda function from the list. Give it a name and click **Next**.
* Change the Method to **POST**, then add to the existing resource path **/post_ssl**. *In this case, I prefer to specify in case I add more API functionality later on.* Click **Next**.
* Leave the stage name as $default. No need to mess with that. Click **Next**, then click **Create**.

*When you create an API Gateway manually like this, note that it creates your permissions required automatically. You'll still need to know what permissions are needed for deploying this with IaC like a Terraform template. In the Terraform case below, I'm actually using a REST API instead of the basic HTTP one, but it's still accessible the same way.*

## 3. Test cases
No Lambda function is complete without a way to test it. Technically, you can just throw good and bad results at it to test from the API, but test cases allow you to do that from within the Lambda function. I've included two JSON files that provide the basics needed to test. badssl.com is a great resource as a website that lets you test good and bad responses for SSL stuff, so that is what I used for my test cases.

## 4. SNS Topic
I figure that if I am creating something like this, I want to know if it breaks -- or maybe even more importantly, I want to know if we've got a problem with an SSL cert on a domain we care about. An SNS topic allows you to take care of that notification. To create the SNS topic manually:

* Go to your AWS console and search for (and click) SNS, then select **Topics** on the left. Click **Create topic**.
* Select the type **Standard**. We're just going to email here, we don't need FIFO.
* Name your topic, then click **Create topic**. Copy the ARN of your topic, then paste it into your Lambda function on line 52 to replace **your_snsArn**.
* Now click **Subscriptions** on the left, then click **Create subscription**.
* Select your **Topic ARN** from the dropdown list. Change the protocol to **Email**, then add the desired email address as an **Endpoint**. Click **Create subscription**.
* Go to your email and confirm the email via link provided -- check spam folders, it might be there.
* After confirmation, you're good to go!

## 5. Terraform IaC Deployment
Terraform allows you to deploy all of the above in a short period of time. It also allows you to blow away that environment quickly, which is helpful in dev/sandbox situations where you are testing something out and want to undo everything you previously deployed.

To implement in Windows, some assumptions are made below first.

### Assumptions / Prerequisites

* You have Terraform installed. Instructions for doing so are located here: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
* You have the **PATH** environment variable for Terraform set up properly.
* You have Visual Studio Code already installed as well as the extensions for Terraform and Python (assuming you want to start doing any coding in Python -- since I've already provided you with a script, it is not strictly required here).
* You have the AWS CLI installed. Instructions are located here: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
* You have created an AWS IAM user that has appropriate permissions to do this build work.
  * When you create the AWS IAM user, make sure that the user is created with the AWS credential type "**Access key - Programmatic access**". In this case, I've set the user up as an administrator.
  * Make sure you copy down the **Access key ID** and **Secret access key** when this gets created. You won't get a second chance. (Though if you do forget to do this, you can just make another user and do it there.)
  * Also, make sure to copy down the **account ID** itself -- this will come in handy when building.

### Terraform Setup

* Download the **main.tf** file into whatever directory from which you plan to run your terraform commands.
* Download the ssl_checkerino_iac.zip file into that same directory.
* Open up your terminal of choice. In this case, I'm using the Windows command prompt.
* Set a session environment variable for both your AWS_ACCESS_KEY_ID and your AWS_SECRET_ACCESS_KEY, copied from above: `set AWS_ACCESS_KEY_ID=(your access key id)` followed by `set AWS_SECRET_ACCESS_KEY=(your secret access key)`.
* Change directories to the location you want to run terraform from -- remember, it's where you dropped that .tf and .zip file.
* Proceed with `terraform init` and press **enter**.
* Next, proceed with `terraform plan` and press **enter**. You will be asked to enter a value for v**ar.accountId**. Paste in the account ID you saved previously. You will next be prompted to enter a value for **var.email**. Input an email address that you'd like to set up to receive notifications.  
  ![image](https://user-images.githubusercontent.com/113604859/209582436-bde826e9-dfdf-4e25-935c-de233c4ea2c0.png)
It will provide you an output here automatically that you can use to copy/paste into the Python script later (seen above).
* Next, proceed with `terraform apply` and press **enter**. Repeat the same step above.
* Type `yes` and press enter. In my experience, this creation process takes about 20 seconds.
![image](https://user-images.githubusercontent.com/113604859/209582708-d250f251-d85e-47ff-b0d4-33a50d94363b.png)

### Final steps
Three final steps are needed here to go to work on your test case.

* Check your email. You should have a new AWS Notification that requires you to confirm the subscription.
![image](https://user-images.githubusercontent.com/113604859/209582829-c7316ac6-deba-4ca0-bdb1-de4fe7c4e928.png)

* Go to your lambda function in the AWS console (search for **Lambda** > select **ssl_checkerino_iac**), then adjust line 52 to include the **snsArn** output from above. Remember to click **Deploy**.
* Go to your lambda function in the AWS console (search for **Lambda** > select **ssl_checkerino_iac**), then create the two test cases. You can copy and paste directly from the JSONs I've provided.

### Ready to roll

Now you should be able to run your test cases, both good...

![image](https://user-images.githubusercontent.com/113604859/209583148-42dfcbb1-0937-4b2b-82fd-d83135565f93.png)


...and bad...

![image](https://user-images.githubusercontent.com/113604859/209583169-b63ed453-5225-452d-bc27-cb8e3c2d1f8f.png)

When you run the bad test case, you will receive an email momentarily:

![image](https://user-images.githubusercontent.com/113604859/209583250-03f6db6c-dc3d-4f77-bd36-3abb56b5d866.png)

To invoke from Postman:

![image](https://user-images.githubusercontent.com/113604859/209583372-74f2813d-8074-44db-9492-463c0a30bc15.png)

## Future improvements

While this impementation works, there's always room for improvement, and this case is no exception. I have several potential improvements I'd like to make:

* If the use case is to check known sites for SSL certificates, invoking manually takes more time than regularly scheduled automation. I'd recommend a daily or at least weekly check against a list of known sites that should be checked, removing that manual need.
* If the use case is to take action, we would probably want to be notified BEFORE expiration, but not every single day (and not every single request -- it's why I didn't notify email on positive results). To accomplish this, I'd suggest additional script logic that identifies a threshold...maybe < 14 days to expiration?
  * To take the above example further, it would be good to escalate the alerts as we get closer to 0 days.
* The code I provided doesn't go farther than looking at expiration alone as a data point. It would be nice to look at the other possibilities that include other cert problems, like mismatched cnames, untrusted CA, or even revoked certs.
  * The test cases I provided could be similarly expanded upon.
* Bigger picture, I think that a workflow to automatically renew with approval wouldn't be a bad idea to set up.
