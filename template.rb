fail("Rails 7.0.0 or greater is required") if Rails.version <= "7"

def install_gems
  gem "govuk-components"
  gem "govuk_design_system_formbuilder"

  gem_group :test do
    gem "rspec"
    gem "rspec-rails"
  end

  run "bundle install"
end

def create_procfile
  file(
    "Procfile.dev",
    <<~PROCFILE
      web: bin/rails server -p 3000
      js: yarn build --watch
      css: yarn build:css --watch
    PROCFILE
  )
end

def create_bin_dev
  file(
    "bin/dev",
    <<~SH
      #!/usr/bin/env bash

      foreman start -f Procfile.dev
    SH
  )

  run "chmod +x bin/dev"
end

def create_manifest_js
  file("app/assets/config/manifest.js", force: true) do
    <<~JS
      //= link_tree ../builds/images
      //= link_tree ../builds/
    JS
  end
end

def create_package_json
  file(
    "package.json",
    <<~JSON
      {
        "name": "app",
        "private": "true",
        "dependencies": {
          "@hotwired/stimulus": "^3.0.1",
          "@hotwired/turbo-rails": "^7.1.0",
          "govuk-frontend": "^4.0.0",
          "esbuild": "^0.14.11",
          "sass": "^1.47.0"
        },
        "scripts": {
          "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds",
          "build:css": "sass ./app/assets/stylesheets/application.scss ./app/assets/builds/application.css --no-source-map --load-path=node_modules",
          "postinstall": "cp -rT node_modules/govuk-frontend/govuk/assets/fonts app/assets/builds/fonts && cp -rT node_modules/govuk-frontend/govuk/assets/images app/assets/builds/images"
        }
      }
    JSON
  )
end

def create_application_scss
  remove_file("app/assets/stylesheets/application.css")

  file("app/assets/stylesheets/application.scss", force: true) do
    <<~SCSS
      @use "govuk-frontend/govuk/all";
    SCSS
  end
end

def create_application_js
  file("app/javascript/application.js", force: true) do
    <<~JAVASCRIPT
      import "@hotwired/turbo-rails";
      // import "./controllers";

      import { initAll } from "govuk-frontend";

      initAll();
    JAVASCRIPT
  end
end

def create_application_html_erb
  file("app/views/layouts/application.html.erb", force: true) do
    <<~ERB
      <!DOCTYPE html>
      <html lang="en" class="govuk-template">
        <head>
          <title>GOV.UK Frontend on Rails</title>

          <%= csrf_meta_tags %>
          <%= csp_meta_tag %>

          <%= tag :meta, name: 'viewport', content: 'width=device-width, initial-scale=1' %>
          <%= tag :meta, property: 'og:image', content: asset_path('images/govuk-opengraph-image.png') %>
          <%= tag :meta, name: 'theme-color', content: '#0b0c0c' %>
          <%= favicon_link_tag asset_path('images/favicon.ico') %>
          <%= favicon_link_tag asset_path('images/govuk-mask-icon.svg'), rel: 'mask-icon', type: 'image/svg', color: "#0b0c0c" %>
          <%= favicon_link_tag asset_path('images/govuk-apple-touch-icon.png'), rel: 'apple-touch-icon', type: 'image/png' %>
          <%= favicon_link_tag asset_path('images/govuk-apple-touch-icon-152x152.png'), rel: 'apple-touch-icon', type: 'image/png', size: '152x152' %>
          <%= favicon_link_tag asset_path('images/govuk-apple-touch-icon-167x167.png'), rel: 'apple-touch-icon', type: 'image/png', size: '167x167' %>
          <%= favicon_link_tag asset_path('images/govuk-apple-touch-icon-180x180.png'), rel: 'apple-touch-icon', type: 'image/png', size: '180x180' %>

          <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
          <%= javascript_include_tag "application", "data-turbo-track": "reload", defer: true %>
        </head>

        <body class="govuk-template__body">
          <script>
            document.body.className = ((document.body.className) ? document.body.className + ' js-enabled' : 'js-enabled');
          </script>

          <%= govuk_skip_link %>

          <%= govuk_header(service_name: "GOV.UK Rails Boilerplate") do |header| %>
            <%= header.navigation_item(text: "Navigation item 1", href: "#", active: true) %>
            <%= header.navigation_item(text: "Navigation item 2", href: "#") %>
            <%= header.navigation_item(text: "Navigation item 3", href: "#") %>
          <% end %>

          <div class="govuk-width-container">
            <main class="govuk-main-wrapper" id="main-content" role="main">
              <%= yield %>
            </main>
          </div>

          <%= govuk_footer %>
        </body>
      </html>
    ERB
  end
end

def overwrite_pages_home_html_erb
  file("app/views/pages/home.html.erb", force: true) do
    <<~ERB
      <div class="govuk-grid-row">
        <div class="govuk-grid-column-two-thirds">
          <h1 class="govuk-heading-xl">It works! 🎉</h1>

          <p class="govuk-body">
            Your application is ready - so long as this page rendered without any errors you're good to go.
          </p>

          <%= govuk_summary_list(
            rows: [
              { key: { text: "Rails version" }, value: { text:  Rails.version } },
              { key: { text: "Ruby version" }, value: { text:  RUBY_VERSION } },
              { key: {
                text: "GOV.UK Frontend" },
                value: {
                  text: JSON
                    .parse(File.read(Rails.root.join("package.json")))
                    .dig("dependencies", "govuk-frontend")
                    .tr("^", "")
                }
              }
            ]
          ) %>
        </div>
      </div>
    ERB
  end
end

def add_pages_controller
  generate("controller", "pages", "home", "--skip-routes")
  route("root to: 'pages#home'")
end

def initialize_rspec
  generate("rspec:install")
end

def yarn
  run "mkdir app/assets/builds"
  run "yarn"
end

install_gems

after_bundle do
  create_procfile
  create_bin_dev
  create_manifest_js
  create_package_json
  create_application_scss
  create_application_js
  create_application_html_erb

  initialize_rspec
  add_pages_controller
  overwrite_pages_home_html_erb

  yarn
end