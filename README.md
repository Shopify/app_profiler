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


If `async` query string is provided, then the profile will be uploaded later, in an async manner. One use case for this is when we want to profile a certain % of traffic without incurring costs of inline profile uploads. Async background processing provides three callbacks:

1. profile_enqueue_success: Called when a profile is successfully added to the queue, to be uploaded later.
2. profile_enqueue_failure: Called when a profile fails to be enqueued due to no space left in the queue, `upload_queue_max_length` exceeded.
3. after_process_queue: Called when profiles are uploaded from the background thread.

These callbacks can be configured the following manner:

```ruby
AppProfiler.profile_enqueue_success = ->() {  StatsD.increment("profile_enqueue_success") }
# OR
Rails.application.config.app_profiler.profile_enqueue_success = ->() {  StatsD.increment("profile_enqueue_success") }
```

```ruby
AppProfiler.profile_enqueue_failure = ->(profile) {  Rails.logger.info("Profile #{profile.inspect} could not be enqueued.") }
# OR
Rails.application.config.app_profiler.profile_enqueue_failure = ->(profile) {  Rails.logger.info("Profile #{profile.inspect} could not be enqueued.")}
```

```ruby
AppProfiler.after_process_queue = ->(num_success, num_failures) { StatsD.gauge("async_profile_upload", tags: { sucessful: num_success, failed: num_failures} )}
# OR
Rails.application.config.app_profiler.after_process_queue = ->(num_success, num_failures) { StatsD.gauge("async_profile_upload", tags: { sucessful: num_success, failed: num_failures} )}
```



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
| profile/mode | Supported profiling modes: `cpu`, `wall`, `object` for stackprof. | Use `profile` in (1), and `mode` in (2). Vernier backend only supports `wall` and `retained` at present time. |
| async | Upload profile in a background thread. When this is set, profile redirect headers are not present in the response.
| interval | Sampling interval in microseconds. | |
| ignore_gc | Ignore garbage collection frames | |
| autoredirect | Redirect request automatically to Speedscope's page after profiling. | |
| context | Directory within the specified bucket in the selected storage where raw profile data should be written. | Only supported in (2). Defaults to `Rails.env` if not specified. |
| backend | Profiler to use, either `stackprof` or `vernier`. Defaults to `stackprof`. Note that Vernier requires Ruby 3.2.1+. |


Note that the `autoredirect` feature can be turned on for all requests by doing the following:

```ruby
AppProfiler.autoredirect = true
# OR
Rails.application.config.app_profiler.autoredirect = true
```

File names of profiles are prefixed by default with timezoned date and time, follow by profile mode, an id, and hostname of the machine where it was capture. For example: `20221006-121110-cpu-613fa8d2cdde5820d5312dea1cfa43d9-macbook-pro-work.lan.json`. To customize the prefix you can provide a proc:

```ruby
AppProfiler.profile_file_prefix = -> { "custom-prefix" }
# OR
Rails.application.config.app_profiler.profile_file_prefix = -> { "custom-prefix" }

```
As opposed to `profile_file_prefix`, which is used to customize the prefix of a file name, `profile_file_name` is used to provide the actual file name. If both are provided, `profile_file_name` takes precedence.

```ruby
AppProfiler.profile_file_name = ->(metadata) { "profile-#{metadata[:id]}-#{metadata[:hostname]}.json" }
# OR
Rails.application.config.app_profiler.profile_file_name = ->(metadata) { "profile-#{metadata[:id]}-#{metadata[:hostname]}.json" }
```

To customize the redirect location you can provide a proc:

```ruby
AppProfiler.profile_url_formatter = ->(upload) { "https://host.com/custom/#{upload.name}" }
# OR
Rails.application.config.app_profiler.profile_url_formatter = ->(upload) { "https://host.com/custom/#{upload.name}" }
```

### OpenTelemetry Instrumentation

Apps using OpenTelemetry can add attributes to traces. This can be useful for correlating profiling data with traces. 

To enable this feature, you can set  `otel_instrumentation_enabled` to `true`. The gem does not require the `opentelemetry` gem to be installed. If the gem is not installed or if it is not loaded, enabling it will raise an `ArgumentError`. By default, the feature is disabled.

```ruby
AppProfiler.otel_instrumentation_enabled = true
# OR
Rails.application.config.app_profiler.otel_instrumentation_enabled = true
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

Profile's custom metadata can be passed on to the uploaded [GCS object](https://cloud.google.com/storage/docs/metadata) using:

```ruby
AppProfiler.forward_metadata_on_upload = true
# OR
Rails.application.config.app_profiler.forward_metadata_on_upload = true
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

Alternatively, the server can be directly started by passing in a logger as follows:

```
AppProfiler::Server.start(logger)
```

The default duration (in seconds), for requests without a duration parameter, can also be
set via the railtie config.

```
AppProfiler.server.duration = 30
# OR
Rails.application.config.app_profiler.server_duration = 30
```

The server supports both TCP and Unix sockets for its transport. It is
recommended to use TCP for local development, and Unix sockets for production:

