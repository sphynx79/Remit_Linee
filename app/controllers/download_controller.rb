class DownloadController < Transmission::BaseController
    extend Memoist

    def start
      if file_to_download_exist?
        p "il file esiste"
      else
        p "il file non esiste: scarico"
        download_file
      end
      render

    end

    private 

  
    def file_to_download_exist?
      File.exist?(local_file) ? true : false
    end

    def download_file
      write_out = open(local_file, 'wb')
      write_out.write(remote_file.read)
      write_out.close
    end

    def local_file
      "#{download_path}/remit_#{data}.xlsx"
    end

    def data
      arr_str = λ{|a| "#{a[2]}_#{a[1]}_#{a[0]}" }
      page.
        ᐅ(~:xpath, '//*[@id="dnn_ctr5896_TernaViewDocumentView_grdDocument_ctl00__0"]/td[2]').
        ᐅ(~:text).
        ᐅ(~:gsub, "/", "_").
        ᐅ(~:split, "_").
        ᐅ(arr_str)
    end

    def page
      Nokogiri::HTML(open(site))
    end

    def remote_file
      open(url_file, 'User-Agent' => 'ruby')
    end

    def download_path
      File.expand_path(Transmission::Config.path.download, APP_ROOT)
    end

    def url_file
      page.
        ᐅ(~:xpath, '//*[@id="dnn_ctr5896_TernaViewDocumentView_grdDocument_ctl00__0"]/td[1]/a/@href').
        ᐅ(~:first).
        ᐅ(~:value)
    end

    def site
      Transmission::Config.url.site
    end

    memoize :page
    memoize :local_file
    memoize :data
end
