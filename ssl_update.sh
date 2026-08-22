#!/usr/bin/env bash
# v2ray TLS 证书续期 + 安装 + nginx reload
# 由 cron 每周调用; 证书剩余 <30 天才真正续期(短暂停 nginx 让出 80 端口给 standalone 验证)
# 前置条件: 已用 acme.sh --install-cert 固化证书安装路径与 --reloadcmd,
#           续期成功后会自动安装证书并 reload nginx (双保险, 本脚本挂了 acme.sh cron 也能兜底)
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

# ====== 按机器修改这里: 域名:已安装证书全链路径 ======
DOMAINS_CERTS=(
    "example.com:/data/v2ray.crt"
    # 多域名示例 (证书直接放 acme.sh 目录, nginx 直接引用):
    # "example2.com:/root/.acme.sh/example2.com_ecc/fullchain.cer"
)
# ====================================================

need=0
for pair in "${DOMAINS_CERTS[@]}"; do
    d="${pair%%:*}"
    cert="${pair#*:}"
    exp=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
    if [ -z "$exp" ]; then
        echo "[$d] 读取证书失败: $cert"
        need=1
        continue
    fi
    remain=$(( ($(date -d "$exp" +%s) - $(date +%s)) / 86400 ))
    echo "[$d] 剩余 ${remain} 天"
    [ "$remain" -lt 30 ] && need=1
done

if [ "$need" = "1" ]; then
    echo "证书即将到期, 开始续期..."
    systemctl stop nginx
    sleep 1
    /root/.acme.sh/acme.sh --cron --home /root/.acme.sh --force
    sleep 1
    systemctl start nginx
    echo "续期完成, nginx 已重启"
else
    echo "证书充足, 跳过续期"
fi
