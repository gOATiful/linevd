docker run --shm-size=4gb --gpus=all --mount type=bind,src=.,dst=/linevd -it --entrypoint bash linevd:latest
