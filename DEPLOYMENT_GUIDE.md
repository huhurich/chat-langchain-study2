# 部署指南

## 环境变量配置

部署前需要配置以下环境变量：

### 后端环境变量
```bash
OPENAI_API_KEY=你的硅基流动API密钥
OPENAI_API_BASE=https://api.siliconflow.cn/v1
WEAVIATE_URL=你的Weaviate URL
WEAVIATE_API_KEY=你的Weaviate API密钥
RECORD_MANAGER_DB_URL=你的Supabase PostgreSQL连接字符串
LANGCHAIN_TRACING_V2=true
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
LANGCHAIN_API_KEY=你的LangSmith API密钥
LANGCHAIN_PROJECT=chat-langchain-study
```

### 前端环境变量
```bash
NEXT_PUBLIC_API_BASE_URL=你的后端API地址
```

## 部署步骤

### 1. 部署后端到 Railway

1. 访问 [Railway.app](https://railway.app)
2. 使用 GitHub 登录
3. 点击 "New Project" -> "Deploy from GitHub repo"
4. 选择 `huhurich/chat-langchain-study2` 仓库
5. 在 Variables 中添加上述后端环境变量
6. Railway 会自动检测并部署
7. 部署完成后，复制生成的域名（例如：https://xxx.railway.app）

### 2. 部署前端到 Vercel

1. 访问 [Vercel](https://vercel.com)
2. 使用 GitHub 登录
3. 点击 "Add New..." -> "Project"
4. 导入 `huhurich/chat-langchain-study2` 仓库
5. 配置：
   - Framework Preset: Next.js
   - Root Directory: `frontend`
   - Build Command: `yarn build`
   - Output Directory: `.next`
6. 在 Environment Variables 中添加：
   - `NEXT_PUBLIC_API_BASE_URL` = Railway 后端域名
7. 点击 Deploy

### 3. 数据导入

部署完成后，需要运行一次数据导入：

```bash
# 在本地或通过 Railway CLI 运行
poetry run python backend/ingest.py
```

或者通过 Railway 的 Shell 功能执行。

## 注意事项

- 确保所有 API 密钥正确配置
- Weaviate 和 Supabase 需要保持运行状态
- 首次部署后需要运行数据导入脚本
- 硅基流动 API 配置在 `backend/chain.py` 和 `backend/ingest.py` 中

## 本地开发

```bash
# 安装后端依赖
poetry install

# 运行数据导入（仅首次）
poetry run python backend/ingest.py

# 启动后端
make start

# 安装前端依赖
cd frontend && yarn install

# 启动前端
yarn dev
```
