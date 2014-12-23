

module CitySDK

  describe "Importer" do

    def newImporter(f)
      @importer = Importer.new({
        file_path: f,
        host: TEST_HOST, 
        layername: TEST_LAYER[:name]
      })
    end

    it "checks parameters" do
      expect { Importer.new({:a=>1}) }.to raise_error(CitySDK::Exception)
    end

    it "succesfully creates a FileReader" do
      newImporter('./spec/files/wkb.csv')
      expect(@importer.class).to be(CitySDK::Importer)
      expect(@importer.filereader.params[:unique_id]).to be(:gid)
    end

    it "needs authorization to import" do
      newImporter('./spec/files/hotels.csv')
      expect { @importer.doImport }.to raise_error(CitySDK::Exception)
    end

    it "can make a layer and delete" do

      newImporter('./spec/files/hotels.csv')
      
      @importer.setParameter(:name,TEST_USER)
      @importer.setParameter(:password,TEST_PASS)
      @importer.sign_in
      res = @importer.api.post('/layers',TEST_LAYER)
      expect( (!!res[:features] and res[:features].length == 1) ).to be(true)
      @importer.sign_out

      expect { @importer.doImport }.to raise_error(CitySDK::Exception)

      res = @importer.api.get("/layers/test.rspec/objects")
      expect( (!!res[:features] and res[:features].length == 0) ).to be(true)

      @importer.api.authenticate(TEST_USER,TEST_PASS) do 
        expect( @importer.api.delete("/layers/#{TEST_LAYER[:name]}") ).to eq({})
      end

    end

  end
  
  describe "FileReader" do

    it "can parse json" do
      j = CitySDK::parseJson('{ "arr" : [0,1,1,1], "hash": {"aap": "noot"}, "num": 0 }')
      expect(j[:arr].length).to be(4)
      expect(j[:num].class).to be(Fixnum)
      expect(j[:hash][:aap]).to eq("noot")
    end

    it "can read json files" do
      fr = FileReader.new({:file_path => './spec/files/stations.json'})
      expect(File.basename(fr.file)).to eq('stations.json')
      expect(fr.params[:geomtry_type]).to eq('Point')
      expect(fr.params[:srid]).to be(4326)
      expect(fr.params[:unique_id]).to be(:code)
    end

    it "can read geojson files" do
      fr = FileReader.new({:file_path => './spec/files/geojsonTest.GeoJSON'})
      expect(File.basename(fr.file)).to eq('geojsonTest.GeoJSON')
      expect(fr.params[:unique_id]).to be(:id)#self generated unique id
    end

    it "can read csv files" do
      fr = FileReader.new({:file_path => './spec/files/csvtest.zip'})
      expect(File.basename(fr.file)).to eq('akw.csv')
      expect(fr.params[:srid]).to be(4326)
      expect(fr.params[:colsep]).to eq(';')
      expect(fr.params[:unique_id]).to be(:ID)
    end

    it "can read csv files with wkb geometry" do
      fr = FileReader.new({:file_path => './spec/files/wkb.csv'})
      expect(File.basename(fr.file)).to eq('wkb.csv')
      expect(fr.params[:srid]).to be(4326)
      expect(fr.params[:colsep]).to eq(';')
      expect(fr.params[:unique_id]).to be(:gid)
    end

    it "can read zipped shape files" do
      fr = FileReader.new({:file_path => './spec/files/shapeTest.zip'})
      expect(fr.params[:srid]).to be(2100)
    end

  end

end


