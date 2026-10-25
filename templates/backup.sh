#!/usr/bin/env bash
# 每日备份：账号数据库 + 上传的材料和生成的报告，保留最近 7 天。由 /etc/cron.d/myapp-backup 每天凌晨 3:30 调用。
set -euo pipefail
APP=/opt/myapp; DST=/var/backups/myapp; KEEP=7
mkdir -p $DST; TS=$(date +%Y%m%d-%H%M); TMP=$(mktemp -d)
sqlite3 $APP/data/app.db ".backup '$TMP/app-backup.db'"      # 运行中也能安全备份；恢复时改回 app.db
tar -czf $DST/myapp-$TS.tar.gz -C $APP/data --exclude='app.db' --exclude='app.db-*' . -C $TMP app-backup.db
rm -rf $TMP
ls -1t $DST/myapp-*.tar.gz | tail -n +$((KEEP+1)) | xargs -r rm -f
echo "备份完成：$DST/myapp-$TS.tar.gz"
