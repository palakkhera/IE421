# IE421

Instructions to run sample:
- Install and run verilator.
-- Open Linux subsystem (if on Windows)
```
sudo apt update
sudo apt install verilator
cd /IE421/src-renameme
verilator --cc hello.v --exe sim_main.cpp
make -C obj_dir -f Vhello.mk Vhello
./obj_dir/Vhello
```