#!/usr/bin/env bash
# pkg_manager - ติดตั้ง package อัตโนมัติ ตรวจ environment ให้เอง
# ดูวิธีใช้เต็ม ๆ ใน README.md
#
# Usage:
#   pkg_manager [-c|--check-only] <package_name> [binary_name] [overrides]
#
#   -c, --check-only   แค่เช็คว่าติดตั้งแล้วหรือยัง ไม่ลง ไม่มี side effect
#                       (ใช้แทน `command -v "$cmd"` ตรง ๆ ได้ ปลอดภัยกว่าเวลาใช้เป็น guard)
#   package_name        ชื่อ package ที่ใช้ default กับทุก package manager
#   binary_name          (optional) ถ้าชื่อ binary ที่รันจริงไม่ตรงกับชื่อ package
#                        เช่น package "ripgrep" แต่ binary คือ "rg"
#                        ไม่ใส่ = ใช้ชื่อเดียวกับ package_name
#   overrides            (optional) ชื่อ package เฉพาะ manager ที่ชื่อไม่ตรงกับ default
#                        รูปแบบ: "key=value,key=value" คีย์ที่รองรับ: apk, pacman, winget
#                        เช่น pkg_manager micro micro "winget=zyedidia.Micro"
#
# Environment ($JOE_ENV): TERMUX, WSL, ACODEX, GIT-BASH  (+ autodetect fallback)
# GIT-BASH: ลอง pacman ก่อน (ถ้ามี) -> fallback ไป winget ผ่าน powershell.exe

pkg_manager() {
    local check_only=0

    # ---- parse leading flag ----
    while [[ "$1" == -* ]]; do
        case "$1" in
            -c|--check-only) check_only=1; shift ;;
            *)
                echo "[pkg_manager] ไม่รู้จัก flag '$1'" >&2
                return 1
                ;;
        esac
    done

    local pkg="$1"
    local bin="${2:-}"
    local overrides="$3"

    if [[ -z "$bin" ]]; then
        case "$pkg" in
            openssh|openssh-client|openssh-server) bin="ssh" ;;
            ncurses-utils|ncurses-bin|ncurses)     bin="tput" ;;
            *)                                    bin="$pkg" ;;
        esac
    fi
    local overrides="$3"

    if [[ -z "$pkg" ]]; then
        echo "Usage: pkg_manager [-c|--check-only] <package_name> [binary_name] [overrides]" >&2
        return 1
    fi

    # ---- parse overrides "key=value,key=value" ----
    local apk_pkg="$pkg" pacman_pkg="$pkg" winget_pkg="$pkg"
    if [[ -n "$overrides" ]]; then
        local IFS=','
        local pair
        for pair in $overrides; do
            local key="${pair%%=*}"
            local val="${pair#*=}"
            case "$key" in
                apk)    apk_pkg="$val" ;;
                pacman) pacman_pkg="$val" ;;
                winget) winget_pkg="$val" ;;
            esac
        done
    fi

    # 1) เช็คว่าติดตั้งแล้วหรือยัง (เช็คจาก binary name เผื่อชื่อไม่ตรงกับ package)
    if command -v "$bin" >/dev/null 2>&1; then
        echo "[pkg_manager] '$pkg' ติดตั้งอยู่แล้ว (พบ binary '$bin') ✅"
        return 0
    fi

    # --check-only: ไม่เจอ ก็จบแค่นี้ ไม่มี side effect ใด ๆ
    if [[ "$check_only" -eq 1 ]]; then
        echo "[pkg_manager] '$pkg' ยังไม่ได้ติดตั้ง (check-only, ไม่ได้ลงให้)" >&2
        return 1
    fi

    # 2) ตรวจจับ environment: ใช้ $JOE_ENV ก่อนถ้ามี ไม่งั้น autodetect
    local env="$JOE_ENV"
    if [[ -z "$env" ]]; then
        if [[ -n "$TERMUX_VERSION" || "$PREFIX" == *"com.termux"* ]]; then
            env="TERMUX"
        elif grep -qi microsoft /proc/version 2>/dev/null; then
            env="WSL"
        elif [[ -n "$MSYSTEM" ]] || [[ "$OSTYPE" == "msys" ]]; then
            env="GIT-BASH"
        elif command -v apk >/dev/null 2>&1; then
            env="ACODEX"
        else
            env="LINUX"
        fi
    fi

    echo "[pkg_manager] Environment: $env | กำลังติดตั้ง '$pkg' ..."

    case "$env" in
        TERMUX|MUMU)
            local termux_pkg="$pkg"
            [[ "$pkg" == "openssl" ]] && termux_pkg="openssl-tool"
            pkg install -y "$termux_pkg"
            ;;
        WSL)
            sudo apt update && sudo apt upgrade -y && sudo apt install -y "$pkg"
            ;;
        ACODEX)
            apk update && apk add "$apk_pkg"
            ;;
        GIT-BASH)
            if command -v pacman >/dev/null 2>&1; then
                pacman -Syu --noconfirm "$pacman_pkg"
            elif command -v powershell.exe >/dev/null 2>&1; then
                powershell.exe -NoProfile -Command \
                    "winget install --id $winget_pkg -e --accept-source-agreements --accept-package-agreements"
            else
                echo "[pkg_manager] ไม่พบ pacman หรือ powershell.exe บน GIT-BASH นี้ ติดตั้งเองนะ" >&2
                return 1
            fi
            ;;
        LINUX)
            if [[ "$EUID" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y "$pkg"
            else
                apt update && apt install -y "$pkg"
            fi
            ;;
        *)
            echo "[pkg_manager] ไม่รู้จัก \$JOE_ENV='$env'" >&2
            return 1
            ;;
    esac

    # 3) ยืนยันผล
    if command -v "$bin" >/dev/null 2>&1; then
        echo "[pkg_manager] '$pkg' ติดตั้งสำเร็จ ✅"
    else
        echo "[pkg_manager] ติดตั้ง '$pkg' ไม่สำเร็จ ❌ (เช็คชื่อ package บน environment นี้อีกที)" >&2
        return 1
    fi
}
pkg_(){
    pkg_manager "$@" || return 1
}
