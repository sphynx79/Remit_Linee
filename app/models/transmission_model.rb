#https://jeffkreeftmeijer.com/2011/method-chaining-and-lazy-evaluation-in-ruby/

HOUR_STEP   = (1.to_f/24)

class TransmissionModel < Transmission::BaseModel

  def collection(collection: "transmission")
    client[collection]
  end

  def all_document_from(collection: "transmission")
    (client[collection]).
      ᐅ(~:find, {}).
      ᐅ(~:projection, '_id' => 1, 'properties.nome' => 1).
      ᐅ(~:to_a)
  end

 
  # def all_document_from(collection: "transmission")
  #   (client[collection])
  #     .find({})
  #     .projection('_id' => 1, 'properties.nome' => 1)
  #     .to_a
  # end

end
