require 'ruxtape'
require 'spec'

class Configs
  CONFIG_PATH = File.expand_path(File.join(File.dirname(__FILE__), 'support', 'config_spec.yml'))
end

describe Configs do 
  describe "#admin?" do 
  end

  describe "#attributes" do 
    it "returns a hash" do 
      Configs.attributes.should be_kind_of(Hash)
    end

    it "returns the proper hash if not read from the file" do 
      Configs.attributes = { :foo => "bar", :bah => "buzz" }
      Configs.attributes[:foo].should == "bar"
      Configs.attributes[:bah].should == "buzz"
    end
  end

  describe "#create" do 

    before do 
      ensure_file_does_not_exist
    end

    it "returns true" do 
      Configs.create(:foo => "bar").should == true
    end

    it "saves attributes passed as a hash" do 
      Configs.create(:foo => "bar").should == true
      Configs.attributes[:foo].should == "bar"
    end

    it "ensures the file is created" do 
      Configs.create(:foo => "bar").should == true
      File.exists?(Configs::CONFIG_PATH).should == true
    end
  end

  describe "#update_attributes" do 
    it "merges attributes"  do 
      ensure_file_exists
      Configs.update_attributes(:foo => "bah", :fizz => "buzz").should == true
      YAML.load_file(Configs::CONFIG_PATH)[:foo].should == "bah"
      YAML.load_file(Configs::CONFIG_PATH)[:fizz].should == "buzz"
    end
  end

  describe "#delete" do 
    it "removes the config file" do 
      ensure_file_exists
      Configs.delete
      File.exists?(Configs::CONFIG_PATH).should == false
    end
  end

  describe "#save" do 
    it "returns true, if successful" do 
      Configs.save.should == true
    end

    it "YAML dumps the hash into the file" do 
      File.open(Configs::CONFIG_PATH, "w") { |f| f.write(YAML.dump({ :foo => "bar" })) }
      YAML.load_file(Configs::CONFIG_PATH)[:foo].should == "bar"
    end
  end

  describe "#setup?" do 
    it "returns true if config file exists" do 
      File.exists?(Configs::CONFIG_PATH).should == true
      Configs.should be_setup
    end

    it "returns false if config file does not exist" do 
      File.delete(Configs::CONFIG_PATH)
      File.exists?(Configs::CONFIG_PATH).should == false
      Configs.should_not be_setup
    end
  end

  describe "#writable?" do 
    it "returns true if the file is writable" do 
      ensure_file_exists
      File.writable?(Configs::CONFIG_PATH).should == true
      Configs.should be_writable
    end
  end

  def ensure_file_exists
    File.exists?(Configs::CONFIG_PATH) ? true : File.open(Configs::CONFIG_PATH, "w") { |f| f.write({ :foo => "bar"}) }
  end

  def ensure_file_does_not_exist
    File.exists?(Configs::CONFIG_PATH) ? File.delete(Configs::CONFIG_PATH) : true
  end

end
