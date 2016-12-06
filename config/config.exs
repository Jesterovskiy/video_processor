# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :video_processor, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:video_processor, :key)
#
# Or configure a 3rd-party app:
#
# config :logger,
#   backends: [{LoggerFileBackend, :error_log}]
# config :logger, :error_log,
#   path: "/var/log/my_app/error.log",
#   level: :error

config :video_processor,
  complex_feed_url:    {:system, "COMPLEX_FEED_URL"},
  uplynk_account_guid: {:system, "UPLYNK_ACCOUNT_GUID"},
  uplynk_secret_key:   {:system, "UPLYNK_SECRET_KEY"},
  s3_url:              {:system, "AWS_S3_URL"}
config :ex_aws,
  access_key_id:     {:system, "AWS_ACCESS_KEY_ID"},
  secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
  upload_bucket:     {:system, "AWS_UPLOAD_BUCKET"}

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
