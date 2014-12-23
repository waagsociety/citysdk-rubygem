#!/usr/bin/env ruby

# check the wiki for detailed api usage: https://github.com/waagsociety/citysdk-ld/wiki

require 'citysdk'
include CitySDK

api = API.new('api.citysdk.waag.org') # point to a hosted instance of the api.

# simple GET
# GET requests do not need authentication

endpoint = api.get '/'
puts "Enpoint is: #{endpoint[:features][0][:properties][:title]}."

first10layers = api.get('/layers')
puts "First layer: #{JSON.pretty_generate(first10layers[:features][0])}"

# find out how many owners the endpoint knows
owners = api.get('/owners?per_page=1&count')
puts "Number of data maintaners: #{api.last_result[:headers]['x-result-count']}"

# authenticate for write actions.
unless api.authenticate('<name>','<passw>')
  puts "Did not authenticate..."
  exit 
end
  
# make a layer
# everybody can wite to the temporary 'test' domain: 

layer = {
  name: "test.cities",
  owner: "citysdk",
  title: "Cities: 🏠🏢🏣🏨🏫🏬🏭🏡",
  description: "Cities big and small.",
  data_sources: [ "http://fantasy.com" ],
  authoritative: false,
  rdf_type: "dbp:City",
  category: "administrative",
  subcategory: "cities",
  licence: "CC0"
}

api.post('/layers',layer)

  # add data to this layer
  # attach to the node representing the city of Rotterdam
object = {type: "Feature", 
          geometry: {
            type: 'Point',
            coordinates: [4.4646,51.9222] }, 
            properties: {
              id: 'Rotterdam', 
              title: 'Rotterdam', 
              data: {
                a: 1, 
                b: 2
              }
            }
         }
  
api.post('/layers/test.cities/objects', object)


# don't forget to release! this will also send 'unfilled' batches to the backend.
api.release

