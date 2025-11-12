docker-build:
	docker build . \
		--build-arg REACT_APP_BACKEND_URL=https://ucjl.axavier.org/api \
		-t ucjl-frontend

docker-run:
	docker stop ucjl-frontend
	docker rm ucjl-frontend
	docker run \
		--detach \
		--network custom \
		--restart always \
		--name ucjl-frontend \
		ucjl-frontend
