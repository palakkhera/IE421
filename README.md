# IE421



Instructions to install Verilator:

Instructions to run sample:
For Windows, open Ubuntu subsystem
```
wsl --install -d Ubuntu
wsl -d Ubuntu
```

For Mac,
```
```
```
sudo apt update
sudo apt install verilator
cd /IE421/sample
verilator --cc hello.v --exe sim_main.cpp
make -C obj_dir -f Vhello.mk Vhello
./obj_dir/Vhello
```