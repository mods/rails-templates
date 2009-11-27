# Facebook Skeleton App
# from Mark Daggett (http://www.locusfoc.us)
canvas_name = ask("What is your Facebook application's canvas name?")


# Plugins
# plugin 'rspec',              :git => 'git://github.com/dchelimsky/rspec.git'
# plugin 'rspec-rails',        :git => 'git://github.com/dchelimsky/rspec-rails.git'
plugin 'exception_notifier',     :git => 'git://github.com/rails/exception_notification.git'
plugin 'will_paginate',          :git => 'git://github.com/mislav/will_paginate.git'
plugin 'restful_authentication', :git => 'git://github.com/technoweenie/restful-authentication.git restful_authentication'

# Ignore auto-generated files
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

# Initial Setup
# generate("rspec")
generate("authenticated", "user session")

database = ask("***Database name?")
username = ask("***Database username?")
password = ask("***Database password?")

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


# Initial Migration
file "db/migrate/20090129183012_initial_migration.rb", 
%q{class InitialMigration < ActiveRecord::Migration
  def self.up
    create_table "accounts", :force => true do |t|
      t.string   "facebook_uid"
      t.boolean  "active"
      t.boolean  "is_app_user"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    
    create_table "sessions", :force => true do |t|
      t.string   "session_id", :null => false
      t.text     "data"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    execute("ALTER TABLE accounts CHANGE facebook_uid facebook_uid BIGINT") if adapter_name.to_s == "MySQL"
    add_index "accounts", ["facebook_uid"], :name => "index_accounts_on_facebook_uid"
    
    add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"
    add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  end
  
  def self.down
    drop_table :accounts
    drop_table :sessions
  end
end

}

file 'db/seeds.rb',
%q{
password = 'test09'
admin = User.create(:login => 'admin',
                    :email => 'xxxxx@test.it',
                    :password => password,
                    :password_confirmation => password,
                    :name    => 'Admin')
}

rake "db:create"
rake "db:migrate"
rake "db:seed"

# Now that we've migrated we can include Facebooker otherwise we get this error during the migration:
# uninitialized constant ActionController::AbstractRequest
# from: /vendor/plugins/facebooker/lib/facebooker/rails/facebook_url_rewriting.rb:2
plugin 'facebooker',         :git => "git://github.com/mmangino/facebooker.git"
rake "facebooker:setup"

initializer 'mime_types.rb', %q{Mime::Type.register_alias 'text/html', :fbml}


# Models
file 'app/models/account.rb', 
%q{class Account < ActiveRecord::Base  
  named_scope :active, :conditions => { :active => true }

  # Virtual attribute for when we need to associate a FB Session record with our model
  attr_accessor :facebook_account

  def to_param
    facebook_uid.to_s
  end

  def uninstall
    update_attributes(:active => false)
  end

  class <<self
    def find_or_create_by_facebook_params(u)
      account = find_or_initialize_by_facebook_uid(:is_app_user => true, :facebook_uid => u.uid.to_i, :active => true)
      account.active = true
      account.save
      account
    end
  end
end
}

# Controllers
file 'app/controllers/application_controller.rb', 
%q{class ApplicationController < ActionController::Base
  include FacebookerFilters
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # For use with will_paginate calls
  # For example: Account.paginate(:all, pagination_params.merge(:conditions => { :active => true }))
  
  def pagination_params(opts = {})
    { :page => params[:page] || 1, :per_page => params[:per_page] || 50 }.merge(opts)
  end

  # Redefine the needs permission method to include our redirect back to our app.
  # This is to ensure we don't end up on a dead-end page on Facebook.
  def application_needs_permission(perm)
    redirect_to(facebook_session.permission_url(perm, :next => "http://apps.facebook.com/#{ENV['FACEBOOKER_RELATIVE_URL_ROOT']}"+request.request_uri))
  end
end
}

