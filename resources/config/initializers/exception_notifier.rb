admin_email = YAML.load_file("#{RAILS_ROOT}/config/settings.yml")[RAILS_ENV]['admin_email']
ExceptionNotifier.exception_recipients = [admin_email]

# defaults to exception.notifier@default.com
ExceptionNotifier.sender_address = %("Application Error" <app.err@test.it>)

# defaults to "[ERROR] "
ExceptionNotifier.email_prefix = "[APP rails] "
