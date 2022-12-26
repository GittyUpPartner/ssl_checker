# ssl_checker

This repository contains code that is intended to check individual domains for SSL certificate expiration. This is intended to work with several AWS components: Lambda, an API gateway, and an SNS topic. I'll explain each step of the way and provide screenshots where applicable. This does include IaC components intended to be deployed with Terraform.

## What are we trying to do?

We want to...
1. Create a python script in AWS Lambda that checks domains for SSL cert expiration. This script needs to be able to accept **"host"** as an input. It also needs to provide JSON output. There's a few other requirements we have as well but they are in script comments.
2. Create an API Gateway. This can be super simple -- just allow HTTP POST only. This needs to connect to the above Lambda function.
3. Create test cases for the Lambda function.
4. Connect the Lambda function to an SNS topic so that you can get emails on alerting.
5. Deploy all of the above with Terraform.

## 1. The Python Script
Let's start with the python script. I've linked the [final, full version here](https://github.com/GittyUpPartner/ssl_checker/blob/main/ssl_checkerino_lambda.py) (including components that won't work until you have set up the surrounding AWS systems). Fair warning: I'm **not** a Python scripting guru -- I know PowerShell syntax a lot better! The concepts are similar, but I've had to do some digging into syntax and some trial and error to get this to work. You may find that you have a better, faster, or simpler way to do all of these things. I've got a lot of comments in the script that explain my thought processes here.

*Note that right now, the script won't do much except generate an error if you test it. You don't have an SNS topic yet!*

## 2. The API Gateway
The API Gateway is what gives you access into the Lambda function from outside. In this case, we are making it public -- you could make it private or secure it, but that's not part of this exercise. To create the API manually:

* Go to your AWS console and search for (and click) API Gateway, then click **Create API**.
* Under HTTP API, click **Build**.
* Under Integrations, click **Add integration**, then select **Lambda**. Select your lambda function from the list. Give it a name and click **Next**.
* Change the Method to **POST**, then add to the existing resource path **/post_ssl**. *In this case, I prefer to specify in case I add more API functionality later on.* Click **Next**.
* Leave the stage name as $default. No need to mess with that. Click **Next**, then click **Create**.

*When you create an API Gateway manually like this, note that it creates your permissions required automatically. You'll still need to know what permissions are needed for deploying this with IaC like a Terraform template.*

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