file 'app/controllers/facebook_controller.rb', 
%q{class FacebookController < ApplicationController
  protect_from_forgery :except => [:index, :uninstalled, :authorized] 
  before_filter :only_for_facebook_users, :except => [:uninstalled]
  before_filter :find_facebook_account_during_uninstall, :only => [:uninstalled]
  before_filter :find_facebook_account, :except => [:uninstalled, :installed, :errors_with, :authorize_redirect, :authorized]

  def index
    redirect_to account_path(@account)
  end

  def authorized
  end

  def authorize_redirect
    installed
  end

  def installed
    @account = Account.find_or_create_by_facebook_params(facebook_session.user)
    raise ActiveRecord::RecordNotFound unless @account
    flash[:notice] = "The Facebook application is successfully installed."
    index
  end

  def privacy
  end

  def uninstalled
    find_facebook_account_during_uninstall
    if @account.uninstall
      render :nothing => true, :status => '200'
    else
      render :nothing => true, :status => '500'
    end
  end

  def help
  end
end
}

file 'app/controllers/accounts_controller.rb', 
%q{class AccountsController < ApplicationController
  before_filter :only_for_facebook_users
  before_filter :find_facebook_account

  # Used to view your own account
  # GET /accounts
  # GET /accounts.fbml
  def index
    respond_to do |format|
      format.fbml # index.fbml.erb
    end
  end

  # Used to view another user's account
  # GET /show/1
  # GET /show/1.fbml
  def show
    respond_to do |format|
      format.fbml {} # show.fbml
    end
  end
end
}

# Helpers 
file 'app/helpers/application_helper.rb', 
%q{module ApplicationHelper
  
  # Converts the normal Rails flash methods into the message types expected by Facebook.
  def render_facebook_flash(custom_flash = nil)
    message = custom_flash || flash
    flash_types = [:notice, :warning]
    message.keys.each do |x|
     case x 
       when :notice
         message[:success] = message[:notice]
       when :warning
         message[:explanation] = message[:warning]
     end
    end
    flash_types = [:error, :explanation, :success]
    flash_type = flash_types.detect { |a| message.keys.include?(a) }
    "<fb:%s><fb:message>%s</fb:message></fb:%s>" % [flash_type.to_s, message[flash_type],flash_type.to_s] if flash_type 
  end
end}

