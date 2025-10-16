# sing-box脚本

这个 Bash 脚本可以帮助你在 debian 系统快速部署 sing-box 代理服务器。

### 通过 curl 一键脚本自定义安装
自定义端口参数如：AL_PORTS=8443-8445 (也可用 AL_PORTS=8443,8444,8445 来表达) RE_PORT=443 (此为reality端口，注意端口占用问题) AL_DOMAIN=my.domain.com (服务器解析的域名) RE_SNI=www.java.com (此为reality协议证书地址)、API_TOKEN=K8Xo_z-Seyq0iyQ7icsio0t53FSRoAFohdYr9HFY（此为acme通过CF api方式申请证书），使用时请自行定义此参数！
```bash
AL_PORTS=8443-8445 RE_PORT=443 AL_DOMAIN=my.domain.com RE_SNI=www.java.com API_TOKEN=K8Xo_z-Seyq0iyQ7icsio0t58FSRoAFohiYr9HFY bash <(curl -fsSL https://raw.githubusercontent.com/hide3110/sb-debian/main/install.sh)
```
### 安装指定版本号
可以在脚本bash最后添加sing-box版本号，如1.11.4
```
AL_PORTS=8443-8445 RE_PORT=443 AL_DOMAIN=my.domain.com RE_SNI=www.java.com API_TOKEN=K8Xo_z-Seyq0iyQ7icsio0t58FSRoAFohiYr9HFY bash -s -- 1.11.4 < <(curl -fsSL https://raw.githubusercontent.com/hide3110/sb-debian/main/install.sh)
```

## 详细说明

- 脚本使用的acme申请证书
- 默认安装sing-box 1.11.15版本，可自定版本安装，需要自行修改配置文件
- 此脚本仅安装了ss、trojan、vless-wss和reality四个协议


