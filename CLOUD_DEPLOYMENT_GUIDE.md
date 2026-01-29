# Chat LangChain 云服务器部署指南

本指南将帮助你在自己的云服务器（如阿里云、腾讯云、AWS 等）上部署完整的 Chat LangChain 项目。

---

## 📋 前置要求

### 服务器配置
- **操作系统**：Ubuntu 20.04 / 22.04 或 CentOS 7+
- **最低配置**：2核 CPU，4GB 内存，20GB 硬盘
- **推荐配置**：4核 CPU，8GB 内存，40GB 硬盘
- **网络**：公网 IP，开放端口 80、443、3000、8080

### 域名（可选但推荐）
- 如果有域名，可以配置 HTTPS 和友好的访问地址
- 需要将域名 A 记录指向服务器公网 IP

---

## 🚀 快速部署（推荐）

### 方式一：使用自动化脚本

1. **登录服务器**
```bash
ssh root@your-server-ip
```

2. **下载并运行部署脚本**
```bash
# 下载部署脚本
wget https://raw.githubusercontent.com/huhurich/chat-langchain-study2/main/deploy.sh

# 或使用 curl
curl -O https://raw.githubusercontent.com/huhurich/chat-langchain-study2/main/deploy.sh

# 添加执行权限
chmod +x deploy.sh

# 运行部署脚本
./deploy.sh
```

3. **按提示输入配置信息**
- 硅基流动 API Key
- Weaviate URL 和 API Key
- Supabase 数据库连接字符串
- LangSmith API Key（可选）

4. **等待部署完成**（约 10-15 分钟）

5. **访问网站**
- 前端：`http://your-server-ip:3000`
- 后端 API：`http://your-server-ip:8080`

---

## 📖 手动部署步骤

如果自动化脚本遇到问题，可以按照以下步骤手动部署。

### 第一步：安装系统依赖

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y git curl wget vim build-essential

# 安装 Python 3.11
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev

# 安装 Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 安装 Poetry
curl -sSL https://install.python-poetry.org | python3.11 -
export PATH="/root/.local/bin:$PATH"
echo 'export PATH="/root/.local/bin:$PATH"' >> ~/.bashrc

# 安装 Yarn
npm install -g yarn

# 安装 Nginx（用于反向代理）
sudo apt install -y nginx

# 安装 PM2（用于进程管理）
npm install -g pm2
```

### 第二步：克隆项目

```bash
# 进入工作目录
cd /opt

# 克隆项目
git clone https://github.com/huhurich/chat-langchain-study2.git
cd chat-langchain-study2
```

### 第三步：配置环境变量

```bash
# 创建环境变量文件
cat > .env << 'EOF'
# 硅基流动 API
OPENAI_API_KEY=your-siliconflow-api-key
OPENAI_API_BASE=https://api.siliconflow.cn/v1

# Weaviate 配置
WEAVIATE_URL=https://your-weaviate-url
WEAVIATE_API_KEY=your-weaviate-api-key

# Supabase 数据库
RECORD_MANAGER_DB_URL=postgresql://user:password@host:port/database

# LangSmith（可选）
LANGCHAIN_TRACING_V2=true
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
LANGCHAIN_API_KEY=your-langsmith-api-key
LANGCHAIN_PROJECT=chat-langchain-study
EOF

# 编辑环境变量，填入实际值
vim .env
```

### 第四步：安装后端依赖

```bash
# 进入项目目录
cd /opt/chat-langchain-study2

# 使用 Poetry 安装依赖
poetry install

# 降级 weaviate-client（如果需要）
poetry run pip install weaviate-client==3.25.3
```

### 第五步：导入数据到向量数据库

```bash
# 加载环境变量
export $(cat .env | xargs)

# 运行数据导入脚本
poetry run python backend/ingest.py

# 等待导入完成（可能需要几分钟）
```

### 第六步：安装前端依赖

```bash
# 进入前端目录
cd /opt/chat-langchain-study2/frontend

# 安装依赖
yarn install

# 创建前端环境变量
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_BASE_URL=http://your-server-ip:8080
EOF

# 如果有域名，可以使用域名
# NEXT_PUBLIC_API_BASE_URL=https://api.yourdomain.com

# 构建前端
yarn build
```

### 第七步：使用 PM2 启动服务

```bash
# 创建 PM2 配置文件
cat > /opt/chat-langchain-study2/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'chat-langchain-backend',
      cwd: '/opt/chat-langchain-study2',
      script: '/root/.local/bin/poetry',
      args: 'run uvicorn --app-dir=backend main:app --host 0.0.0.0 --port 8080',
      env: {
        ...require('dotenv').config({ path: '/opt/chat-langchain-study2/.env' }).parsed
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
    },
    {
      name: 'chat-langchain-frontend',
      cwd: '/opt/chat-langchain-study2/frontend',
      script: 'yarn',
      args: 'start',
      env: {
        PORT: 3000,
        NODE_ENV: 'production'
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
    }
  ]
};
EOF

# 安装 dotenv（用于加载环境变量）
cd /opt/chat-langchain-study2
npm install dotenv

# 启动服务
pm2 start ecosystem.config.js

# 查看服务状态
pm2 status

# 查看日志
pm2 logs

# 设置开机自启
pm2 startup
pm2 save
```

### 第八步：配置 Nginx 反向代理（可选）

```bash
# 创建 Nginx 配置
sudo cat > /etc/nginx/sites-available/chat-langchain << 'EOF'
# 前端配置
server {
    listen 80;
    server_name yourdomain.com;  # 替换为你的域名或使用 _

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# 后端 API 配置
server {
    listen 80;
    server_name api.yourdomain.com;  # 替换为你的 API 域名

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS 配置
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
        add_header Access-Control-Allow-Headers 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
        
        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }
}
EOF