# Stylesheets
file 'public/stylesheets/facebook_scaffold.css', 
%q{/***************************************************
 * Rails UI Elements
 ***************************************************/
.flash_notice, .flash_error, .flash_warning, .flash_success, .flash_explanation {
  border: 1px solid #ebdfb0;
  background-color: #fff4c8;
  padding-top:0.5em !important;
  color: #000;
  text-align: center;
}

.flash_error {
  border: 1px solid #ebb0b0;
  background-color: #ffc8c8;  
}

.flash_notice, .flash_success {
  border: 1px solid #b0ebb0;
  background-color: #c8ffcb;
}

.flash_notice a, .flash_error a, .flash_warning a {
  color: #01a163;
  border: none !important;
}

.errorExplanation h2 {
  margin: 0;
  color: #c00;
}
.errorExplanation li {
  margin-left: 3.0em;
  font-weight: bolder;
  list-style: decimal;
  color: #c00;
}

.fieldWithErrors input {
  background-color: #faa;
  border: 1px solid #f00;
}
/***************************************************
 * Facebook UI Elements
 ***************************************************/
.fb_blue_button, .fb_gold_button {
  display:block;
  background-color: #536ea6;
  padding:2px;
  font-size:0.9em;
  text-align:center;
  color: #fff;
  font-weight:bolder;
  border: 1px solid #0e1f5b;
  border-left: 1px solid #D8DFEA;
  border-top: 1px solid #D8DFEA;
  text-decoration:none;
}

.fb_gold_button {
  background-color: #eff087;
  border: 1px solid #DCDE32;
  border-left: 1px solid #EFf087;
  border-top: 1px solid #EFf087;
  color: #1b1b1b;
  
}

.fb_content_box {
  margin: 10px 0 0 0 !important;
  border: 1px solid transparent;
  border-top: 1px solid #3B5998;
}

.fb_content_box .fb_content_box {
  border: none;
  margin: 0 !important;
}

.fb_content_box .head {
  background-color: #D8DFEA;
  color: #3B5998;
  font-size: 12px !important;
  margin:0 !important;
  padding:5px 5px 5px 10px !important;
  font-weight:bolder !important;
}

.fb_content_box .fb_content_box .head {
  background:#EEEEEE none repeat scroll 0% 0%;
}

.fb_content_box .sub_head {
  background:#EEEEEE none repeat scroll 0% 0%;
  margin:0 !important;
  border-top:1px solid #CCCCCC;
  color: #444444;
  overflow:hidden;
  padding:2px 5px 2px 10px !important;
  font-size: 11px !important;
  margin-bottom: 11px !important;
}

.fb_content_box .fb_content_box .sub_head {
  background:#fff none repeat scroll 0% 0%;
}

.fb_content_box .sub_head .inline_list {
  margin:0 !important;
}

.fb_content_box .sub_head .inline_list li {
  padding-left: 5px !important;
  font-size: 11px !important;
}

.fb_content_box .sub_head .inline_list li.first {
  padding-left: 0 !important;
}

.fb_content_box .content {
  padding:10px !important;  
}

.inline_fb_button_list a {
  display: block;
  margin:0;
  padding: 2px 10px;
  color: #fff;
  text-decoration: none;
}
.inline_fb_button_list a:hover, .inline_fb_button_list a:active {
  background-color: #6d84B4;
}
.inline_fb_button_list {
  display: block;
  float: left;
  font-size: 13px;
  list-style-image: none;
  list-style-position: outside;
  list-style-type: none;
  margin: 0px;
  padding: 0px;
  line-height: 2em;
  text-align: left;
  font-family: "lucida grande",tahoma,verdana,arial,sans-serif;
  font-size: 11px;
  text-align: left;
}
.inline_fb_button_list li {
  background-color: #3B5998;
  display:block;
  float:left;
  font-weight:bold;
  margin:0px 10px 0px 0px;
}
/***************************************************
 * Pagination
 ***************************************************/
.pagination {
  padding: 3px !important;
  margin: 3px !important;
}

.pagination a {
  padding: 2px 5px 2px 5px;
  margin: 2px;
  border: 1px solid #3B5998;
  text-decoration: none;
  color: #3B5998;
  background-color: transparent;
}

.pagination a:hover, .pagination a:active {
  border: 1px solid #3B5998;
  background-color: #3B5998;
  color: #FFF;
  font-weight: bold;
}

.pagination span.current {
  padding: 2px 5px 2px 5px;
  margin: 2px;
  border: 1px solid #3B5998;
  font-weight: bold;
  background-color: #3B5998;
  color: #FFF;
}

.pagination span.disabled {
  padding: 2px 5px 2px 5px;
  margin: 2px;
  border: 1px solid #eee;
  color: #ddd;
}
}

# Facebook Filters which are useful for sussing out and handling requests made by Facebook uers.
file 'lib/facebooker_filters.rb', 
%q{# This module contains a collection of helper methods that make detecting and 
# responding to Facebook methods easier.
module FacebookerFilters
  def self.included(base)
    base.class_eval do
      # The is a conditional before_filter that will only fire for requests using the fbml format.
      before_filter(:except => :uninstalled) do |controller|
        if controller.params["format"].to_s == "fbml"
          
          # This session property will be set if the user has called the allow_login_from_facebook is called before this 
          # filter; for example, prepend_before_filter :allow_login_from_facebook, :only => [:show]
          if controller.session[:authenticate_through_facebook].nil? || controller.session[:authenticate_through_facebook] == false
            controller.send(:ensure_application_is_installed_by_facebook_user)
          end
        end
      end
    end
  end
  
  def only_login_from_facebook_required
    session[:authenticate_through_facebook] = true
  end
  
  # For requests that use .fbml
  def find_facebook_account
    @facebook_session = facebook_session
    @account = Account.find_by_facebook_uid(@facebook_session.user.uid)
    
    raise ActiveRecord::RecordNotFound unless @account
    # Assign the current_account so that the existing before_filters that check for authentication can find this user.
    # self.current_account = @account
    @account
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Could Not Find Account"
    redirect_to(installed_path(:format => 'fbml')) and return false
  end

  # Deny access to any request that does not use the fbml format.
  def only_for_facebook_users
    unless params['format'].to_s == "fbml"
      flash[:error] = "This page must be viewed within Facebook."
      redirect_to root_url and return false 
    end
  end
  
  def find_facebook_account_during_uninstall
    @account = Account.find_by_facebook_uid(params["fb_sig_user"])
    raise ActiveRecord::RecordNotFound unless @account
    @account
  rescue ActiveRecord::RecordNotFound
    render :nothing => true, :status => '500' and return false
  end
end
}

