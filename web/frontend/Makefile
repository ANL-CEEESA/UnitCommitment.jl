docker-build:
	docker build . -t ucjl-frontend

docker-run:
	docker run -e REACT_APP_BACKEND_URL=http://localhost:9000/api --publish 3000:3000 --rm -it ucjl-frontend