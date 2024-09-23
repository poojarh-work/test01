# test_lambda.py
import lambda_function

# Create a test event that simulates an S3 put event
test_event = {
    'Records': [
        {
            's3': {
                'bucket': {
                    'name': 'patient-data20240922194536335400000001'
                },
                'object': {
                    'key': 'test-file.json'
                }
            }
        }
    ]
}

# Invoke the handler
response = lambda_function.lambda_handler(test_event, None)
print(response)
