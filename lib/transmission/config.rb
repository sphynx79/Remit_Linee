module Transmission
  class Config < Settings
   source File.join(__dir__,"../../config/config.yml")
   namespace ENV['APP_ENV']
  end
end






