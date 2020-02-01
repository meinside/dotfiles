#!/usr/bin/env bash

# install_tensorflow.sh
# 
# install Tensorflow (https://www.tensorflow.org/install)
# 
# created on : 2018.08.09.
# last update: 2020.02.01.
# 
# by meinside@gmail.com

function install_linux {
	sudo apt-get install python3-pip libatlas-base-dev && \
		pip3 install --upgrade --user tensorflow && \
		python3 -c "import tensorflow as tf;print(\"Tensorflow version\", tf.__version__, \"installed.\")"
}

case "$OSTYPE" in
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

