#!/bin/bash

is_ubuntu() {
    grep -q "Ubuntu" /etc/os-release
}

is_arch() {
    grep -q "Manjaro" /etc/os-release
}
