#!/bin/bash

set -e

OPENPLC_DIR="$PWD"
VENV_DIR="$OPENPLC_DIR/.venv"
SWAP_FILE="$OPENPLC_DIR/swapfile"

function fail {
    echo "$*"
    echo "OpenPLC was NOT installed!"
    exit 1
}

function install_deps {
    echo "[APT DEPENDENCIES]"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -yq \
        build-essential pkg-config bison flex autoconf \
        automake libtool make git sqlite3 cmake curl \
        libgtk-3-dev libxml2-dev libxslt-dev \
        python3 python3-venv python3-dev
}

function install_py_deps {
    echo "[PYTHON DEPENDENCIES]"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/python3" -m pip install --upgrade pip
    "$VENV_DIR/bin/python3" -m pip install \
        flask==2.3.3 werkzeug==2.3.7 flask-login==0.6.2 \
        pyserial pymodbus==2.5.3 \
        zeroconf pypubsub pyro5 attrdict3 lxml==4.6.2 wxPython==4.2.0
}

function install_matiec {
    echo "[MATIEC COMPILER]"
    cd "$OPENPLC_DIR/utils/matiec_src"
    autoreconf -i
    ./configure
    make
    cp ./iec2c "$OPENPLC_DIR/webserver/" || fail "Error compiling MatIEC"
    cd "$OPENPLC_DIR"
}

function install_st_optimizer {
    echo "[ST OPTIMIZER]"
    cd "$OPENPLC_DIR/utils/st_optimizer_src"
    g++ st_optimizer.cpp -o "$OPENPLC_DIR/webserver/st_optimizer" || fail "Error compiling ST Optimizer"
    cd "$OPENPLC_DIR"
}

function install_glue_generator {
    echo "[GLUE GENERATOR]"
    cd "$OPENPLC_DIR/utils/glue_generator_src"
    g++ -std=c++11 glue_generator.cpp -o "$OPENPLC_DIR/webserver/core/glue_generator" || fail "Error compiling Glue Generator"
    cd "$OPENPLC_DIR"
}

function install_libmodbus {
    echo "[LIBMODBUS]"
    cd "$OPENPLC_DIR/utils/libmodbus_src"
    ./autogen.sh
    ./configure
    make install || fail "Error installing Libmodbus"
    ldconfig
    cd "$OPENPLC_DIR"
}

function install_libsnap7 {
    echo "[LIBSNAP7]"
    cd "$OPENPLC_DIR/utils/snap7_src/build/linux"
    make clean
    make install || fail "Error installing Libsnap7"
    cd "$OPENPLC_DIR"
}

function finalize_install {
    echo "[FINALIZING]"
    cd "$OPENPLC_DIR/webserver/scripts"
    ./change_hardware_layer.sh blank_linux
    ./compile_program.sh blank_program.st

    cat > "$OPENPLC_DIR/start_openplc.sh" <<EOF
#!/bin/bash
cd "$OPENPLC_DIR/webserver"
"$OPENPLC_DIR/.venv/bin/python3" webserver.py
EOF

    chmod +x "$OPENPLC_DIR/start_openplc.sh"
}

# --- Execute install steps ---
install_deps
install_py_deps
install_matiec
install_st_optimizer
install_glue_generator
install_libmodbus
install_libsnap7
finalize_install
