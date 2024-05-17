FROM nvidia/opengl:1.0-glvnd-runtime-ubuntu20.04

RUN apt-get update \
    && apt-get install -q -y --no-install-recommends \
    dirmngr \
    sudo \
    locales \
    gnupg2 \
    lsb-release \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && \
    apt-get install -q -y --no-install-recommends tzdata \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# setup sources.list
RUN echo "deb http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" > /etc/apt/sources.list.d/ros2-latest.list

# setup keys
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# Set env variables
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    XVFB_WHD="1920x1080x24"\
    LIBGL_ALWAYS_SOFTWARE="1"

RUN apt-get update
RUN apt install -y software-properties-common python3-pip
RUN pip3 install --upgrade pip
RUN pip3 install --user pygame numpy
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 1AF1527DE64CB8D9 \
  && add-apt-repository "deb [arch=amd64] http://dist.carla.org/carla $(lsb_release -sc) main" \
  && apt-get update \
  && apt-get install -y carla-simulator=0.9.13 libomp-dev

# ROS2
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    git \
    vim \
    wget \
    bash-completion \
    build-essential \
    tree \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    python3-argcomplete \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
RUN colcon mixin add default \
    https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon mixin update && \
    colcon metadata add default \
    https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update
ENV ROS_DISTRO=foxy
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-desktop \
    ros-${ROS_DISTRO}-gazebo-ros \
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# user
RUN useradd -m carla
COPY --chown=carla:carla . /home/carla

# ros-bridge
RUN git clone --recurse-submodules https://github.com/carla-simulator/ros-bridge.git /home/carla/ros-bridge
WORKDIR /home/carla/ros-bridge
RUN rosdep init
RUN rosdep update
RUN ./install_dependencies.sh
RUN /bin/bash -c 'source /opt/ros/${ROS_DISTRO}/setup.bash; colcon build'
RUN apt install -y ros-foxy-derived-object-msgs
ENV CARLA_ROOT=/home/carla/carla
ENV PYTHONPATH=$PYTHONPATH:$CARLA_ROOT/PythonAPI/carla/dist/carla-0.9.13-py3.8-linux-x86_64.egg:$CARLA_ROOT/PythonAPI/carla
ENV NVIDIA_VISIBLE_DEVICES ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics

USER carla
WORKDIR /opt/carla-simulator

# setup entrypoint
COPY ./ros_entrypoint.sh /

