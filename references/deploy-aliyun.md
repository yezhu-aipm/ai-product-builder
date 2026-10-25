# 阿里云：从购买到上线

> 面向不写代码的使用者。AI 每次只给一步，让用户截图确认后再继续。

## 1. 选购
| 选项 | 建议 | 说明 |
|---|---|---|
| 产品 | ECS e 实例 2核2G | 个人和小团队够用；**续费同价**。轻量服务器首年便宜，但续费贵 |
| 地域 | 离用户近的，例如华东2（上海） | 不同地域之间内网不通 |
| 镜像 | 操作系统 → **Ubuntu 24.04 64位** | 不选 Windows、不选最新版、不选 UEFI 版 |
| 系统盘 | ESSD Entry 40G | 默认即可 |
| 带宽 | 固定带宽 3M | 加带宽会加钱 |
| 自动续费 | 勾选 | 锁定续费价，可以随时取消 |

## 2. 开通后的三件事
1. **重置实例密码**（用户名 root），改完要重启才生效。密码由用户自己保管，**不要发到对话里**。
2. **安全组 → 入方向 → 手动添加**：端口 80，访问来源 `0.0.0.0/0`。有了域名再加 443。
3. 记下**公网 IP**。

## 3. 连上服务器
- 远程连接选 **Workbench 网页连接**。
- 第一次连接会弹出"服务关联角色"的提示，点确定。
- 免密连接失败时，改用"终端连接 + 密码认证"。
- 切到 **Shell** 模式（不要用 Agent 模式）。
- 在左侧"文件管理"里，对 `root` 文件夹点右键 → 上传文件。

## 4. 安装
```
apt-get update && apt-get install -y unzip && cd /root && unzip -o myapp-release.zip && cd myapp && bash deploy/install.sh
```
- 多行命令粘贴之后，要再按一下回车才会执行。
- 看到 `安装完成。浏览器打开：http://公网IP` 就成功了。
- 中途弹出选择框，问要不要重启服务的，直接按回车选默认。

## 5. 填密钥（不显示、不经过对话）
```
read -s -p "请粘贴 API Key 后按回车: " K && sed -i "s|^LLM_API_KEY=.*|LLM_API_KEY=$K|" /opt/myapp/.env && unset K && systemctl restart myapp && echo " 已保存并重启"
```
- 只粘贴一次，然后按回车。粘贴多了就按 Ctrl+C 取消，重来一次。
- 检查是否填进去了：
  ```
  grep '^LLM_API_KEY=' /opt/myapp/.env | cut -c1-17; grep '^LLM_API_KEY=' /opt/myapp/.env | wc -c
  ```
  如果数字是 13，说明密钥是空的。
- 再跑一次 [连通测试](./model-selection.md#连通测试在服务器上运行)。

## 6. 备案
- 国内服务器用**域名**访问，必须先做 ICP 备案；只用 **IP** 访问不需要备案。
- 已备案域名下的子域名一般不用再备案；新的域名要做"新增网站"。
- ICP 备案通过后，30 天内要做公安备案。

## 7. 升级
```
cd /root && rm -rf myapp && unzip -o myapp-release.zip && cd myapp && bash deploy/install.sh
```
数据（`/opt/myapp/data`）和配置（`.env`）都会保留。

## 8. 排查问题
```
systemctl is-active myapp nginx fail2ban
journalctl -u myapp -n 40 --no-pager
```
页面没更新时，在浏览器里按 Cmd/Ctrl + Shift + R 强制刷新。
