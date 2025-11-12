# Use official Julia image as base
FROM julia:1.11
WORKDIR /app

# Install project & dependencies
COPY Project.toml /app/Backend/
COPY src /app/Backend/src
RUN julia --project=. -e 'using Pkg; Pkg.develop(path="Backend"); Pkg.add("HiGHS"); Pkg.add("JuMP"); Pkg.precompile()'
COPY startup.jl ./

# Set timezone to Chicago
ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set default environment variables
ENV UCJL_HOST="0.0.0.0"
ENV UCJL_PORT="9000"

# Run the server
CMD ["julia", "--threads", "1", "--procs", "4", "--project=.", "startup.jl"]
