#!/bin/zsh
echo "Zsh Startup Benchmark"
echo "===================="
echo
echo "10 runs average:"
time (repeat 10 { zsh -i -c exit })
echo
echo "With profiling:"
ZPROF=true zsh -i -c exit

