class Config
  CONFIG_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'config.yml'))

  class << self
    def admin?
    end

    def delete
    end

    def save
    end

    def setup?
    end

    def values
    end

    def writable?
    end
  end
end
