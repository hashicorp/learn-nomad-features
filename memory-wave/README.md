## Building

This project uses a gcc container to build the C code and then creates an
alpine container containing just the binary.

$ docker build . -t wave:v4
$ docker push -t wave:v4
