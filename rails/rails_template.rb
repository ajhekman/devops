# see https://guides.rubyonrails.org/generators.html

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }

append_file "README.md", <<~EOS

  ## Future gem considerations

  - `gem strong_migrations #prevent potentially harmful migrations from being run.
  - `gem "reforge"` #Data translation / transformation / adaptation
  - `gem "rack-cors"` # Cors headers for cross-origin requests
  - `gem "rack-host-redirect"` # Redirects from one host to anther 'myapp.herokuapp.com' => 'www.myapp.com'
  - `gem install squasher` #squashes migrations into a single file (usually installed outside of Gemfile)
EOS

gem_group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  # gem "debug", platforms: %i[mri mingw x64_mingw] # installed by default in rails 7

  # Brakeman is a security scanner for Ruby on Rails applications. https://brakemanscanner.org/docs/introduction/
  gem "brakeman"

  # Help to kill N+1 queries and unused eager loading https://github.com/flyerhzm/bullet
  gem "bullet"

  # Standardize ruby formatting https://github.com/testdouble/standard
  gem "standard"

  # A library for generating fake data such as names, addresses, and phone numbers.
  gem "faker"

  # fixtures replacement with a straightforward definition syntax
  gem "factory_bot_rails"

  # Insert template path in development
  gem "view_source_map"

  # prevent loading application in migrations
  gem 'good_migrations'
end

gem_group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  # gem "web-console" # installed by default in Rails 7

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  # Middleware that displays speed badge for every html page. https://github.com/MiniProfiler/rack-mini-profiler
  gem "rack-mini-profiler", require: false

  # For memory profiling (used with rack-mini-profiler)
  gem "memory_profiler"

  # For call-stack profiling flamegraphs (used with rack-mini-profiler)
  gem "stackprof"

  # prevent emailing in development. Mail is redirected to allowed email address.
  gem "recipient_interceptor"
end

gem_group :test do
  gem "vcr"

  # Use RSpec for testing
  gem "rspec-rails"
  # gem "capybara" # installed by default in Rails 7
  # gem "webdrivers", require: false # installed by default in Rails 7
end

gem_group :production, :staging do
  gem "lograge"
end

# Error reporting
gem "honeybadger"

# Ruby state machine
gem "aasm"

# Haml templates (replaces erb)
gem "haml-rails"

# Pagination
gem "kaminari"

# Money support
gem "money-rails"

# Easy styling for email
gem "premailer-rails"

# Block clients that send abusive requests (e.g. Fail2Ban)
gem "rack-attack"

# Better html forms
gem "simple_form"

# AR validations for dates and times
gem "validates_timeliness"

# Simple view-model for forms
gem "yaaf"

# Authorization
gem "pundit"

# Feature flags
gem "flipper"
gem "flipper-ui"
gem "flipper-active_record"

create_file "Brewfile", <<~EOF
  tap "heroku/brew"

  # Dependency install script for macOS environments.
  # Use for local development and match Aptfile.sh when possible.

  # GNU File, Shell, and Text utilities
  # brew "coreutils"

  # Object-relational database system
  brew "postgresql", restart_service: true

  # Persistent key-value database, with built-in net interface
  # brew "redis", restart_service: true

  # Everything you need to get started with Heroku
  brew "heroku/brew/heroku"

  # Github CLI
  brew "gh"

  # intercept mail and display locally. Useful for quick debugging.
  brew "mailhog"
EOF

create_file "Aptfile.sh", <<~'BASH'
  #!/bin/bash

  # Dependency install script for linux environments.
  # Use for CI, Production, etc. and match Brewfile when possible.

  set -eu -o pipefail # fail on error and report it, debug all lines

  sudo -n true
  test $? -eq 0 || exit 1 "you should have sudo privilege to run this script"

  echo "Updating apt lists"
  sudo apt-get update
  echo "installing dependencies"
  while read -r p ; do sudo apt-get install -y $p ; done < <(cat << "EOF"
      ca-certificates
      curl
      imagemagick
  EOF
  )
BASH

gem "paper_trail"
gem "postmark-rails"

# User authentication
gem "devise"
gem "devise-async"


run "brew bundle"
run "bundle install"
rake "db:prepare"

# =========== Gem install scripts and configuration ===========
generate "rack_profiler:install"
generate "simple_form:install"
generate "bullet:install"
generate "active_storage:install"
generate "flipper:active_record"
generate "AddSystemAdminToUser", "system_admin:boolean"
generate "pundit:install"

route <<~TEXT

  #
  # Admin only routes
  #
  authenticate :user, ->(user) { user.system_admin? } do
    mount Flipper::UI.app(Flipper) => "/flipper"
  end

TEXT

# =========== Rspec config ===========
generate "rspec:install"
run "standardrb --fix spec"

gsub_file "spec/spec_helper.rb", "  #   config.example_status_persistence_file_path = \"spec/examples.txt\"", "  config.example_status_persistence_file_path = \"spec/examples.txt\""
gsub_file "spec/spec_helper.rb", "  #   config.order = \"random\"", "  config.order = \"random\""
old_rspec_doc = %{  #   if config.files_to_run.one?\n  #     # Use the documentation formatter for detailed output,\n  #     # unless a formatter has already been configured\n  #     # (e.g. via a command-line flag).\n #     config.default_formatter = "doc"\n  #   end}
new_rspec_doc = %{if config.files_to_run.one?\n # Use the documentation formatter for detailed output,\n # unless a formatter has already been configured\n # (e.g. via a command-line flag).\n config.default_formatter = "doc"\n end}
gsub_file "spec/spec_helper.rb", old_rspec_doc, new_rspec_doc
gsub_file "spec/spec_helper.rb", "  #   Kernel.srand config.seed", "  Kernel.srand config.seed"

inject_into_file "spec/rails_helper.rb", after: %(require "rspec/rails"\n) do
  <<~'RUBY'
    require "capybara/rspec"
    require 'paper_trail/frameworks/rspec' # Use paper_trail with 'with_versioning' or 'versioning: true'
  RUBY
end

gsub_file "spec/rails_helper.rb",
  %!# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }!,
  %!Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }!

create_file "spec/support/capybara.rb", <<~'RUBY'
  require "webdrivers"

  RSpec.configure do |config|
    config.include Capybara::RSpecMatchers
    config.include Capybara::DSL

    config.after(type: :feature) do |scenario|
      if Capybara::Driver::Base.respond_to?(:window_handles)
        # Make sure all browser windows except one are closed
        windows.reject(&:current?).each(&:close)
      end
      if scenario.exception.present? && config.files_to_run.one?
        # Extra debugging when a scenario fails. Only activates when running a single test file.
        puts "Scenario failed #{scenario.example_group.name}."
        puts "Reason: #{scenario.exception.message}"
        puts "Saving page:"
        scenario.instance_exec { puts save_page }
      end
    end

    Capybara.default_max_wait_time = 5

    # Display chromedrive and other debugging information
    # Webdrivers.logger.level = :DEBUG

    Capybara.register_driver :headless_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new(
        args: %w[
          disable-web-security
          disable-gpu
          disable-popup-blocking
          window-size=1285,1080
          no-sandbox
          disable-blink-features=BlockCredentialedSubresources
          enable-features=NetworkService,NetworkServiceInProcess
        ],
        "goog:loggingPrefs": {
          browser: "ALL"
        }
      )
      options.headless! unless config.files_to_run.one?
      Capybara::Selenium::Driver.new(app, browser: :chrome, capabilities: options)
    end

    Capybara.register_driver :chrome do |app|
      Capybara::Selenium::Driver.new(app, browser: :chrome)
    end

    Capybara.javascript_driver = :headless_chrome
    # Capybara.javascript_driver = :chrome
  end
RUBY

# =========== Devise Config ===========
generate "devise:install"
model_name = ask("\n\nWhat would you like the user model to be called? [user]")
model_name = "user" if model_name.blank?
generate "devise", model_name
initializer "devise_async.rb", <<~RUBY
  Devise::Async.setup do |config|
    config.enabled = true
  end
RUBY


# =========== PaperTrail (gem) config ===========
generate "paper_trail:install"
inject_into_class "app/controllers/application_controller.rb", "ApplicationController", "before_action :set_paper_trail_whodunnit\n"


# === VCR config ===
create_file "spec/support/vcr.rb" do
  <<~RUBY
    require "vcr"
    require "webdrivers"

    VCR.configure do |c|
      c.ignore_localhost = true
      c.hook_into :webmock
      c.configure_rspec_metadata!
      c.cassette_library_dir = "spec/cassettes"
      c.debug_logger = File.open("log/vcr.log", "w")

      c.default_cassette_options = {
        record_on_error: false,
        record: :new_episodes
      }

      # Allow downloading webdrivers for Selenium
      # Selenium does a check to see if it is running the latest driver at https://chromedriver.storage.googleapis.com/LATEST_RELEASE_**
      driver_hosts = Webdrivers::Common.subclasses.map { |driver| URI(driver.base_url).host }
      c.ignore_hosts(*driver_hosts)
    end

    RSpec.configure do |config|
      config.before(:example, vcr: false) do
        WebMock.allow_net_connect!
        VCR.turn_off!
      end

      config.after(:example, vcr: false) do
        WebMock.disable_net_connect!
        VCR.turn_on!
      end
    end
  RUBY
end


inject_into_file "bin/setup", after: "FileUtils.chdir APP_ROOT do\n" do
  <<~'RUBY'

    puts "\n== Installing macOS system dependencies =="
    # Note: to upgrade brew dependencies, run 'brew bundle' yourself.
    # Brew doesn't manage versions, so we're intentionally not upgrading automatically.
    system("brew bundle check") || system!("brew bundle --no-upgrade")

  RUBY
end

gsub_file "bin/setup", /Preparing database/, "Priming development database"
gsub_file "bin/setup", /db:prepare/, "dev:prime"


# =========== Rack-Attack config ===========
initializer "rack_attack.rb", <<~'RUBY'
  class Rack::Attack
    # Cache only used for throttling
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    # Throttle all requests by IP (60rpm)
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets')
    end

    # Throttle POST requests to /login by IP address
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
    throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
      if req.path == '/users/sign_in' && req.post?
        req.ip
      end
    end

    # Throttle POST requests to /login by email param
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{normalized_email}"
    throttle('logins/email', limit: 5, period: 20.seconds) do |req|
      if req.path == '/users/sign_in' && req.post? && req.params.dig('user', 'email').present?
        req.params.dig('user', 'email').to_s.downcase.gsub(/\s+/, "").presence
      end
    end

    # Block suspicious requests for '/etc/password' or wordpress specific paths.
    # After 2 blocked requests in 10 minutes, block all requests from that IP for 30 minutes.
    Rack::Attack.blocklist('fail2ban pentesters') do |req|
      # `filter` returns truthy value if request fails, or if it's from a previously banned IP
      # so the request is blocked
      Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 1, findtime: 10.minutes, bantime: 30.minutes) do
        # The count for the IP is incremented if the return value is truthy
        CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
        req.path.include?('/etc/passwd') ||
        req.path.include?('wp-admin') ||
        req.path.include?('wp-login')

      end
    end
  end
RUBY


# =========== Routes ==================
generate :controller, "home show"
route "root 'home\#show'"
append_file "app/views/home/show.html.haml", <<~'HAML'
  .show-page
    .header
      %header.bg-white
        .mx-auto.py-6.px-4.sm:px-6.lg:px-8
          %h1.text-3xl.tracking-tight.font-bold.text-gray-900 Rails Kickstart
    .bg-black.p-6
      %h2.text-white.font-bold.mb-4 TODO: include all theme colors

      .flex.flex-col.space-y-3.sm:flex-row.text-xs.sm:space-y-0.sm:space-x-4
        .w-16.shrink-0
          .h-10.flex.flex-col.justify-center
            .text-sm.font-semibold.text-slate-900.dark:text-slate-200 Slate
        .min-w-0.flex-1.grid.grid-cols-5.2xl:grid-cols-10.gap-x-4.gap-y-3.2xl:gap-x-2
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(248, 250, 252);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 50
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #F8FAFC
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(241, 245, 249);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 100
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #F1F5F9
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(226, 232, 240);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 200
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #E2E8F0
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(203, 213, 225);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 300
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #CBD5E1
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(148, 163, 184);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 400
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #94A3B8
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(100, 116, 139);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 500
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #64748B
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(71, 85, 105);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 600
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #475569
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(51, 65, 85);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 700
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #334155
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(30, 41, 59);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 800
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #1E293B
          %div{:class => "space-y-1.5"}
            .h-10.w-full.rounded.dark:ring-1.dark:ring-inset{:class => "dark:ring-white/10", :style => "background-color: rgb(15, 23, 42);"}
            .md:flex.md:justify-between.md:space-x-2.2xl:space-x-0.2xl:block{:class => "px-0.5"}
              .w-6.font-medium.text-slate-900.2xl:w-full.dark:text-white 900
              .text-slate-500.font-mono.lowercase.dark:text-slate-400 #0F172A

    .other.max-w-full
      %p
        %pre
          = Bundler::Env.report
HAML


# =========== Gitignore ===========
inject_into_file(".gitignore", after: "/config/master.key\n") do
  <<~HERE
    /config/*.key

    /bin/post-install.sh
  HERE
end

# =========== dev:prime ===========
rakefile "dev.rake" do
 <<~'RUBY'
  #
  # Any data that needs created to help in local development
  # should be done here.
  #
  # If you want to add data that should always be present in
  # every environment (including production), you are probably
  # looking for db/seeds.rb
  #
  if Rails.env.development? || Rails.env.test? || ENV["HEROKU_APP_NAME"].present?
    require "factory_bot"

    namespace :dev do
      desc "Reset database and load data"
      task prime: [:environment, "dev:reset_state"] do
        load_prime_data
      end

      desc "Reset database and load data without running migrations"
      task re_prime: [:environment, "dev:quick_reset_state"] do
        load_prime_data
      end

      desc "Keep existing database and load data"
      task load: :environment do
        load_prime_data
      end

      desc "Reset datastores quickly through truncation and re-seed"
      task quick_reset_state: [:environment, "dev:destroy_attachments", "dev:delete_temporary_files", "dev:destroy_redis", "db:truncate_all", "db:seed"]

      desc "Reset datastores thoroughly via delete, create, migrate, and re-seed"
      task reset_state: [:environment, "dev:destroy_attachments", "dev:delete_temporary_files", "dev:destroy_redis", "dev:db_drop_and_migrate", "db:seed"]

      task db_drop_and_migrate: [:environment, "db:drop", "db:create", "db:migrate"]

      desc "Delete all temporary files"
      task delete_temporary_files: ["log:clear", "tmp:clear", "tmp:create", "assets:clobber"]

      task destroy_attachments: [:environment] do
        begin
          # remove any files left over from testing
          FileUtils.rm_rf(Rails.root.join("tmp", "storage"))
          puts "Purging all active record attachments..."
          ActiveStorage::Attachment.find_each { |attachment| attachment.purge }
          puts "  Done"
        rescue => e
          puts "Failed purging attachments: #{e}"
        end

        if Rails.configuration.active_storage.service == :local
          puts "`:local` ActiveStorage in use, also deleting `storage` folder contents"
          FileUtils.rm_rf(Rails.root.join("storage"))
          puts "  Done"
        end
      end

      task destroy_redis: [:environment] do
        Redis.current.flushall if defined?(Redis)
      end
    end

    def load_prime_data
      ActiveRecord::Base.descendants.each do |klass|
        klass.reset_column_information
      end

      # Put data that makes development easier here. This is contrasted with
      # db/seeds.rb in that this data makes development easier, but it is not
      # required for production. Whereas db/seeds.rb is required for all
      # environments. .

    end
  end

  RUBY
end

# =========== Gemfile.next ===========
run "ln -s Gemfile Gemfile.next"
run "ln -s Gemfile.lock Gemfile.next.lock"
gsub_file "Gemfile", /^gem (['"])rails['"](.*)/ do |match|
  rails_line = /^gem (['"])rails['"](.*)/.match(match)
  quote = rails_line.captures.first
  version = rails_line.captures.last
  <<~RUBY
    if __FILE__ =~ /Gemfile\.next/
      # Use this pattern with 'bundle install --gemfile=Gemfile.next' to
      # incrementally install updated gems, while maintaining a single gemfile.
      # Gemfile.next should be symbolic-linked to Gemfile, and Gemfile.next.lock
      # should be its own file (when upgrading, it can be a symbolic link when
      # not upgrading).
      gem #{quote}rails#{quote}
    else
      gem #{quote}rails#{quote}#{version}
    end
  RUBY
end
gsub_file "Gemfile", /^ruby.*$/, %q|ruby "#{File.read('.ruby-version').chomp.gsub(/^.+?(?=\d)/,'')}"|


# =========== recipient_interceptor ===========
append_to_file "config/environments/development.rb" do
  <<~'RUBY'

  # Redirect all outbound mail to this address
  Mail.register_interceptor(
    RecipientInterceptor.new(
      ["devs@example.com"],
      subject_prefix: "[#{Rails.env}]"
    )
  )
  RUBY
end

# # =========== mailhog ===========
# append_to_file("Procfile.dev", "mail: mailhog")


git add: "."
git commit: %Q{ -m "Installed with rails template\n\nhttps://github.com/ajhekman/devops" }



__END__
# ================================================================
# helpful patterns for this template file:
# see also https://guides.rubyonrails.org/generators.html

# TODO:

# - configure development to use mailhog https://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration



if yes? 'Do you wish to generate a root controller? (y/n)'
  name = ask('What do you want to call it?').to_s.underscore
  generate :controller, "#{name} show"
  route "root to: '#{name}\#show'"
  route "resource :#{name}, controller: :#{name}, only: [:show]"
end

inject_into_file 'name_of_file.rb', after: "#The code goes below this line. Don't forget the Line break at the end\n" do <<~'RUBY'
  puts "Hello World"
RUBY
end

gsub_file 'name_of_file.rb', 'method.to_be_replaced', 'method.the_replacing_code'

# Adds a line to config/application.rb directly after the application class definition.
application do
  "config.asset_host = 'http://example.com'"
end
application(nil, env: "development") do
  "config.asset_host = 'http://localhost:3000'"
end

git :init
git add: "."
git commit: "-m First commit!"
git add: "onefile.rb", rm: "badfile.cxx"

rakefile "test.rake" do
  %Q{
    task rock: :environment do
      puts "Rockin'"
    end
  }
end

initializer "begin.rb" do
  "puts 'this is the beginning'"
end

rake "db:migrate"
rake "db:migrate", env: "test"

route "resources :people"

readme "README"

inside('vendor') do
  run "ln -s ~/commit-rails/rails rails"
end








