HARchiver
===================

Universal lightweight proxy for apianalytics.com that was made to be portable, fast and transparent.

## Quick Start

First get your [API analytics](http://www.apianalytics.com) service token and [install HARchiver](#install).

Start HARchiver on port 15000 with your API analytics service token:

```bash
./harchiver 15000 api_analytics_token
```

Now you can send requests through the HARchiver using the `Host` header:

```bash
curl -H "Host: www.mocky.io" http://127.0.0.1:15000/v2/
```

That's it, your data is now available on [apianalytics.com](http://www.apianalytics.com)!

## Usage

`harchiver PORT OPTIONAL_SERVICE_TOKEN`

Without `OPTIONAL_SERVICE_TOKEN` the HTTP header `Service-Token` must be set on every request.

##### Optional Flags

`-c NB` to change the maximum number of concurrent requests. The default is 300.

`-debug` to output the generated data on-the-fly.

`-https PORT` to add HTTPS support. The files `key.cert` and `cert.pem` need to be in the same directory as harchiver.

`-t TIMEOUT` to change the default timeout for the remote server to respond. The default is 6 seconds.

`-version` for the version number.

`-help` for usage instructions.

## Install

#### Linux

```bash
wget https://github.com/Mashape/harchiver/releases/download/v1.2.0/harchiver.tar.gz
tar xzvf harchiver.tar.gz
cd release
./harchiver
```

If the program reports a GLIBC error on startup, please [open a Github Issue](https://github.com/APIAnalytics/HARchiver/issues).

#### Docker

##### HTTP only

The only thing needed is to create a container with the correct port forwarding and [command-line options](#usage) from the image.

```bash
# Download the image
sudo docker pull mashape/harchiver

# Then make a container from it
sudo docker run -p 15000:15000 --name="harchiver_http" mashape/harchiver
# or with some options:
sudo docker run -p 15000:15000 --name="harchiver_http" mashape/harchiver /release/harchiver 15000 OPTIONAL_SERVICE_TOKEN
```

There's now a container named `harchiver_http` that can be started easily with `sudo docker start harchiver_http`. That container can be removed and recreated from the `mashape/harchiver` image easily to change the [command-line options](#usage).

##### With HTTPS

The certificate and key must be copied into a new image based on the `mashape/harchiver` image.

```bash
# Download the image
sudo docker pull mashape/harchiver

# Then make a basic container
sudo docker run -p 15000:15000 --name="harchiver_http" mashape/harchiver

# Let it run and switch to a new terminal window
# Remember that the certificate and key MUST be named cert.pem and key.pem
# Copy the certificate and the key into the container
sudo docker exec -i harchiver_http bash -c 'cat > /key.pem' < key.pem
sudo docker exec -i harchiver_http bash -c 'cat > /cert.pem' < cert.pem

# Stop the container
sudo docker kill harchiver_http

# Save it as a new image
sudo docker commit -m "Added https support" harchiver_http harchiver_image_https

# Create a container from it
sudo docker run -p 15000:15000 -p 15001:15001 --name="harchiver_https" harchiver_image_https /release/harchiver 15000 -https 15001 OPTIONAL_SERVICE_TOKEN
```

## Compiling

This is seriously not recommended, but here are the instructions to compile it from scratch. It's not for the faint of heart.

####1- Acquire OPAM

Check if your Linux distribution offers OPAM 1.2 in `yum` or `apt-get`. If it does, install it and go to step 2. Otherwise, check if your distribution offers OCaml 4. If it does, install it and go to Step 1.2, if it doesn't, go to Step 1.1.

####1.1- Install OCaml 4.02.0 from source

`git clone` https://github.com/ocaml/ocaml. Checkout version 4.02.0 and follow the instructions in the INSTALL file. Go to Step 1.2.

####1.2- Install OPAM 1.2.0 from source

`git clone` https://github.com/ocaml/opam. Checkout version 1.2.0 and follow the instructions in the README.md file carefully. You'll have to run `make ext-lib` when instructed to. Go to Step 2.

####2- Install an OPAM-managed version of OCaml 4.02.0

This is necessary for some of the dependencies. Run `opam init`, then `opam switch 4.02.0`.

####3- Install ZMQ

Go to http://zeromq.org/intro:get-the-software and download the latest 4.0.x release POSIX tarball. Then scroll and follow the instructions in the `To build on UNIX-like systems` section.

####4- Install the dependencies for Harchiver.

`apt-get install libssl-dev zlib1g-dev` (or `yum`).

Run `opam install core lwt ssl cohttp lwt-zmq atdgen dns utop`. If it fails, try reinstalling ZMQ and make sure that you followed all the instructions carefully and have all the dependencies listed on the ZMQ page, then try again.

####5- Build it

You are now ready to compile the program. Run `./build.sh` in the Harchiver directory. If everything went fine until this point you'll see a `harchiver` file in the directory. Congrats!

## Libraries

This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit (http://www.openssl.org/).

This project ships with a compiled library of ZeroMQ, more specifically, the libzmq.so.4 file. As required by the LGPL license, you have been made aware that you are free to download and replace it with your own from the [official website](http://zeromq.org/intro:get-the-software).
