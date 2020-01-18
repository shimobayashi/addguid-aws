require 'json'
require 'feed-normalizer'
require 'open-uri'
require 'digest/md5'
require 'cgi'
# aws-sdkをrequireするとどういうことかよく分かってないけど本番Lambdaでタイムアウトまでスタックしてしまう
#require 'aws-sdk'
require 'aws-sdk-s3'
require 'aws-sdk-dynamodb'

def lambda_handler(event:, context:)
  dynamodb = Aws::DynamoDB::Client.new(
    region: 'ap-northeast-1',
  )

  s3 = Aws::S3::Resource.new(region:'ap-northeast-1')
  begin
    #TODO DynamoDBのテーブルもtemplate.yml の管理下にしたほうが良い気がする(できるのか知らんけど)
    result = dynamodb.scan({ table_name: 'addguid_target' })
    result.items.each do |target|
      puts target

      begin
        feed = FeedNormalizer::FeedNormalizer.parse open(target['uri'])
        feed.entries.each do |entry|
          # guidに相当する文字列を渡されたオプションからよしなに生成する。
          seed = ''
          if target['use_entry_url'] & entry.url
            seed += entry.url
          end
          if target['use_entry_title'] & entry.title
            seed += entry.title
          end
          if target['use_entry_content'] & entry.content
            seed += entry.content
          end
          if target['use_entry_date_published'] & entry.date_published
            seed += entry.date_published.to_s
          end
          if target['use_entry_id'] & entry.id
            seed += entry.id
          end

          # entry.idを存否の確認をせずに上書きする。
          entry.id = Digest::MD5.hexdigest(seed)
        end

        key = "production/#{target['uri'].gsub('/', '-')}.xml"
        link = "https://addguid-aws.s3.ap-northeast-1.amazonaws.com/#{CGI.escape(key)}"

        rss = RSS::Maker.make('2.0') do |rss|
          rss.channel.title = feed.title
          rss.channel.description = feed.description
          rss.channel.link = link

          feed.entries.each do |entry|
            item = rss.items.new_item
            item.title = entry.title
            item.link = entry.url
            item.guid.content = entry.id
            item.guid.isPermaLink = false
            item.description = entry.content
            item.date = entry.date_published
          end
        end

        obj = s3.bucket('addguid-aws').object(key)
        obj.put(
          acl: 'public-read',
          body: rss.to_s,
          content_type: 'application/rss+xml;charset=UTF-8',
        )
      rescue => error
        puts error
      end
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
