require 'json'
require 'aws-sdk'
require 'feed-normalizer'
require 'open-uri'
require 'digest/md5'

def lambda_handler(event:, context:)
  dynamodb = Aws::DynamoDB::Client.new(
    region: 'ap-northeast-1',
  )

  begin
    result = dynamodb.scan({ table_name: 'addguid_target' })
    result.items.each do |target|
      p target

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

      rss = RSS::Maker.make('2.0') do |rss|
        rss.channel.title = feed.title
        rss.channel.description = feed.description
        rss.channel.link = "#{to('/')}?#{request.query_string}"

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

      p rss
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