# 启用配置
sudo ln -s /etc/nginx/sites-available/chat-langchain /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

### 第九步：配置 HTTPS（推荐）

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取 SSL 证书（需要先配置好域名解析）
sudo certbot --nginx -d yourdomain.com -d api.yourdomain.com

# Certbot 会自动配置 Nginx 并设置自动续期
```

---

## 🔧 常用管理命令

### PM2 进程管理

```bash
# 查看所有服务状态
pm2 status

# 查看日志
pm2 logs
pm2 logs chat-langchain-backend
pm2 logs chat-langchain-frontend

# 重启服务
pm2 restart all
pm2 restart chat-langchain-backend
pm2 restart chat-langchain-frontend

# 停止服务
pm2 stop all
pm2 stop chat-langchain-backend

# 删除服务
pm2 delete all
pm2 delete chat-langchain-backend
```

### 更新代码

```bash
# 进入项目目录
cd /opt/chat-langchain-study2

# 拉取最新代码
git pull origin main

# 更新后端依赖（如果有变化）
poetry install

# 更新前端依赖（如果有变化）
cd frontend
yarn install
yarn build

# 重启服务
pm2 restart all
```

### 查看服务日志

```bash
# 实时查看所有日志
pm2 logs

# 查看后端日志
pm2 logs chat-langchain-backend --lines 100

# 查看前端日志
pm2 logs chat-langchain-frontend --lines 100

# 查看 Nginx 日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

---

## 🛡️ 安全配置

### 配置防火墙

```bash
# 安装 UFW
sudo apt install -y ufw

# 允许 SSH
sudo ufw allow 22

# 允许 HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# 如果不使用 Nginx，需要开放应用端口
sudo ufw allow 3000
sudo ufw allow 8080

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

### 环境变量安全

```bash
# 确保 .env 文件权限正确
chmod 600 /opt/chat-langchain-study2/.env

# 不要将 .env 文件提交到 Git
echo ".env" >> /opt/chat-langchain-study2/.gitignore
```

---

## 🐛 故障排查

### 后端无法启动

```bash
# 检查 Python 版本
python3.11 --version

# 检查 Poetry 是否正确安装
poetry --version

# 手动测试后端
cd /opt/chat-langchain-study2
poetry run uvicorn --app-dir=backend main:app --host 0.0.0.0 --port 8080

# 查看详细错误信息
pm2 logs chat-langchain-backend --err --lines 50
```

### 前端无法访问

```bash
# 检查 Node.js 版本
node --version

# 检查前端构建
cd /opt/chat-langchain-study2/frontend
yarn build

# 手动启动前端
yarn start

# 查看前端日志
pm2 logs chat-langchain-frontend --lines 50
```

### Weaviate 连接失败

```bash
# 测试 Weaviate 连接
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://your-weaviate-url/v1/meta

# 检查环境变量
echo $WEAVIATE_URL
echo $WEAVIATE_API_KEY

# 重新导入数据
cd /opt/chat-langchain-study2
export $(cat .env | xargs)
poetry run python backend/ingest.py
```

### 端口被占用

```bash
# 查看端口占用
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8080

# 杀死占用端口的进程
sudo kill -9 <PID>

# 或者修改端口配置
```

---

## 📊 性能优化

### 1. 使用 Nginx 缓存

```nginx
# 在 Nginx 配置中添加缓存
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m;

location / {
    proxy_cache my_cache;
    proxy_cache_valid 200 60m;
    proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
    # ... 其他配置
}
```

### 2. 增加 PM2 实例数

```javascript
// 在 ecosystem.config.js 中修改
instances: 2,  // 或使用 'max' 自动检测 CPU 核心数
exec_mode: 'cluster',
```

### 3. 配置 CDN

- 将前端静态资源上传到 CDN
- 修改前端配置使用 CDN 地址

---

## 🔄 备份和恢复

### 备份数据

```bash
# 创建备份目录
mkdir -p /backup/chat-langchain

# 备份环境变量
cp /opt/chat-langchain-study2/.env /backup/chat-langchain/

# 备份 PM2 配置
pm2 save
cp ~/.pm2/dump.pm2 /backup/chat-langchain/

# 备份 Nginx 配置
sudo cp /etc/nginx/sites-available/chat-langchain /backup/chat-langchain/
```

### 恢复数据

```bash
# 恢复环境变量
cp /backup/chat-langchain/.env /opt/chat-langchain-study2/

# 恢复 PM2 进程
pm2 resurrect

# 恢复 Nginx 配置
sudo cp /backup/chat-langchain/chat-langchain /etc/nginx/sites-available/
sudo systemctl restart nginx
```

---

## 📞 获取帮助

如果遇到问题：
1. 查看本文档的故障排查部分
2. 查看 PM2 日志：`pm2 logs`
3. 查看 GitHub Issues：https://github.com/huhurich/chat-langchain-study2/issues
4. 检查 Render 部署的日志作为参考

---

## ✅ 部署检查清单

- [ ] 服务器配置满足要求
- [ ] 系统依赖全部安装
- [ ] 项目代码已克隆
- [ ] 环境变量已配置
- [ ] 后端依赖已安装
- [ ] 前端依赖已安装并构建
- [ ] 数据已导入向量数据库
- [ ] PM2 服务已启动
- [ ] 防火墙已配置
- [ ] Nginx 反向代理已配置（可选）
- [ ] HTTPS 证书已配置（可选）
- [ ] 可以通过浏览器访问网站
- [ ] 聊天功能测试正常

---

**祝部署顺利！** 🚀
