#!/usr/bin/env bash

function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
        esac
    done
}

rm -rf zig-cache
rm -rf zig-out
zig build docs

yes_or_no "Start local HTTP server hosting the documentation?" \
	&& http-server ./zig-out/docs/ -p 8000 \