```
AppProfiler.server.transport = AppProfiler::Server::TRANSPORT_UNIX
# OR
Rails.application.config.app_profiler.server_transport = AppProfiler::Server::TRANSPORT_UNIX
```

It is possible, but not recommended, to hardcode the listen port to be used in
TCP server mode with:

```
AppProfiler.server.port = 8080
# OR
Rails.application.config.app_profiler.server_port = 8080
```

If this is done in production and it can cause port conflicts with multiple
instances of the app, which is another reason why the Unix transport is
preferred for production.

#### Discovering the port or socket path

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

For the Unix mode, this is even easier as the file simply includes the PID
in it, and this will be the file handle to use for the Unix socket:

```
$ PID=41016
$ SOCK=$(ls -1d /tmp/app_profiler/* | grep $PID.sock)
$ echo $SOCK
/tmp/app_profiler/app-profiler-41016.sock
```

### Collecting a profile

The API is very simple, and passes supported parameters directly to stackprof.

See the [possible keys](#possible-keys) for additional documentation on the
supported parameters.

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

report.view # opens the profile locally in speedscope by default
```

Profile files can be found locally in your rails app at `tmp/app_profiler/*.json`.

**Note** In development, if using the `AppProfiler::Viewer::SpeedscopeRemoteViewer` for stackprof
or if using Vernier, a route for `/app_profiler` will be added to the application.
If using Vernier, a route for `/from-url` is also added. These will be handled
in middlewares, before any application routing logic. There is a small chance
that these could shadow existing routes in the application.

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

Note that in `development` and `test` modes the file isn't uploaded. Instead, it is viewed via the `Middleware::ViewAction`. If you want to change that, use the `middleware_action` configuration:

```ruby
Rails.application.config.app_profiler.middleware_action = AppProfiler::Middleware::UploadAction
```

## Profiler backends

It is possible to configure AppProfiler to use the [`vernier`](https://github.com/jhawthorn/vernier) or [`stackprof`](https://github.com/tmm1/stackprof). To use `vernier`, it must be added separately in the application Gemfile.

The backend can be selected dynamically at runtime using the `backend` parameter. The default backend to use when this parameter is not specified can be configured with:

```ruby
AppProfiler.backend = AppProfiler::StackprofBackend # or AppProfiler::VernierBackend
# OR
Rails.application.config.app_profiler.backend = AppProfiler::StackprofBackend # or AppProfiler::VernierBackend
```

By default, the stackprof backend will be used.

In local development, changing the backend will change whether the profile is viewed in Speedscope or Firefox Profiler.


## Profile Sampling

The `AppProfiler` middleware can be configured to sample a percentage of requests for profiling. This can be useful for profiling a subset of requests in production without profiling every request.

To enable profile sampling, you can either set `profile_sampler_enabled` to `true` or provide your own custom `Proc`:

```ruby
AppProfiler.profile_sampler_enabled = true
# OR
Rails.application.config.app_profiler.profile_sampler_enabled = true
```

```ruby
AppProfiler.profile_sampler_enabled = -> { sampler_enabled? }
# OR
Rails.application.config.app_profiler.profile_sampler_enabled = -> { sampler_enabled? }
```


Both backends, StackProf and Vernier, can be configured separately.

These can be overridden like:

```ruby
AppProfiler.profile_sampler_config = AppProfiler::Sampler::Config.new(
  sample_rate: 0.5,
  targets: ["/foo"],
  backends_probability: { stackprof: 0.5, vernier: 0.5 },
  backend_configs: {
    stackprof: AppProfiler::Sampler::StackprofConfig.new,
    vernier: AppProfiler::Sampler::VernierConfig.new,
)

# OR

Rails.application.config.app_profiler = AppProfiler::Sampler::Config.new(
  sample_rate: 0.5,
  targets: ["/foo"],
  backends_probability: { stackprof: 0.5, vernier: 0.5 },
  backend_configs: {
    stackprof: AppProfiler::Sampler::StackprofConfig.new,
    vernier: AppProfiler::Sampler::VernierConfig.new,
)

```

All the configuration parameters are optional and have default values. The default values are:

```ruby

| Sampler Config                                         | Default         |
| --------                                               | -------         |
| sample_rate (0.0 - 1.0)                                | 0.001 (0.1 %)   |
| targets (request paths, job_names etc )                | ['/']           |
| exclude_targets (request paths, job_names etc )        | ['/ping']       |
| stackprof_probability                                  | 1.0             |
| vernier_probability                                    | 0.0             |

| StackprofConfig                     | Default |
| --------                            | ------- |
| wall_interval                       | 5000    |
| cpu_interval                        | 5000    |
| object_interval                     | 1000    |
| wall_mode_probability               | 0.8     |
| cpu_mode_probability                | 0.1     |
| object_mode_probability             | 0.1     |

| VernierConfig                       | Default |
| --------                            | ------- |
| wall_interval                       | 5000    |
| retained_interval                   | 5000    |
| wall_mode_probability               | 1.0     |
| retained_mode_probability           | 0.0     |
```

Apps do not need have to configure anything if they are happy with the default values.

## Running tests

```
bin/setup && bundle exec rake
```
