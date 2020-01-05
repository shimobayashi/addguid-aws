require 'json'
require 'aws-sdk'

def lambda_handler(event:, context:)
  dynamodb = Aws::DynamoDB::Client.new(
    region: 'ap-northeast-1',
  )

  begin
    result = dynamodb.scan({ table_name: 'addguid_target' })
    result.items.each do |target|
      p target
    end

  rescue  Aws::DynamoDB::Errors::ServiceError => error
    puts "Unable to read item:"
    puts "#{error.message}"
  end

  {
    statusCode: 200,
    body: {
      message: "Hello World!",
    }.to_json
  }
end
