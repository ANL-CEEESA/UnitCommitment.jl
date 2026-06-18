# HTTP Backend

UnitCommitment.jl includes an optional HTTP backend that exposes the solve pipeline as a REST API. This allows web applications, microservices, or other non-Julia clients to submit instances and retrieve solutions over HTTP. Use cases include:

- **Web-based tools** -- Serve a browser UI or dashboard that submits
  instances and polls for results without embedding Julia.
- **Language-agnostic integration** -- Let Python, R, or any HTTP-capable
  client solve unit commitment problems by posting JSON.
- **Batch processing** -- Accept multiple submissions that are queued and
  processed by a pool of distributed workers.

## Usage

```julia
using UnitCommitment, HiGHS, Ipopt, Juniper
using JuMP

ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
highs = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.001)
juniper = optimizer_with_attributes(
    Juniper.Optimizer,
    "nl_solver" => ipopt,
    "mip_solver" => highs,
)

server = UnitCommitment.start_backend(
    "127.0.0.1",
    9000;
    milp_optimizer = highs,
    minlp_optimizer = juniper,
)
wait(server)  # blocks until Ctrl+C, then shuts down
```

The backend automatically selects the appropriate optimizer for each job:
`milp_optimizer` is used by default, and `minlp_optimizer` is used when
the request includes `ACTransmissionExt`.

### Customizing the solve pipeline

By default, the backend uses the same defaults as the core package for
reading instances and solving models. To override:

```julia
server = UnitCommitment.start_backend(
    "127.0.0.1",
    9000;
    milp_optimizer = HiGHS.Optimizer,
    minlp_optimizer = juniper,
    method = UnitCommitment.XavQiuWanThi2019.Method(time_limit = 600.0),
)
```

When `method` is omitted (or set to `nothing`), the backend delegates to
whatever default `UnitCommitment.optimize!` uses internally.

### Extensions

Extensions can be configured per request by embedding an `"extensions"`
array in the submitted instance JSON. Each element is an object with a
`"type"` key (the extension's Julia type) and additional keys for
constructor keyword arguments. Nested extensions follow the same
pattern (recursive objects with their own `"type"` key). When omitted,
`UnitCommitment.read` uses its built-in defaults.

Example:

```json
{
    "extensions": [
        {
            "type": "ThermalExt",
            "pwl_costs": { "type": "KnuOstWat2018.PwlCosts" },
            "ramping": { "type": "MorLatRam2013.Ramping" },
            "slimits": { "type": "MorLatRam2013.StartupShutdownLimits" }
        },
        { "type": "ShiftFactorsTransmissionExt", "isf_cutoff": 0.075 }
    ]
}
```

### Distributed workers

The backend uses `Distributed.jl` to process jobs. If worker processes
are available, jobs are dispatched to them; otherwise everything runs
on the main process. The simplest way to add workers is the `--procs`
flag when launching Julia:

```bash
julia --procs 4 serve.jl
```

Julia automatically loads the project environment on each worker, so
no additional setup is needed inside the script.

## HTTP API

### Submit a job

**`POST /api/submit`**

Submit a gzipped JSON instance. The server decompresses the body,
computes a SHA-256 hash to derive a job ID, saves the input, and enqueues
the job for processing.

**Request:**

| Header | Value |
|---|---|
| `Content-Encoding` | `gzip` |
| `Content-Type` | `application/json` |

The body is the gzip-compressed JSON instance (same format accepted by
`UnitCommitment.read`).

**Response (200):**

```json
{
    "job_id": "a1b2c3d4e5f67890"
}
```

### Poll job status

**`GET /api/jobs/{job_id}/view`**

Poll the status and results of a previously submitted job.

**Response (200):**

```json
{
    "status": "completed",
    "position": null,
    "log": "...",
    "input": { ... },
    "output": { ... }
}
```

**Response fields:**

| Field | Type | Description |
|---|---|---|
| `status` | `String` | `"queued"`, `"processing"`, or `"completed"` |
| `position` | `Int` or `null` | Queue position (1-based) while queued, `null` otherwise |
| `log` | `String` or `null` | Solver log output, available once processing starts |
| `input` | `Object` or `null` | The submitted instance JSON |
| `output` | `Object` or `null` | The solution JSON, available once completed |

## API reference

### `UnitCommitment.start_backend`

```julia
start_backend(
    host::String = "127.0.0.1",
    port::Int = 9000;
    milp_optimizer,
    minlp_optimizer,
    method = nothing,
    jobs_dir::String = mktempdir(),
) -> ServerHandle
```

Start the HTTP backend server.

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `host` | `String` | `"127.0.0.1"` | Address to bind |
| `port` | `Int` | `9000` | Port to listen on |
| `milp_optimizer` | any JuMP optimizer | *(required)* | Optimizer for MILP models (used by default) |
| `minlp_optimizer` | any JuMP optimizer | *(required)* | Optimizer for MINLP models (used when `ACTransmissionExt` is active) |
| `method` | method or `nothing` | `nothing` | Solution method passed to `optimize!`; `nothing` uses the package default |
| `jobs_dir` | `String` | `mktempdir()` | Directory for job artifacts (input, log, solution files) |

**Returns:** a `ServerHandle` used to stop the server.

### `Base.wait(::ServerHandle)`

```julia
wait(handle::ServerHandle) -> Nothing
```

Block until the server shuts down. On `InterruptException` (Ctrl+C),
the server and job processor are stopped automatically. Also handles
the case where the server exits on its own (e.g., network error).

### `UnitCommitment.stop_backend`

```julia
stop_backend(handle::ServerHandle) -> Nothing
```

Stop the HTTP server and shut down the job processor. Idempotent --
safe to call multiple times or after `wait` has already cleaned up.
