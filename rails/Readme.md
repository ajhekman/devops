# Rails

A collection of files, settings, and scripts commonly used in Rails projects.

## Rails Template

The `rails_template.rb` file is a template for Rails projects. It is intended to be used with the `rails new` command.
It's not trying to be a one-size-fits-all template, but rather the first "80%" of starting a new Rails project. You will still need to clean up the generated code, add your own gems, and finish configuration.

*First ensure you're using modern versions of Ruby and Rails. Use asdf/rbenv to install.*
```bash
❯  ruby -v
ruby 3.1.2p20 # example, doesn't have to match exactly

❯  rails --version
Rails 7.0.3.1 # example, doesn't have to match exactly
```
*Then run the following command to create a new Rails project*
```bash
rails new my_app --template https://raw.githubusercontent.com/ajhekman/devops/main/rails/rails_template.rb --rc https://raw.githubusercontent.com/ajhekman/devops/main/rails/.railsrc
```
