#!/usr/bin/env bash
# 模板来自实战项目，用之前把 myapp 换成你的项目名，并按你的技术栈调整第 3、4 步（依赖安装）和 ExecStart。
# 一键安装（Ubuntu 22.04 / 24.04，阿里云、腾讯云的轻量服务器都可以）
# 用法：把整个项目文件夹上传到服务器，进入文件夹后执行  sudo bash deploy/install.sh
# 升级：上传新的安装包，解压覆盖后再执行一次同样的命令。账号、报告和 .env 配置都会保留。
set -euo pipefail
APP=/opt/myapp
PIP_INDEX=${PIP_INDEX:-https://mirrors.aliyun.com/pypi/simple}
PLAYWRIGHT_DOWNLOAD_HOST=${PLAYWRIGHT_DOWNLOAD_HOST:-https://cdn.npmmirror.com/binaries/playwright}
SRC=$(cd "$(dirname "$0")/.." && pwd)

echo "==> 0/6 检查内存（小于 3G 时自动加 2G 虚拟内存，防止生成 PDF 时内存不够）"
MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
if [ "$MEM_MB" -lt 3000 ] && ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "已添加 2G 虚拟内存"
fi

echo "==> 1/6 安装系统依赖（Python、中文字体、Nginx）"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip fonts-noto-cjk fonts-dejavu-core fontconfig nginx rsync sqlite3 fail2ban cron

echo "==> 2/6 复制程序到 $APP"
mkdir -p $APP/data
rsync -a --delete --exclude data --exclude .env --exclude venv --exclude browsers --exclude 'frontend/node_modules' "$SRC/" $APP/
if [ ! -f $APP/frontend/dist/index.html ]; then
  echo "没有找到打包好的前端（frontend/dist）。请用发布包里的文件夹，或先在电脑上执行 npm run build。"; exit 1
fi

echo "==> 3/6 安装 Python 依赖"
python3 -m venv $APP/venv
$APP/venv/bin/pip install -i $PIP_INDEX --upgrade pip
$APP/venv/bin/pip install -i $PIP_INDEX -r $APP/backend/requirements.txt

echo "==> 4/6 安装生成 PDF 用的 Chromium"
PLAYWRIGHT_BROWSERS_PATH=$APP/browsers PLAYWRIGHT_DOWNLOAD_HOST=$PLAYWRIGHT_DOWNLOAD_HOST $APP/venv/bin/python -m playwright install --with-deps chromium

echo "==> 5/6 配置文件"
if [ ! -f $APP/.env ]; then
  cp $APP/.env.example $APP/.env; echo "已生成 $APP/.env，稍后请填入大模型 Key"
  if [ "$MEM_MB" -lt 3000 ]; then sed -i 's/^WORKERS=.*/WORKERS=1/' $APP/.env; echo "内存较小，已设为一次只处理一个任务"; fi
fi
# 升级时补上新版本才有的配置项（已有的不动）
grep -q '^INVITE_CODE=' $APP/.env || printf '\n# 注册邀请码（管理员也可以在网站「设置 → 管理员」里修改）\nINVITE_CODE=change-me-2026\n' >> $APP/.env
id -u myapp >/dev/null 2>&1 || useradd --system --home $APP --shell /usr/sbin/nologin myapp
chown -R myapp:myapp $APP/data $APP/browsers

echo "==> 6/6 注册为系统服务（开机自动启动）"
cat > /etc/systemd/system/myapp.service <<UNIT
[Unit]
Description=我的应用
After=network.target

[Service]
User=myapp
WorkingDirectory=$APP/backend
EnvironmentFile=$APP/.env
Environment=DATA_DIR=$APP/data FRONTEND_DIR=$APP/frontend/dist PLAYWRIGHT_BROWSERS_PATH=$APP/browsers TZ=Asia/Shanghai
ExecStart=$APP/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --proxy-headers
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable myapp
systemctl restart myapp
sleep 3
if curl -fs http://127.0.0.1:8000/api/health >/dev/null; then echo "服务已启动。"; else echo "服务没有起来，用 journalctl -u myapp -n 50 查看原因"; fi

echo "==> 配置网页入口（先用公网 IP 访问，有域名后再换成 deploy/nginx.conf）"
# 第一次安装，或之前用的就是 IP 访问版：更新为最新的 IP 访问配置；已换成域名配置的不动
if [ ! -f /etc/nginx/conf.d/myapp.conf ] || grep -q 'default_server' /etc/nginx/conf.d/myapp.conf; then
  rm -f /etc/nginx/sites-enabled/default
  cp $APP/deploy/nginx-ip.conf /etc/nginx/conf.d/myapp.conf
fi
nginx -t && systemctl reload nginx

echo "==> 防暴力破解：有人反复猜服务器登录密码，自动封禁他的 IP 1 小时"
cat > /etc/fail2ban/jail.d/myapp.local <<'JAIL'
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
# 阿里云网页远程连接（Workbench）走的是内部地址，不封
ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10
JAIL
systemctl enable --now fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban || true

echo "==> 每日自动备份（凌晨 3:30，保留 7 天，位置 /var/backups/myapp）"
chmod +x $APP/deploy/backup.sh
echo '30 3 * * * root /opt/myapp/deploy/backup.sh >/var/log/myapp-backup.log 2>&1' > /etc/cron.d/myapp-backup
$APP/deploy/backup.sh || echo "第一次备份没有成功，不影响网站使用"

IP=$(curl -fs --max-time 3 http://100.100.100.200/latest/meta-data/eipv4 || curl -fs --max-time 5 https://ifconfig.me || echo "你的公网IP")
echo
echo "安装完成。浏览器打开： http://$IP"
echo "接下来：编辑 $APP/.env，填入 LLM_BASE_URL 和 LLM_API_KEY，然后执行 sudo systemctl restart myapp"
