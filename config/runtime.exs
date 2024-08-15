import Config

if Mix.env() == :test do
  config :wallaby,
    driver: Wallaby.Chrome,
    screenshot_on_failure: true
end
