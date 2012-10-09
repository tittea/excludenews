$KCODE = 'UTF8'

require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'kconv'
require 'json'

require 'aws/s3'

include AWS::S3


def uploadtoS3(filename)
  Base.establish_connection!(
                             :access_key_id => ENV['AWS_ID'],
                             :secret_access_key => ENV['AWS_KEY'])
  p filename
  File.open(filename,'rb') do |f|
    S3Object.store('/exnews/'+File::basename(filename),f,'exnews',:access=>:public_read)
  end
end


def get_news_list(category)
  doc = Nokogiri::HTML(open("http://news.google.com/news?hl=ja&ned=jp&ie=UTF-8&oe=UTF-8&topic="+category, 'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/13.0.782.112 Safari/535.1'))
  datalist = []

  #news article list
  links = doc.search("//div[@class='moreLinks']/a")

  #each article
  n = 0
  links.each{|l|
    data = 
    {:category => category, 
      :newstitle => [],
      :related_list_link => [],
      :abbrev => "",
      :media => [],
      :medianame => [],
      :mediaurl => []
    }

    p '#'*40
    p "article"
    article_list_url = 'http://news.google.com'+l[:href]
    p article_list_url

    #get all related articles
    tmp = Nokogiri::HTML(open(article_list_url))
    related_list_link = tmp.search("//div[@class='filter-link']/a")
    

    p "all related list link"
    data[:related_list_link] = related_list_link[0][:href]
    p data[:related_list_link]

    related_article_url = 'http://news.google.com'+related_list_link[0][:href]

    p "related article url: "+ related_article_url
    related_article_doc = Nokogiri::HTML(open(related_article_url))
    #check pagenation
    p "pagenation"
    pageurl = related_article_doc.search("//div[@id='pagination']//td/a").map {|l| 
      l[:href][0..-1] #last one is 'next'
    }

    #pagenation urls
    p pageurl
    pagenation_article_doc = pageurl.map{|url|
      Nokogiri::HTML(open('http://news.google.com'+url))
    }
    
    pagenation_article_doc << related_article_doc
    
    pagenation_article_doc.each{|doc|
      #extract news source
      p "extract news source"
      newstitle = doc.search("//h2[@class='title']")[0].text
      p newstitle
      data[:newstitle] = newstitle

      data[:abbrev] = doc.search("//div[@class='snippet']")[0].text
      p "news snippet"
      p data[:abbrev]
      
      p "media"
      medianame = ''
      doc.search("//div[@class='sub-title']/span[position()<2]").each{|s|
        medianame = s.text
        data[:medianame] << s.text
      }

      mediaurl = ''
      doc.search("//h2[@class='title']/a").each{|s|
        mediaurl = s[:href]
        data[:mediaurl] << mediaurl
      }
      #data[:media] << {:name => medianame, :url => mediaurl}

      datalist << data
    }

  }
  open('/tmp/'+category+'_news_list.txt','w'){|f|
    f.puts JSON.pretty_generate(datalist.uniq)
  }
end


def get_all_news_category(cat)

  categories = {}
  categories[:social] = 'y'
  categories[:world] = 'w'
  categories[:business] = 'b'
  categories[:politics] = 'p'
  categories[:entertainment] = 'e'
  categories[:sports] = 's'
  categories[:tech] = 't'


  get_news_list(cat)
  latest_fname = '/tmp/'+cat+'_news_list.txt'
  uploadtoS3(latest_fname) #latest
  fname = '/tmp/'+cat+'_news_list'+Time.now.strftime("%Y-%m-%d-%H%M%S")+'.txt'

  FileUtils.cp(latest_fname,fname)
  uploadtoS3(fname) #latest

end

