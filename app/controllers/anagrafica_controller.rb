class AnagraficaController < Transmission::BaseController
  extend Memoist

  def start
    tmp_array = []
    linee_dataset_mapbox.each do |feature|
        tmp_hash = {
        id: feature[:id],
        p1: feature[:properties][:p1],
        p2: feature[:properties][:p2],
        id_terna: feature[:properties][:id_terna],
        nome: feature[:properties][:nome],
        nome_terna: feature[:properties][:nome_terna].map{ |i|  %Q('#{i}') }.join(','),
        voltage: feature[:properties][:voltage],
        lunghezza: feature[:properties][:lunghezza],
        country_to: feature[:properties][:country_to],
        country_fr: feature[:properties][:country_fr],
        zona1: feature[:properties][:zona1],
        zona2: feature[:properties][:zona2],
        interzonal: feature[:properties][:interzonal],
        underconst: feature[:properties][:underconst],
        dc: feature[:properties][:dc],
        geometry: 'LineString',
        coordinates: feature[:geometry][:coordinates].map{ |i|  %Q('#{i}') }.join(','),
      }
      tmp_array << tmp_hash
    end
    CSV.open("#{Transmission::Config.path.anagrafica}/Anagrafica_Linee_#{@voltage}.csv", "w", write_headers: true, headers: tmp_array.first.keys, col_sep: ';') do |csv|
      tmp_array.each do |h|
        csv << h.values
      end
    end

  end

  private

  def volt
    @env[:command_options][:volt]
  end

  def dataset_id
    volt == '380' ? 'cjcb6ahdv0daq2xnwfxp96z9t' : 'cjcfb90n41pub2xp6liaz7quj'
  end

  def linee_dataset_mapbox
    geojson = open(url, {ssl_verify_mode: 0}).read
    Oj.load(geojson, :symbol_keys => true, :mode => :compat)[:features]
  end

  def url
    "https://api.mapbox.com/datasets/v1/browserino/#{dataset_id}/features?access_token=sk.eyJ1IjoiYnJvd3NlcmlubyIsImEiOiJjamEzdjBxOGM5Nm85MzNxdG9mOTdnaDQ0In0.tMMxfE2W6-WCYIRzBmCVKg"
  end

  memoize :volt
  memoize :dataset_id
  memoize :linee_dataset_mapbox

end

