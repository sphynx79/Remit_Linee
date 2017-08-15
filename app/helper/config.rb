class Config

  class << self

    def read_config(controparte)
      y = YAML.load_file config_path
      s = OpenStruct.new
      c = y[controparte]
      c.each do |k, v|
        k = k.to_s if !k.respond_to?(:to_sym) && k.respond_to?(:to_s)
        s.send("#{k}=".to_sym, v)
      end
      return s
    end

    private

    def config_path
      File.join(__dir__,"../../config/config.yml")
    end

  end

end
