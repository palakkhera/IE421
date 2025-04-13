# IE421


<b>Instructions to run sample:</b>

For Windows, open Ubuntu subsystem, then install.
```
wsl --install -d Ubuntu
wsl -d Ubuntu
sudo apt update
sudo apt install verilator
```
For Mac,
```
brew install verilator
```
For Linux,
```
sudo apt update
sudo apt install verilator
```

<b>Instructions to install Verilator:</b>

Clone repo, then
```
cd /IE421/sample
verilator --cc hello.v --exe sim_main.cpp
make -C obj_dir -f Vhello.mk Vhello
./obj_dir/Vhello
```