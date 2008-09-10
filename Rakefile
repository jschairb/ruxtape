require 'fileutils'

desc "Combines [update, restart]"
task :deploy => [:update, :restart]

desc "Pulls the latest code from a git repository"
task :update => :load_config do 
  command = "ssh #{HOST} 'cd #{DEPLOY_TO} && git pull'"
  puts "Pulling yur latest codez..."
  system(command)
end

desc "Restarts app processes by touching tmp/restart.txt"
task :restart => :load_config do 
  command = "ssh #{HOST} 'touch #{File.join(DEPLOY_TO, "tmp", "restart.txt")}'"
  puts "Restarting yur processez..."
  system(command)
end

desc "Copies relevant example files to their rightful locations"
task :install => [:install_rack, :install_deploy]

desc "[LOCAL]Copies example config.ru to root"
task :install_rack do 
  example = File.join(File.dirname(__FILE__), 'examples', 'example.config.ru')
  actual = File.join(File.dirname(__FILE__), 'config.ru')
  unless File.exists?(actual)
    cp(example, actual)
  else
    puts "#{actual} exists.  File not copied."
  end
end

desc "[LOCAL]Copies example deploy.rb to config"
task :install_deploy do 
  example = File.join(File.dirname(__FILE__), 'examples', 'example.deploy.rb')
  actual = File.join(File.dirname(__FILE__), 'config', 'deploy.rb')
  unless File.exists?(actual)
    cp(example, actual)
  else
    puts "#{actual} exists.  File not copied."
  end
end

task :load_config do 
  load File.join(File.expand_path(File.dirname(__FILE__)), 'config', 'deploy.rb')
end
