import json, boto3, os, logging, urllib.request

#Initialize the DynamoDB Client
dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ.get('TABLE_NAME', 'EmployeesTable')
table = dynamodb.Table(TABLE_NAME)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_slack_token():
    """ Retrieves the Slack Bot Token from AWS Secrets Manager"""
    secret_name = os.environ.get('SLACK_SECRET_NAME', 'slack/token')
    client = boto3.client('secretsmanager')
    try:
        response = client.get_secret_value(SecretId=secret_name)
        token_data = json.loads(response['SecretString'])
        slack_token = token_data['token']

        # This will output our slack token in our Cloudwatch Log Stream just to verify we got the secret.
        logger.info(f"DEBUG: Retrieved Slack Token: {slack_token}")

        return slack_token

    except Exception as e: 
        logger.error(f"Error retrieving secret: {str(e)}")
        return None
        
def handler(event, context):
    slack_token = get_slack_token()
    if not slack_token:
        return {"status": "error", "message": "Could not retrieve Slack token"}
    """
    Processes DynamoDB stream events and returns a creation message
    without calling the external Slack API.
    """
    logger.info(f"Received event: {json.dumps(event)}")
    results = []
    try:
        for record in event['Records']:
            # Only process new hires added to the table
            if record['eventName'] == 'INSERT':
                new_user = record['dynamodb']['NewImage']
                
                # Extract data from the stream event 
                user_id = new_user.get('UserId', {}).get('S')
                company_email = new_user.get('CompanyEmail', {}).get('S')
                personal_email = new_user.get('PersonalEmail', {}).get('S', 'Unknown')
                first_name = new_user.get('FirstName', {}).get('S', 'Employee')
                last_name = new_user.get('LastName', {}).get('S', '')

                if not user_id:
                    logger.warning("No User ID was found, skipping update.")
                    continue     

                # --- Slack API Integration Call Placeholder ---
                # For standard workspaces users.admin.invite is legacy/undocumented
                # For Enterprise Grid, use admin.users.invite. 

                # We are only mocking that the Slack API was successful
                slack_success = True

                if slack_success: 
                    table.update_item(
                        Key={'UserId': user_id},
                        UpdateExpression="SET SlackStatus = :status",
                        ExpressionAttributeValues={
                            ':status': 'Invite created'
                        }
                    )
                    logger.info(f"PROVISIONING SUCCESS: Slack invite sent to {company_email}")
                
                results.append({
                    "email_used": company_email,
                    "status": "SUCCESS",
                })
    
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }
    except Exception as e: 
        logger.error(f"Error processing stream: {str(e)}")
        raise e