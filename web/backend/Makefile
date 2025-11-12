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
