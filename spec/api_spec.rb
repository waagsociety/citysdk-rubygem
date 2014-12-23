

module CitySDK
  TEST_HOST = 'localhost:9292'
  # TEST_HOST = 'test-api.citysdk.waag.org'
  TEST_USER = 'test'
  TEST_PASS = '123Test321'

  # name=test.rspec title='test layer' owner=citysdk description='for testing' rdf_type=csdk\:Test category=security

  TEST_LAYER = {
    name: "test.rspec",
    title: "test layer",
    owner: TEST_USER,
    description: "for testing",
    data_sources: [""],
    rdf_type: "csdk:Test",
    category: "security",
    subcategory: "test",
    licence: "CC0",
    fields: []
  }
  
  $api = API.new(TEST_HOST)

  
  
  describe API do


    it "can be connected to" do
      expect($api.class).to be(CitySDK::API)
    end

    it "can be queried" do
      expect($api.get('/layers').class).to be(Hash)
    end

    it "can be authorized against" do
      expect($api.authenticate(TEST_USER,TEST_PASS)).to be(true)
      expect($api.release.class).to be(Array)
    end

    it "can create and delete a test layer" do
      expect($api.authenticate(TEST_USER,TEST_PASS)).to be(true)
      expect($api.post('/layers',TEST_LAYER)[:features].class).to be(Array)
      expect($api.delete('/layers/test.rspec')).to eq({})
      expect($api.release.class).to be(Array)
    end

    it "can not create a layer in an unauthorized domain" do
      h = TEST_LAYER.dup
      h[:name] = 'unauthorized.rsped'
      expect($api.authenticate(TEST_USER,TEST_PASS)).to be(true)
      expect { $api.post('/layers',h) }.to raise_error(HostException,"Owner has no access to domain 'unauthorized'")
      h[:name] = "test.rspec"
      $api.release
    end

    it "can not add data to a layer not owned" do
      res = $api.get('/objects?per_page=1')
      expect(res[:type]).to eq('FeatureCollection')
      cdk = res[:features][0][:properties][:cdk_id]
      expect($api.authenticate(TEST_USER,TEST_PASS)).to be(true)
      expect { $api.patch("/objects/#{cdk}/layers/osm",{:plop => 'pipo'}) }.to raise_error(HostException,"Operation requires owners' authorization")
      $api.release
    end

  end
  
end