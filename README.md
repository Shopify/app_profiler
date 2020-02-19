# AppProfiler

Profiling is critical to providing an understanding of an application's performance.

`AppProfiler` aims to provide a common framework for performance profiling for Rails applications.

## Installation

To install `app_profiler` you need to include it in your `Gemfile`.

## Profiling middleware

### Configuration

This gem automatically injects the `AppProfiler::Middleware` middleware into your Rails application.

This middleware can be disabled by using:

```ruby
AppProfiler.middleware.disabled = true
# OR
Rails.application.config.app_profiler.middleware_disabled = true
```

### Trigger profiling

Profiling can be triggered in one of two ways:
1. Using the `profile` key in the query string of the URL.
   - Query string format: `/?[key=value]&...`
2. Using the `X-Profile` key in the request headers.
   - `X-Profile` header format: `[<key>=<value>];...`


You can configure the profile header using:

```ruby
AppProfiler.profile_header = "X-Profile"
# OR
Rails.application.config.app_profiler.profile_header = "X-Profile"
```

### Here are some examples:

1. `/?profile=cpu&interval=2000&autoredirect=1`
2. Set `X-Profile` to `mode=wall;interval=1000;context=test-directory;autoredirect=1`

### Possible keys:

| Key | Value | Notes |
| --- | ----- | ----- |
| profile/mode | Supported profiling modes: `cpu`, `wall`, `object`. | Use `profile` in (1), and `mode` in (2). |
| interval | Sampling interval in milliseconds. | |
| autoredirect | Redirect request automatically to Speedscope's page after profiling. | |
| context | Directory within the specified bucket in the selected storage where raw profile data should be written. | Only supported in (2). Defaults to `Rails.env` if not specified. |

Note that the `autoredirect` feature can be turned on for all requests by doing the following:

```ruby
AppProfiler.autoredirect = true
# OR
Rails.application.config.app_profiler.autoredirect = true
```

When profiling is triggered, the middleware will generate the profile through StackProf and upload the profiles to your specified storage. For example, the default configuration would upload profiles to file storage.

When using a cloud storage provider, you can configure the target bucket name using:

```ruby
AppProfiler.storage.bucket_name = "new-bucket-name"
# OR
Rails.application.config.app_profiler.storage_bucket_name = "new-bucket-name"
```

## Profiling manually

`AppProfiler` can be used more simply to profile blocks of code. Here's how:

```ruby
report = AppProfiler.run(mode: :cpu) do
  # ...
end

report.view # opens the profile locally in speedscope.
```

Profile files can be found locally in your rails app at `tmp/app_profiler/*.json`.


## Storage backends

Profiles are stored based on the defined storage class. At the moment, the gem only supports file-based and remote storage via Google Cloud Storage. the default backend is file storage.

You can use a different backend with the following configuration:

```ruby
AppProfiler.storage = AppProfiler::Storage::GoogleCloudStorage
# OR
Rails.application.config.app_profiler.storage = AppProfiler::Storage::GoogleCloudStorage
```

Credentials for the selected storage can be set using the following configuration (Google Cloud Storage expects the path to a JSON file, or the JSON contents):

```ruby
AppProfiler.storage.credentials = { "key" => "value" }
# OR
Rails.application.config.app_profiler.storage_credentials = { "key" => "value" }
```

## Running tests

```
bin/setup && bundle exec rake
```
