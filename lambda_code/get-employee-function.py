import json, boto3, os, logging

# Initialize DynamoDB
dynamodb   = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME')
table      = dynamodb.Table(TABLE_NAME)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
	try:
		# We will pass in the User ID from the path parameter
		# E.g. /staging/employees/EvQbtwu7o8
		path_params = event.get('pathParameters')
		user_id     = path_params.get('UserId') if path_params else None

		if not user_id:
			return {
				'statusCode': 400, 
				'body': json.dumps(
					{
						"Error": "Missing User ID in request path"
					}
				)
			}

		if user_id: 
			# Use get_item for a direct lookup by the User ID Partition Key
			response = table.get_item (Key={'UserId': user_id})
			item     = response.get('Item')

			if not item: 
				return {
					'statusCode': 404,
					'body': json.dumps(
						{
							"message": f"Employee with ID {user_id} not found"
						}
					)
				}

			first_name = item.get('FirstName', 'Unknown')
			last_name  = item.get('LastName', 'User')

			logger.info(f"Successfully retrieved information for {first_name} {last_name}")
			return {
				'statusCode': 200, 
				'headers': {
					"Content-Type": "application/json",
					"Access-Control-Allow-Origin": "*"
				},
				'body': json.dumps(item)
			}

		else:
			response = table.scan()
			items    = response.get('Items', [])

			return {
				'statusCode': 200, 
				'headers': {
					"Content-Type": "application/json",
					"Access-Control-Allow-Origin": "*" 
				},
				'body': json.dumps(items)
			}
	except Exception as e:
		logger.error(f"Error retrieving employee: {str(e)}")
		return {
			'statusCode': 500, 
			'body': json.dumps(
				{
					"error": "Internal server error"
				}
			)
		}