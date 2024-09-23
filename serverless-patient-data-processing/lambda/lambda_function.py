# lambda/lambda_function.py
import json
import boto3

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('processed_data')

def lambda_handler(event, context):
    try:
        # Process the incoming event
        if 'Records' in event:
            # Example: Process S3 event
            bucket = event['Records'][0]['s3']['bucket']['name']
            key = event['Records'][0]['s3']['object']['key']
            
        else:
            # Assume the event comes from API Gateway and contains bucket and key directly
            event_data = json.loads(event['body'])
            bucket = event_data.get('bucket')
            key = event_data.get('key')

            if not bucket or not key:
                raise ValueError("Bucket and key are required in the body") 
        
        response = s3.get_object(Bucket=bucket, Key=key)
        data = response['Body'].read().decode('utf-8')
        # Parse the JSON file
        patients = json.loads(data)
        
        # Iterate over each patient and put into DynamoDB
        for patient_data in patients['patients']:
            #Store data in DynamoDB
            table.put_item(Item={'id': patient_data['patient_id'], 'data': patient_data})
            
        return {
            'statusCode': 200,
            'body': json.dumps('Data processed successfully!')
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error processing data: {str(e)}")
        }

