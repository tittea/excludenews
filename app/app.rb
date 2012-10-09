# -*- coding: utf-8 -*-
require 'haml'
require 'json'
require 'yajl'
require 'aws/s3'
load './get_googlenews_list.rb'

include AWS::S3

class Exnews < Padrino::Application
  register Padrino::Rendering
  register Padrino::Mailer
  register Padrino::Helpers

  enable :sessions

  ##
  # Caching support
  #
  register Padrino::Cache
  #enable :caching

  get '/styles.css' do
    content_type 'text/css', :charset => 'utf-8'
    scss :styles
  end

  get '/btstyle.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :btstyle
  end

  def load_s3_file(fname)
    Base.establish_connection!(
                             :access_key_id => ENV['AWS_ID'],
                             :secret_access_key => ENV['AWS_KEY'],
                             :server => "exnews.s3.amazonaws.com")
    open('/tmp/'+fname,'w') do |file|
      S3Object.stream('exnews/'+fname,'exnews') do |chunk|
        file.write chunk
      end
    end
  end

  def get_category_news(cat)
    fname = cat+'_news_list.txt'

    #get from s3
    load_s3_file(fname)

    json = File.new('/tmp/'+fname,'r')
    parser = Yajl::Parser.new
    allarticles = parser.parse(json)
    @articles = []
    medialist = []

    #exclude asahi
    allarticles.each{|a|
      if a["medianame"].grep(/朝日新/) != []
        
      else
        @articles << a
      end
    }

    #search topnews
    @toparticle = @articles[0]
    @articles = @articles[1..-1]
    
    #p @articles[0]["newstitle"]
    haml :index    
  end

  categories = {}
  categories[:social] = 'y'
  categories[:world] = 'w'
  categories[:business] = 'b'
  categories[:politics] = 'p'
  categories[:entertainment] = 'e'
  categories[:sports] = 's'
  categories[:tech] = 't'

  get '/' do
    @category = "社会"
    get_category_news('y')
  end

  get '/w' do
    @category = "世界"
    get_category_news('w')
  end

  get '/b' do
    @category = "ビジネス"
    get_category_news('b')
  end

  get '/p' do
    @category = "政治"
    get_category_news('p')
  end

  get '/e' do
    @category = "エンターテイメント"
    get_category_news('e')
  end

  get '/s' do
    @category = "スポーツ"
    get_category_news('s')
  end

  get '/t' do
    @category = "技術"
    get_category_news('t')
  end

end
