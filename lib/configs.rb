class Configs

  CONFIG_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'config.yml'))

  class << self
    # def admin?
    # end

    def attributes
      @attributes ||= setup? ? YAML.load_file(CONFIG_PATH) : { }
    end

    def attributes=(attributes)
      @attributes = attributes
    end

    def create(attributes)
      @attributes = attributes
      save
    end

    def delete
      @attributes = nil
      File.delete(CONFIG_PATH)
    end

    def save
      File.open(CONFIG_PATH, "w") { |f| f.write(YAML.dump(attributes)) }
      return true
    end

    def setup?
      File.exists?(CONFIG_PATH)
    end

    def update_attributes(attributes)
      self.attributes = attributes
      save
    end

    def writable?
      File.writable?(CONFIG_PATH)
    end
  end
end
