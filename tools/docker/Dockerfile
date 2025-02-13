# To Do: Check if it is worth to use espressif/idf as base image (image size will be much bigger)
FROM ubuntu:latest

# switch to root, let the entrypoint drop back to host user
USER root
SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

RUN : \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    bison \
    ccache \
    cmake \
    curl \
    flex \
    git \
    gperf \
    jq \
    libncurses-dev \
    libssl-dev \
    libusb-1.0 \
    ninja-build \
    patch \
    python3 \
    python3-click \
    python3-cryptography \
    python3-future \
    python3-pip \
    python3-pyelftools \
    python3-pyparsing \
    python3-serial \
    python3-setuptools \
    python3-venv \
    wget \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* \
  && :

# To build the image for a branch or a tag of the lib-builder, pass --build-arg LIBBUILDER_CLONE_BRANCH_OR_TAG=name.
# To build the image with a specific commit ID of lib-builder, pass --build-arg LIBBUILDER_CHECKOUT_REF=commit-id.
# It is possibe to combine both, e.g.:
#   LIBBUILDER_CLONE_BRANCH_OR_TAG=release/vX.Y
#   LIBBUILDER_CHECKOUT_REF=<some commit on release/vX.Y branch>.
# Use LIBBUILDER_CLONE_SHALLOW=1 to peform shallow clone (i.e. --depth=1 --shallow-submodules)
# Use LIBBUILDER_CLONE_SHALLOW_DEPTH=X to define the depth if LIBBUILDER_CLONE_SHALLOW is used (i.e. --depth=X)

ARG LIBBUILDER_CLONE_URL=https://github.com/espressif/esp32-arduino-lib-builder
ARG LIBBUILDER_CLONE_BRANCH_OR_TAG=master
ARG LIBBUILDER_CHECKOUT_REF=
ARG LIBBUILDER_CLONE_SHALLOW=
ARG LIBBUILDER_CLONE_SHALLOW_DEPTH=1

ENV LIBBUILDER_PATH=/opt/esp/lib-builder
# Ccache is installed, enable it by default
ENV IDF_CCACHE_ENABLE=1

RUN echo LIBBUILDER_CHECKOUT_REF=$LIBBUILDER_CHECKOUT_REF LIBBUILDER_CLONE_BRANCH_OR_TAG=$LIBBUILDER_CLONE_BRANCH_OR_TAG && \
    git clone --recursive \
      ${LIBBUILDER_CLONE_SHALLOW:+--depth=${LIBBUILDER_CLONE_SHALLOW_DEPTH} --shallow-submodules} \
      ${LIBBUILDER_CLONE_BRANCH_OR_TAG:+-b $LIBBUILDER_CLONE_BRANCH_OR_TAG} \
      $LIBBUILDER_CLONE_URL $LIBBUILDER_PATH && \
    git config --system --add safe.directory $LIBBUILDER_PATH && \
    if [ -n "$LIBBUILDER_CHECKOUT_REF" ]; then \
      cd $LIBBUILDER_PATH && \
      if [ -n "$LIBBUILDER_CLONE_SHALLOW" ]; then \
        git fetch origin --depth=${LIBBUILDER_CLONE_SHALLOW_DEPTH} --recurse-submodules ${LIBBUILDER_CHECKOUT_REF}; \
      fi && \
      git checkout $LIBBUILDER_CHECKOUT_REF && \
      git submodule update --init --recursive; \
    fi && \
    pip3 install --break-system-packages --upgrade -r $LIBBUILDER_PATH/tools/config_editor/requirements.txt

COPY entrypoint.sh $LIBBUILDER_PATH/entrypoint.sh

WORKDIR /opt/esp/lib-builder
ENTRYPOINT [ "/opt/esp/lib-builder/entrypoint.sh" ]
CMD [ "python3", "tools/config_editor/app.py" ]
