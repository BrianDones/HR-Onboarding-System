import json, boto3, os, logging, random, string
from datetime import datetime
from boto3.dynamodb.conditions import Key

dynamodb   = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME', 'EmployeesTable')
table      = dynamodb.Table(TABLE_NAME)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

COMPANY_DOMAIN = "redhatchilipeppers.org"

def generate_user_id(length=10):
    """Generates a random string of fixed length using letters and digits"""
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Parse the incoming JSON body
        body = json.loads(event.get('body', '{}'))

        # Extract the HR Staff's identity from the Cognito claims
        authorizer_context = event.get('requestContext', {}).get('authorizer', {})
        claims = authorizer_context.get('claims', {})

        first_name_staff = claims.get('given_name', 'Unknown')
        last_name_staff  = claims.get('family_name', 'User')

        created_by = f"{first_name_staff} {last_name_staff}".strip()

        # Validate required fields
        first_name     = body.get('firstName')
        last_name      = body.get('lastName')
        personal_email = body.get('personalEmail')

        if not all([first_name, last_name, personal_email]):
            return {
                'statusCode': 400, 
                'body': json.dumps({'error': 'Missing required fields: firstName, lastName, personalEmail'})
            }

        # Generate a unique 10-character ID
        user_id = generate_user_id(10)

        # Create the timestamp of when the user was added in "YYYY-MM-DD hh:mm:ss" format
        created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Prepare the user entry for DynamoDB
        employee = {
            'UserId': user_id,
            'FirstName': first_name,
            'LastName': last_name,
            'PersonalEmail': personal_email,
            'SlackStatus': 'PENDING', # This is the initial state for all provisioned users until the slack integration triggers the slack invite
            'CreatedAt': created_at,
            'CreatedBy': created_by
        }   
    
        # Write the employee entry to the DynamoDB table
        table.put_item(Item=employee)

        logger.info(f"Successfully create employee: {first_name} {last_name} | User ID: {user_id}")
    
        return {
            'statusCode': 201, 
            'headers': {
                "Content-Type": "application/json", 
                "Access-Control-Allow-Origin": "*"
            },
            'body': json.dumps({
                "message": f"Employee {first_name} {last_name} was created successfully",
                "personalEmail": personal_email,
                "userId": user_id
                })
        }

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'})
        }