# Views
file 'app/views/layouts/application.fbml.erb', 
%q{<% if ["production"].include?(ENV["RAILS_ENV"])  %>
    <%= stylesheet_link_tag "facebook_scaffold", :media => "screen" %>
  <%- else -%>
    <%= content_tag :style, File.readlines("public/stylesheets/facebook_scaffold.css").join("\n"), :type=>'text/css' %>
  <%- end -%>
  
  <%= render_facebook_flash() %>
  
  <%= yield %>
  <script type="text/javascript" charset="utf-8">

    // Give JS access to the canvas page name;
    CANVAS_PAGE_NAME= '<%= ENV["FACEBOOKER_RELATIVE_URL_ROOT"] %>';
    REMOTE_HOST = '<%= url_for :controller => "/facebook", :only_path => false, :canvas => false %>';

  </script>
  <%= javascript_tag "AUTH_TOKEN = #{form_authenticity_token.inspect};" if protect_against_forgery? %>

  <%= content_tag :script, File.readlines("public/javascripts/application.js").join("\n") %>
}

file 'app/views/accounts/index.fbml.erb', %q{
  Find me in: app/views/accounts/index.fbml.erb
}

file 'app/views/accounts/show.fbml.erb', %q{
  Find me in: app/views/accounts/show.fbml.erb
}

file 'app/views/facebook/about.fbml.erb', %q{
  Find me in: app/views/facebook/errors_with.fbml.erb
}

file 'app/views/facebook/tos.fbml.erb', %q{
  Find me in: app/views/facebook/tos.fbml.erb
}

file 'app/views/facebook/errors_with.fbml.erb', %q{
  Find me in: app/views/facebook/errors_with.fbml.erb
}

file 'app/views/facebook/help.fbml.erb', %q{
  Find me in: app/views/facebook/help.fbml.erb
}

file 'app/views/facebook/index.fbml.erb', %q{
  Find me in: app/views/facebook/index.fbml.erb
}

file 'app/views/facebook/installed.fbml.erb', %q{
  Finde me in: app/views/facebook/installed.fbml.erb
}


# Routing
route "map.resources :accounts"

# Facebook specific routes.
# Canvas URL And Side Nav URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/
route "map.root :controller => 'facebook'"

# About URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/about
route "map.about '/about', :controller => 'facebook', :action => 'about'"

# Post-Authorize URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/authorized
route "map.authorized '/authorized', :controller => 'facebook', :action => 'authorized'"
route "map.bp_authorized '/#{canvas_name}/authorized', :controller => 'facebook', :action => 'authorized'"

# Post-Authorize Redirect URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/authorize_redirect
route "map.authorize_redirect '/authorize_redirect', :controller => 'facebook', :action => 'authorize_redirect'"

# Facebook Application Profile
# http://apps.facebook.com/FACEBOOK_APP_NAME/profile
route "map.authorize_redirect '/profile', :controller => 'accounts', :action => 'index'"

# Post-Add URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/installed
route "map.installed '/installed', :controller => 'facebook', :action => 'installed'"

# Privacy URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/privacy
route "map.privacy '/privacy', :controller => 'facebook', :action => 'privacy'"

# Terms Of Service 
# http://apps.facebook.com/FACEBOOK_APP_NAME/tos
route "map.tos '/tos', :controller => 'facebook', :action => 'tos'"

# Post-Remove URL
# http://<some server>/FACEBOOK_APP_NAME/uninstalled  
route "map.uninstalled '/uninstalled', :controller => 'facebook', :action => 'uninstalled'"

# Help URL
# http://apps.facebook.com/FACEBOOK_APP_NAME/help
route "map.help '/help', :controller => 'facebook', :action => 'help'"

# Errors
route "map.errors_with_facebook '/errors_with_facebook', :controller => 'facebook', :action => 'errors_with'"


# Finalize
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"


# Add the whole ball of wax to git
# git :init
# git :add => "."
# git :commit => "-a -m 'Initial commit'"

