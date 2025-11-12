docker-build:
	docker build . -t ucjl-backend

docker-run:
	docker stop ucjl-backend
	docker rm ucjl-backend
	docker run \
		--restart always \
		--detach \
		--network custom \
		--name ucjl-backend \
		--volume ucjl_data:/app/Backend/jobs \
		--memory 16g \
		--cpus 4 \
		ucjl-backend

test:
	clear; julia --threads 1 --procs 1 --project=test -e "using BackendT; runtests()"

run:
	julia --procs 1 --project=. startup.jl

.PHONY: test
