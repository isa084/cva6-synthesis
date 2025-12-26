[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# cva6-synthesis

## Description

This repository contains helpful scripts to synthesize OpenHWGroup CVA6 using open source synthesis tools (e.g. Yosys).

## Setup
First, setup a docker image using the Dockerfile provided.
```
docker build -t Dockerfile # If using default docker
docker buildx build .      # If using docker  buildx
```
Now, run a docker container on this image :
```
docker run -it <docker-image-name>
```
Once inside the container, navigate to cva6-synthesis repository and run the demo program. 
```
cd /install/cva6-synthesis
source setup-env.sh
bash run-yosys.sh cv64a6_imafdc_sv39 cmos
```
This will synthesize cv64a6\_imafdc\_sv39 (a hardware configuration of OpenHWGroup's CVA6), using yosys and CMOS tech library.

Alternately, for nangate45, use :
```
bash run-yosys.sh cv64a6_imafdc_sv39 nangate45
```  

## License

The content of this repository is licensed under the permissive **MIT License**.

You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the software. For the full license text, please see the [LICENSE](LICENSE) file.

