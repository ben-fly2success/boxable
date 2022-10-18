folders = ['app', 'lib', 'config']

Gem::Specification.new do |s|
  s.name = 'boxable'
  s.version = "0.1.23"
  s.summary = 'handle Box tree'
  s.files = Dir['{app,config,lib}/**/*']
  s.author = "Adrien LENGLET"
  s.require_paths = folders
end
