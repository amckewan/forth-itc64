#!/bin/sh

#FORTH = gforth
#FORTH = ../forth
#FORTH = gforth-fast -e "warnings off"
TIME='time -f %U'

bench() {
	echo testing $1
	echo sieve
	$TIME $1 bench/sieve.f -e "main bye"
	echo bubble-sort
	$TIME $1 bench/bubble-sort.f -e "main bye"
	echo fib
	$TIME $1 bench/fib.f -e "main bye"
	echo matrix-mult
	$TIME $1 bench/matrix-mult.f -e "main bye"
	echo mm-rtcg
	$TIME $1 bench/mm-rtcg.f -e "main bye"
}

bench "gforth -m32M"
bench "gforth-fast -m32M"
bench "./fo -m32M rth"
