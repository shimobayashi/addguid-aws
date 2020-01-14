# FeedlyからエクスポートしたOPMLをDynamoDBのaddguid_targetテーブルに突っ込むスクリプト
# OLD_HOST=example.com ruby tools/opml2target.rb path-to-opml.opml

require 'uri'
require 'cgi'
require 'aws-sdk'

dynamodb = Aws::DynamoDB::Client.new(
  region: 'ap-northeast-1',
)
File.foreach(ARGV[0]) do |line|
  line =~ /xmlUrl="(.+?)"/

  next unless $1

  uri = URI.parse(URI.encode($1))

  next unless uri.host == ENV['OLD_HOST'] && uri.path == '/addguid/feed'

  params = Hash[
    URI.decode_www_form(
      CGI.unescape_html(uri.query) # XMLの実体参照を置換する
    ).map { |e| e.map { |e| e.gsub('amp;', '') } } # 実体参照を置換してもパラメーターにamp;というゴミが入り込んでいるので削除する。経緯は忘れた
  ]

  item = {}
  item['uri'] = CGI.unescape(params['url'])
  item['use_entry_url'] = params['link'] == 'on'
  item['use_entry_title'] = params['title'] == 'on'
  item['use_entry_content'] = params['descriptikon'] == 'on'
  item['use_entry_date_published'] = params['date'] == 'on'
  item['use_entry_id'] = params['guid'] == 'on'

  dynamodb.put_item({
    table_name: 'addguid_target',
    item: item,
  })
end
