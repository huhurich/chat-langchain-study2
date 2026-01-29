#!/bin/bash

# Chat LangChain 自动化部署脚本
# 适用于 Ubuntu 20.04/22.04

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用 root 用户或 sudo 运行此脚本"
    exit 1
fi

print_info "==================================="
print_info "Chat LangChain 自动化部署脚本"
print_info "==================================="
echo ""

# 检查操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    print_error "无法检测操作系统版本"
    exit 1
fi

print_info "检测到操作系统: $OS $VER"

if [[ ! "$OS" =~ "Ubuntu" ]]; then
    print_warning "此脚本针对 Ubuntu 优化，其他系统可能需要手动调整"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 收集配置信息
print_info "请输入配置信息："
echo ""

read -p "硅基流动 API Key: " OPENAI_API_KEY
read -p "Weaviate URL (例如: https://xxx.weaviate.cloud): " WEAVIATE_URL
read -p "Weaviate API Key: " WEAVIATE_API_KEY
read -p "Supabase 数据库连接字符串: " RECORD_MANAGER_DB_URL
read -p "LangSmith API Key (可选，直接回车跳过): " LANGCHAIN_API_KEY
read -p "服务器公网 IP 或域名: " SERVER_ADDRESS

echo ""
print_info "配置信息已收集，开始部署..."
echo ""

# 1. 更新系统
print_info "步骤 1/10: 更新系统..."
apt update && apt upgrade -y

# 2. 安装基础工具
print_info "步骤 2/10: 安装基础工具..."
apt install -y git curl wget vim build-essential software-properties-common

# 3. 安装 Python 3.11
print_info "步骤 3/10: 安装 Python 3.11..."
if ! command -v python3.11 &> /dev/null; then
    add-apt-repository ppa:deadsnakes/ppa -y
    apt update
    apt install -y python3.11 python3.11-venv python3.11-dev python3-pip
else
    print_info "Python 3.11 已安装"
fi

# 4. 安装 Node.js 20
print_info "步骤 4/10: 安装 Node.js 20..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
else
    NODE_VERSION=$(node --version)
    print_info "Node.js 已安装: $NODE_VERSION"
fi

# 5. 安装 Poetry
print_info "步骤 5/10: 安装 Poetry..."
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3.11 -
    export PATH="/root/.local/bin:$PATH"
    echo 'export PATH="/root/.local/bin:$PATH"' >> ~/.bashrc
else
    print_info "Poetry 已安装"
fi

# 6. 安装 Yarn 和 PM2
print_info "步骤 6/10: 安装 Yarn 和 PM2..."
npm install -g yarn pm2

# 7. 克隆项目
print_info "步骤 7/10: 克隆项目..."
cd /opt
if [ -d "chat-langchain-study2" ]; then
    print_warning "项目目录已存在，将进行更新..."
    cd chat-langchain-study2
    git pull origin main
else
    git clone https://github.com/huhurich/chat-langchain-study2.git
    cd chat-langchain-study2
fi

# 8. 配置环境变量
print_info "步骤 8/10: 配置环境变量..."
cat > .env << EOF
OPENAI_API_KEY=$OPENAI_API_KEY
OPENAI_API_BASE=https://api.siliconflow.cn/v1
WEAVIATE_URL=$WEAVIATE_URL
WEAVIATE_API_KEY=$WEAVIATE_API_KEY
RECORD_MANAGER_DB_URL=$RECORD_MANAGER_DB_URL
LANGCHAIN_TRACING_V2=true
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
LANGCHAIN_API_KEY=$LANGCHAIN_API_KEY
LANGCHAIN_PROJECT=chat-langchain-study
EOF

chmod 600 .env

# 9. 安装后端依赖
print_info "步骤 9/10: 安装后端依赖..."
export PATH="/root/.local/bin:$PATH"
poetry install
poetry run pip install weaviate-client==3.25.3 psycopg2-binary

# 10. 导入数据
print_info "步骤 10/10: 导入数据到向量数据库..."
export $(cat .env | xargs)
print_warning "数据导入可能需要几分钟，请耐心等待..."
poetry run python backend/ingest.py || print_warning "数据导入失败，可以稍后手动运行"

# 11. 安装前端依赖
print_info "安装前端依赖..."
cd frontend
yarn install

# 配置前端环境变量
cat > .env.local << EOF
NEXT_PUBLIC_API_BASE_URL=http://$SERVER_ADDRESS:8080
EOF

# 构建前端
print_info "构建前端..."
yarn build

# 12. 创建 PM2 配置
print_info "创建 PM2 配置..."
cd /opt/chat-langchain-study2

cat > ecosystem.config.js << 'EOFPM2'
require('dotenv').config({ path: '/opt/chat-langchain-study2/.env' });

module.exports = {
  apps: [
    {
      name: 'chat-langchain-backend',
      cwd: '/opt/chat-langchain-study2',
      script: '/root/.local/bin/poetry',
      args: 'run uvicorn --app-dir=backend main:app --host 0.0.0.0 --port 8080',
      env: process.env,
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      error_file: '/var/log/pm2/chat-backend-error.log',
      out_file: '/var/log/pm2/chat-backend-out.log',
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
      error_file: '/var/log/pm2/chat-frontend-error.log',
      out_file: '/var/log/pm2/chat-frontend-out.log',
    }
  ]
};
EOFPM2

# 安装 dotenv
npm install dotenv

# 创建日志目录
mkdir -p /var/log/pm2

# 13. 启动服务
print_info "启动服务..."
pm2 delete all 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# 14. 配置防火墙
print_info "配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 22
    ufw allow 80
    ufw allow 443
    ufw allow 3000
    ufw allow 8080
    echo "y" | ufw enable || true
fi

# 完成
echo ""
print_info "==================================="
print_info "部署完成！"
print_info "==================================="
echo ""
print_info "访问地址："
print_info "  前端: http://$SERVER_ADDRESS:3000"
print_info "  后端 API: http://$SERVER_ADDRESS:8080"
print_info "  API 文档: http://$SERVER_ADDRESS:8080/docs"
echo ""
print_info "常用命令："
print_info "  查看服务状态: pm2 status"
print_info "  查看日志: pm2 logs"
print_info "  重启服务: pm2 restart all"
print_info "  停止服务: pm2 stop all"
echo ""
print_warning "注意："
print_warning "  1. 首次访问后端可能需要等待几秒钟启动"
print_warning "  2. 如需配置域名和 HTTPS，请参考部署文档"
print_warning "  3. 建议定期备份 .env 文件和数据库"
echo ""
print_info "查看实时日志: pm2 logs"
