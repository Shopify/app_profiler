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

1. `/?profile=cpu&interval=2000&autoredirect=1&ignore_gc=1`
2. Set `X-Profile` to `mode=wall;interval=1000;context=test-directory;autoredirect=1`

### Possible keys:

| Key | Value | Notes |
| --- | ----- | ----- |
| profile/mode | Supported profiling modes: `cpu`, `wall`, `object`. | Use `profile` in (1), and `mode` in (2). |
| interval | Sampling interval in microseconds. | |
| ignore_gc | Ignore garbage collection frames | |
| autoredirect | Redirect request automatically to Speedscope's page after profiling. | |
| context | Directory within the specified bucket in the selected storage where raw profile data should be written. | Only supported in (2). Defaults to `Rails.env` if not specified. |

Note that the `autoredirect` feature can be turned on for all requests by doing the following:

```ruby
AppProfiler.autoredirect = true
# OR
Rails.application.config.app_profiler.autoredirect = true
```

To customize the redirect location you can provide a proc:

```ruby
AppProfiler.profile_url_formatter = ->(upload) { "https://host.com/custom/#{upload.name}" }
# OR
Rails.application.config.app_profiler.profile_url_formatter = ->(upload) { "https://host.com/custom/#{upload.name}" }
```

When profiling is triggered, the middleware will generate the profile through StackProf and upload the profiles to your specified storage. For example, the default configuration would upload profiles to file storage.

When using a cloud storage provider, you can configure the target bucket name using:

```ruby
AppProfiler.storage.bucket_name = "new-bucket-name"
# OR
Rails.application.config.app_profiler.storage_bucket_name = "new-bucket-name"
```

### Access control

You may restrict the storing of profiling results by defining your own Middleware based on `AppProfiler::Middleware` and changing the `after_profile` hook method to return `false` for such cases.

For example, the following middleware only stores the profiling results if a `disallow_profiling` key was not added to the `request.env` while processing the request.

```ruby
class AppProfilerAuthorizedMiddleware < AppProfiler::Middleware
  def after_profile(env, params)
    !env.key?("disallow_profiling")
  end
end
```

You can also restrict running profiling at all by using `before_profile`. For
example you may wish to prevent anonymous users triggering the profiler:

```ruby
class AppProfilerAuthorizedMiddleware < AppProfiler::Middleware
  def before_profile(env, params)
    current_user.present?
  end
end
```

The custom middleware can then be configured like the following:

```ruby
Rails.application.config.app_profiler.middleware = AppProfilerAuthorizedMiddleware
```

## Profile Server

This option allows for profiles to be passively collected via an HTTP endpoint,
inspired by [golang's built-in pprof server](https://pkg.go.dev/net/http/pprof).

A minimal Rack app runs a minimal (non-compliant) HTTP server, which exposes an
endpoint that allows for profiling. For security purposes, the server is bound
to localhost only. The HTTP server is built using standard library modules only,
in order to keep dependencies minimal. Because it is an entirely separate server,
listening on an entirely separate socket, this should not interfere with any
existing application routes, and should even be usable in non-web apps.

This allows for two main use cases:

- Passive profile collection in production
  - Periodically profiling production apps to analyze them responding to real
workloads
  - Providing a statistical, long-term view of the "hot paths" of the workload
- Local development profiling
  - Can be used to get a profile "on demand" against a development server

### Configuration

If using as a railtie, only a single option needs to be set:

```
config.app_profiler.server_enabled = true
```

Alternatively, the server can be directly started with:

```
AppProfiler::Server.start!
```

The default duration, for requests without a duration parameter, can also be
set via the railtie config.

```
AppProfiler.server.duration
```

It is possible, but not recommended, to hardcode the listen port to be used with

```
AppProfiler.server.port
```

If this is done in production and it can cause port conflicts with multiple
instances of the app.


#### Discovering the port

In general, the server should be run without setting the port, in which case
any free TCP port may be used. To determine what the port is, check the
application logs, or resolve it from the special "Magic file" which contains
a mapping of pid to port:

```
$ PID=49825
$ port_file=$(ls -1 /tmp/app_profiler/profileserver-$PID-port-*)
$ PORT=$(echo $port_file | sed 's/.*port-\([[:digit:]]*\)-.*/\1/g')
$ echo $PORT
60160
```

This approach is intended to be "machine friendly" so that an external
profiling agent can easily detect what port to profile on.

### Collecting a profile

The API is very simple, and passes supported parameters directly to stackprof.

Supported are:

- mode: the stackprof mode to use [cpu, wall, object]
- interval: the interval to use
  - For cpu and wall, this will be the duration in microseconds between samples
  - For object, this be the modulus of which allocations are counted. Eg, for
1, every allocation is counted. For 10, only every tenth will be.
- duration: how long the profiling session should last

For example, to collect a heap profile for 60 seconds, counting every 10th
allocation:

```
curl "http://127.0.0.1:$PORT/profile?duration=60&mode=object&interval=10"
```

#### Usage with speedscope directly

By default the server will allow CORS. This can be disabled if it presents a
problem, but it should be generally safe given that the server listens for
requests on localhost only, which is already a private network address.

This can be used with a local instance of speedscope to directly initiate
profiling from the browser. Assuming speedscope is running locally on port
`9292`, and the profile server is running on port `57510`, the server address
can  be URL encoded, and passed to speedscope via `#profileURL`:

```
http://127.0.0.1:9292/#profileURL=http%3A%2F%2F127.0.0.1%3A57510%2Fprofile%3Fduration%3D1
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

Note that in `development` mode the file isn't uploaded. Instead, it is viewed via the `Middleware::ViewAction`. If you want to change that, use the `middleware_action` configuration:

```ruby
Rails.application.config.app_profiler.middleware_action = AppProfiler::Middleware::UploadAction
```

## Running tests

```
bin/setup && bundle exec rake
```
