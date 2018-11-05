class FileSystem
  getter root : String, watchable : Array(String), files : Array(String)

  def initialize(@root)
    @watchable = [] of String
    @files = [] of String
  end

  def watch(path)
    watchable << path
    files.concat(Dir[File.join(path, "**")])
  end

  def clean
    watchable.each do |path|
      (Dir[File.join(path, "**")] - files).each do |path|
        File.delete(path)
      end
    end
  end
end
