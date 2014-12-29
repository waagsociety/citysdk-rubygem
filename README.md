# CitySDK GEM

The CitySDK gem encapulates the CitySDK LD API, and offers high-level file import functionalities.
The CitySDK LD API is part of an open data distribution platform developed in the EU CitySDK program by [Waag Society](http://waag.org).
Find the platform itself on [GitHub](https://github.com/waagsociety/citysdk-ld), background is [here](http://dev.citysdk.waag.org).

In order to best get an overview of the way to use the gem to import files into the CitySDK LD API, have a look at the [`admr` importer]((https://github.com/waagsociety/citysdk-amsterdam/tree/master/importers/admr)) for the top-level administrative regions in the Netherlands. The data consists of three ESRI Shapefiles; the importer is well-commented, explaining most of the possibilities of the gem.

## Installation

To install it just install the gem:

    gem install citysdk

If you're using Bundler, add the gem to Gemfile.

    gem 'citysdk'

Then, run `bundle install`.

## Usage

The gem can be used on two different levels, either simply as a wrapper around the API, or as a means to read, convert and import various types of data files. The gem exposes its functionality through three different objects:

- CitySDK::API
- CitySDK::FileReader
- CitySDK::Importer

The FileReader can be used stand-alone to read, edit and save data files, the Importer builds on the FileReader and API objects.

The FileReader has support for CSV, Shape and (Geo)Json files. XML is currently not supported; we recommend [OpenRefine](https://github.com/OpenRefine/OpenRefine/wiki/Downloads) to convert these to either CSV or JSON.

### CitySDK::API Usage

Call                                   | Description
|:-------------------------------------|:-------------------------------------------------------
`@api = CitySDK::API.new('<endpoint IP>')` | Establish a link to the particular endpoint
`@api.authenticate('<name>','<password>')` | For reading this is not necessary, for writing and deleting you need to authenticate. The authentication times out if not used (is reset by writing to the API). This call takes an optional  block for immediate automatic release when the block has been called.
`@api.get path` | Simply issue a 'GET' against the API; the results are returned as a ruby Hash.
`@api.put path,data` | PUT a resource; see [Documentation](https://github.com/waagsociety/citysdk-ld/wiki/Objects)
`@api.post path,data` | POST a resource; see [Documentation](https://github.com/waagsociety/citysdk-ld/wiki/Objects)
`@api.patch path,data` | PATCH a resource; see [Documentation](https://github.com/waagsociety/citysdk-ld/wiki/Objects)
`@api.delete path` | Issue a DELETE to the API; path points to the resource to delete. Requires authentication.
`@api.release` | This call will flush any buffered object that were scheduled to be created or updated. See also batch_size, below.
`@api.set_layer(layername)` | Set the the layer for subsequent 'create_object' calls. User must be authenticate for this layer in order to sucesfully create objects.
`@api.create_object(objhash)` | Adds an object to the database. See also batch_size, below.
`@api.layers` | Shortcut for `get '/layers'`
`@api.owners` | Shortcut for `get '/owners'`
`@api.objects(layer=nil)` | Shortcut for `get '/objects'`. When a layer name is supplied, returns only objects from with data on this layer, and the layerdata itself.
`@api.next` | When more results are available, returns the next page.
`@api.format = <format>` | Specify the output format. Currently supported are (Geo)JSON and (Geo)JSON-LD.
`@api.per_page = <per_page>` | Specify the number of features returned; default is 10.
`@api.batch_size = <n>` | When adding objects thorugh 'create_object', they are buffered until '<n>' objects are available, then a single call is issuesd to the API.
`@api.last_result` | Returns a Hash with the last HTTP status and the headers returned from the last call.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request