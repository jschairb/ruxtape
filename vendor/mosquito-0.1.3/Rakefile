$: << 'lib'

require 'rubygems'
require 'hoe'
require './lib/mosquito'

# Disable spurious warnings when running tests, ActiveMagic cannot stand -w
Hoe::RUBY_FLAGS.replace ENV['RUBY_FLAGS'] || "-I#{%w(lib test).join(File::PATH_SEPARATOR)}" + 
  (Hoe::RUBY_DEBUG ? " #{RUBY_DEBUG}" : '')

Hoe.new('Mosquito', Mosquito::VERSION) do |p|
  p.name = "mosquito"
  p.author = ["Geoffrey Grosenbach"] # TODO Add Julik ...
  p.description = "A library for writing tests for your Camping app."
  p.email = 'boss@topfunky.com'
  p.summary = "A Camping test library."
  p.changes = p.paragraphs_of('CHANGELOG', 0..1).join("\n\n")
  p.url = "http://mosquito.rubyforge.org"
  p.rdoc_pattern = /README|CHANGELOG|mosquito/
  p.clean_globs = ['**.log', 'coverage', 'coverage.data', 'test/test.log', 'email.txt']
  p.extra_deps = ['activerecord', 'activesupport', 'camping']
end

begin
  require 'rcov/rcovtask'
  desc "just rcov minus html output"
  Rcov::RcovTask.new do |t|
    t.test_files = FileList["test/test_*.rb"]
    t.verbose = true
  end

  desc 'Aggregate code coverage for unit, functional and integration tests'
  Rcov::RcovTask.new("coverage") do |t|
    t.test_files = FileList["test/test_*.rb"]
    t.output_dir = "coverage"
    t.verbose = true
    t.rcov_opts << '--aggregate coverage.data'
  end
rescue LoadError
end
