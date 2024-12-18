<!-- This is a brief version of the Arduino Core for ESP32 documentation (add specific link)
     intended to be displayed on the Docker Hub page: https://hub.docker.com/r/espressif/esp32-arduino-lib-builder.
     When changing this page, please keep the documentation in sync.
     (Keep the differences between Markdown and restructuredText in mind.)
 -->

# ESP-IDF Docker Image

This is a Docker image for the [ESP32 Arduino Lib Builder](https://github.com/espressif/esp32-arduino-lib-builder). It is intended for building the static libraries of ESP-IDF components for use in Arduino projects.

This image contains a copy of the esp32-arduino-lib-builder repository and already include or will obtain all the required tools and dependencies to build the Arduino static libraries.

Currently supported architectures are:
  - `amd64`
  - `arm64`

## Tags

Multiple tags of this image are maintained:

  - `latest`: tracks `master` branch of esp32-arduino-lib-builder
  - `release-vX.Y`: tracks `release/vX.Y` branch of esp32-arduino-lib-builder

## Basic Usage

```bash
docker run --rm -it -e "TERM=xterm-256color" -v <path to arduino-esp32>:/arduino-esp32 espressif/esp32-arduino-lib-builder:release-v5.3
```

The above command explained:

  - `docker run`: Runs a command in a new container.
  - `--rm`: Optional. Automatically removes the container when it exits. Remove this flag if you plan to use the container multiple times.
  - `-i`: Runs the container in interactive mode.
  - `-t`: Allocates a pseudo-TTY.
  - `-e "TERM=xterm-256color"`: Optional. Sets the terminal type to `xterm-256color` to display colors correctly.
  - `-v <path to arduino-esp32>:/arduino-esp32`: Optional. Mounts the Arduino Core for ESP32 repository at `/arduino-esp32` inside the container. Replace `<path to arduino-esp32>` with the path to the repository on the host machine. If not provided, the container will not copy the compiled libraries to the host machine.
  - `espressif/esp32-arduino-lib-builder:release-v5.3`: The Docker image to use.

After running the above command, you will be inside the container and can build the libraries using the user interface.

By default the docker container will run the user interface script. If you want to run a specific command, you can pass it as an argument to the docker run command. For example, to run a terminal inside the container, you can run:

```bash
docker run -it espressif/esp32-arduino-lib-builder:release-v5.3 /bin/bash
```

## Documentation

For more information about this image and the detailed usage instructions, please refer to the [Arduino Core for ESP32 documentation](https://docs.espressif.com/projects/arduino-esp32/en/latest/lib_builder.html#docker-image).
