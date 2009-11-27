

set :deploy_to, "/srv/www/#{application}"
set :scm, :bzr
set :checkout, "branch"

ssh_options[:keys] = %w(/home/mods/.ssh/identity)
ssh_options[:port] = 9003


task :before_update_code do
  `bzr push sftp://#{user}@#{domain}/srv/www/#{application}`
end

task :after_deploy do
  run "bzr update"
  run "cd #{repository} && whenever --update-crontab #{application}"
end

task :merge do
  `bzr merge sftp://#{user}@#{domain}/srv/www/#{application}`
end

desc "Scarica il database in locale ed installalo"
task :db_local, :roles =>:db do
  env   = ENV['RAILS_ENV'] || 'development'
  db_name_locale = YAML.load_file('./config/database.yml')[env]['database']
  
  database = YAML.load_file('./config/database.yml')['production']
  db_user  = database['username']
  db_pwd   = database['password']
  db_name  = database['database']
  
  run "mysqldump -u #{db_user} -p#{db_pwd} #{db_name} > /tmp/#{db_name}.sql"
  run "bzip2 -f /tmp/#{db_name}.sql"
  system "scp #{domain}:/tmp/#{db_name}.sql.bz2 /tmp"
  system "bunzip2 -c /tmp/#{db_name}.sql.bz2 | mysql -u root -pmods #{db_name_locale}"
  system "rm -f /tmp/#{db_name}.sql.bz2"
  run "rm -f /tmp/#{db_name}.sql.bz2"
end
