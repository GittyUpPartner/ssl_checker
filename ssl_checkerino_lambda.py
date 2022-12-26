import json
import ssl
import socket
import datetime
import boto3

# create the function -- also make sure to rename the runtime handler for Lambda to match the below
def ssl_checkerino(event, context):
    # define the host event -- this can be determined by running postman against a simple "print(event), then looking over cloudwatch logs to see the results"
    host = event['queryStringParameters']['host']
    # requirement -- we need a domain_name output
    domain_name = host
    # per documentation for the ssl module, best to define the context this way rather than with the older method
    context = ssl.create_default_context()
    connection = context.wrap_socket(socket.socket(socket.AF_INET), server_hostname=domain_name)
    # set a reasonable timeout
    connection.settimeout(3.0)
    try:
        # always connect to the host provided via 443 -- we are tracking SSL after all
        connection.connect((host, 443))
        # set a variable to pull the certificate information in general
        ssl_info = connection.getpeercert()
        # set a variable that gets the exact expiration date
        expiration_date = ssl_info['notAfter']
        # set a variable that in turn converts the expiration date into something that can be interpreted better by python (for comparison)
        expiration_timestamp = datetime.datetime.strptime(expiration_date, '%b %d %H:%M:%S %Y %Z')
        # grab the current timestamp for comparison below
        current_timestamp = datetime.datetime.now()
        # requirement -- determine how many days til expiration
        days_until_expiration = (expiration_timestamp - current_timestamp).days
        # this is the main check -- the current timestamp would have to be earlier than the expiration of the SSL cert, otherwise we'd get an SSL error.
        if current_timestamp < expiration_timestamp:
            # requirement -- identify validity, though this is just based off of the above check.
            is_valid = "valid"
            # return values properly from JSON, providing domain_name, whether it's valid, and days until expiration, all wrapped around decent text
            return {
                'statusCode': 200,
                'headers': { 'Content-Type': 'application/json' },
                'body': json.dumps({'message': f'SSL certificate for {domain_name} is {is_valid}. There are {days_until_expiration} days until expiration.'})
            }

    # exceptions are bound to happen, and must be accounted for
    except Exception as error:
        # if we get an SSLCertVerificationError (in other words, the cert is not valid or expired), we need to report that back to the requesting user.
        if ssl.SSLCertVerificationError:
            # requirement -- since this is outside of the try context, we are determining that the cert is not valid due to meeting the check above
            is_valid = "not valid"
            # requirement -- since this is outside of the try context, we need to specify that domain_name refers to the host
            domain_name = host
            # the below concerns SNS info -- sending a failure message for bad stuff
            client = boto3.client('sns')
            snsArn = 'your_snsArn'
            message = "Error checking SSL certificate."
            response = client.publish(
                TopicArn = snsArn,
                Message = message ,
                Subject = "SSL cert verfication error: " + str(event['queryStringParameters']['host'])
                )
            # don't just tell the requestor that it is expired. Give them the error.
            return {
                'statusCode': 500,
                'headers': { 'Content-Type': 'application/json' },
                'body': json.dumps({'message': f'Error checking SSL certificate for {domain_name} as it was expired. Cert validity: {is_valid}. {error}'})
            }
        else:
            # just in case something else weird happened, we want to trap for that as well, and tell the requestor what the error was.
            client = boto3.client('sns')
            snsArn = 'your_snsArn'
            message = "Some uncaught exception occurred with the SSL checker."
            response = client.publish(
                TopicArn = snsArn,
                Message = message ,
                Subject = 'SSL checker - uncaught exception for ' + str(event['queryStringParameters']['host'])
                )
            return {
                'statusCode': 500,
                'headers': { 'Content-Type': 'application/json' },
                'body': json.dumps({'message': f'Some other uncaught exception was found: {error}'})
            }
