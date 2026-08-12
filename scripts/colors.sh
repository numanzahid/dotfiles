#!/usr/bin/env bash

echo "TERM=$TERM"
echo "colors=$(tput colors 2>/dev/null || echo unknown)"
echo

echo "256-color background table"
for i in $(seq 0 255); do
  printf "\033[48;5;%sm %3s \033[0m" "$i" "$i"
  if [ $(( (i + 1) % 16 )) -eq 0 ]; then
    printf "\n"
  fi
done

echo
echo
echo "256-color foreground table"
for i in $(seq 0 255); do
  printf "\033[38;5;%sm %3s \033[0m" "$i" "$i"
  if [ $(( (i + 1) % 16 )) -eq 0 ]; then
    printf "\n"
  fi
done

echo
echo
echo "Truecolor red gradient"
for i in $(seq 0 255); do
  printf "\033[48;2;%s;0;0m %3s \033[0m" "$i" "$i"
  if [ $(( (i + 1) % 8 )) -eq 0 ]; then printf "\n"; fi
done

echo
echo "Truecolor green gradient"
for i in $(seq 0 255); do
  printf "\033[48;2;0;%s;0m %3s \033[0m" "$i" "$i"
  if [ $(( (i + 1) % 8 )) -eq 0 ]; then printf "\n"; fi
done

echo
echo "Truecolor blue gradient"
for i in $(seq 0 255); do
  printf "\033[48;2;0;0;%sm %3s \033[0m" "$i" "$i"
  if [ $(( (i + 1) % 8 )) -eq 0 ]; then printf "\n"; fi
done
