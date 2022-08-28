module Minithesis
  class FSDatabase
    def initialize(directory)
      @directory = directory
      Dir.mkdir(directory)
    rescue Errno::EEXIST
    end

    def []=(key, val)
      path = to_file(key)
      File.open(path) { |f| f.write(val) }
    end

    def get(key)
      f = to_file(key)
      return nil unless File.exist?(f)
      File.read(f)
    end

    def delete(key)
      File.unlink(key)
    rescue Errno::ENOENT
      raise KeyError
    end

    private

    def to_file(key)
      File.join(@directory, Digest::SHA512.hexdigest(key.encode('utf-8')))
    end
  end
end
