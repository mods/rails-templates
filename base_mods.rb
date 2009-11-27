generate :nifty_layout

# =====================
# Plugins
# =====================
plugin 'exception_notifier',     :git => 'git://github.com/rails/exception_notification.git'
plugin 'will_paginate',          :git => 'git://github.com/mislav/will_paginate.git'
plugin 'restful_authentication', :git => 'git://github.com/technoweenie/restful-authentication.git restful_authentication'

# =====================
# Ignore auto-generated files
# =====================
file '.bzrignore', 
%q{coverage/*
.bashrc
.bash_history
.ssh/*
.bzr.log
.mc/*
log/*.log
log/*.pid
db/*.db
db/*.sqlite3
db/schema.rb
tmp/**/*
.DS_Store
doc/api
doc/app
public/javascripts/all.js
public/stylesheets/all.js
coverage/*
.dotest/*
}

# =====================
# Initial Setup
# =====================
generate("authenticated", "user session")
generate("controller", "'admin/bacheca' index")
generate("controller", "'admin/login' index")

# =====================
#  EXTRANET
# =====================
route "map.admin '/admin',             :controller => 'admin/bacheca', :action => 'index'"
route "map.admin_login '/admin_login', :controller => 'admin/login', :action => 'index'"
file 'app/controllers/admin/bacheca_controller.rb', 
%q{class Admin::BachecaController < ApplicationController
  layout 'admin'
  before_filter :login_required
  
  def index
  end

  protected
  def authorized?
    logged_in? && current_user.login == 'admin'
  end
  
  def access_denied
    redirect_to admin_login_path
  end
end}

file 'app/controllers/admin/login_controller.rb',
%q{class Admin::LoginController < ApplicationController
  layout 'login_admin'
  def index
  end

end}

file 'app/views/admin/login/index.html.erb',
%q{
<% content_for :header do -%>
Login
<% end -%>

<% form_tag session_path do -%>
  &nbsp;

  <fieldset>
    <legend>Account</legend>

    <p><label for="login">Login</label><br/>
    <%= text_field_tag 'login' %></p>

    <p><label for="password">Password</label><br/>
    <%= password_field_tag 'password' %></p>
  </fieldset>

<div id="submitbutton">
  <p><%= submit_tag 'Log in &raquo;' %></p>
</div>
<% end -%>
}

file 'app/controllers/application_controller.rb',
%q{
class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include AuthenticatedSystem
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
end
}

run("cp -a ~/PROJECT/rails-templates/resources/stylesheets/* public/stylesheets/")
run("cp -a ~/PROJECT/rails-templates/resources/images/* public/images/")
run("cp -a ~/PROJECT/rails-templates/resources/javascripts/* public/javascripts/")
run("cp -a ~/PROJECT/rails-templates/resources/app/layouts/* app/views/layouts/")

# =====================
# Copi o i file di configurazione e li personalizzo
# =====================
run("cp -a ~/PROJECT/rails-templates/resources/config/* config/")
run("cp ~/PROJECT/shared/email.yml config/")

database = ask("*** Il nome del DB?")
username = "root"   # ask("***Database username?")
password = "mods"   # ask("***Database password?")

file 'config/database.yml',
%Q{
development:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{database}_dev
  pool: 5
  username: #{username}
  password: #{password}
  socket: /var/run/mysqld/mysqld.sock

test:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{database}_test
  pool: 5
  username: #{username}
  password: #{password}
  socket: /var/run/mysqld/mysqld.sock

production:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{database}_prod
  pool: 5
  username: #{username}
  password: #{password}
  socket: /var/run/mysqld/mysqld.sock
}

password_admin = ask("***Password della extranet (minimo 6 caratteri)")
file 'db/seeds.rb',
%Q{
password = '#{password_admin}'
admin = User.create(:login => 'admin',
                    :email => 'mods@iaki.it',
                    :password => password,
                    :password_confirmation => password,
                    :name    => 'Admin')
}

# =====================
# Attivo sessione nel DB
# =====================
run("echo 'ActionController::Base.session_store = :active_record_store' >> config/initializers/session_store.rb")

# =====================
# Capify il progetto
# =====================
file 'Capifile', %q{
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy'
}

# =====================
# Deploy
# =====================
application = ask("***Il dominio dell'applicazione")
domain = ask("***L'host su cui risiede")
user = ask("***Utente sul server")

file 'config/deploy.rb', %Q{
set :application, "#{application}"
set :repository, "/srv/www/\#{application}"
set :domain, "#{domain}"

role :web, "#{application}"
role :app, "#{application}"
role :db,  "#{application}", :primary=>true

set :user, "#{user}"
}
run("cat ~/PROJECT/rails-templates/resources/config/deploy.rb >> config/deploy.rb")


# =====================
# Creo e popolo il DB
# =====================
rake "db:create"
rake "db:sessions:create"

rake "db:migrate"
rake "db:seed"

# =====================
# Delete unnecessary files
# =====================
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"

# =====================
# Freezo la versione di rails
# =====================
rake "rails:freeze:gems"

# =====================
# Sistema di revisione
# =====================
run "bzr init"
run "bzr add"
run "bzr commit -m 'Init repo'"
