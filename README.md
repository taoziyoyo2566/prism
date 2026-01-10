# PhotoPrism Docker Compose 部署记录

本文档记录在本项目中部署 PhotoPrism + MariaDB 的完整创建过程，便于复现和排错。

## 环境准备

- 服务器已安装 Docker 和 Docker Compose（v2）
- 建议准备至少 2G 内存；内存偏小可参考下方性能限制配置

## 目录规划

本项目使用以下宿主机目录（与 `.env` 一致）：

```
/opt/photoprism/originals   # 原始照片
/opt/photoprism/storage     # 索引、缓存、缩略图、备份等
/opt/photoprism/database    # MariaDB 数据目录
```

创建目录并设置权限（UID/GID 见下文）：

```bash
sudo mkdir -p /opt/photoprism/{originals,storage,database}
sudo chown -R 999:988 /opt/photoprism
```

> 说明：`999:988` 为 PhotoPrism 容器运行的 UID/GID，可通过宿主机用户或已有用户来决定。

## 宿主机用户与权限准备

如果希望使用低权限系统用户来管理宿主机文件（推荐）：

```bash
# 1) 创建没有登录权限的系统用户 photoprism
sudo useradd -r -s /bin/false photoprism

# 2) 获取该用户的 UID/GID（记下这两个数字）
id photoprism

# 3) 建立目录并移交所有权给该低权限用户
sudo mkdir -p /opt/photoprism/database
sudo mkdir -p /opt/photoprism/storage
sudo mkdir -p /opt/photoprism/originals
sudo chown -R photoprism:photoprism /opt/photoprism
```

说明：如果 `originals` 目录需要被你的日常用户写入，也可只保证 `photoprism` 有读取权限，或单独调整该目录权限策略。

## 配置文件

### 1) `.env`

`.env` 用于统一管理环境变量。可直接运行 `scripts/prep.sh` 自动生成并填入随机密码：

```
PHOTOPRISM_ADMIN_PASSWORD=你的管理员密码
PHOTOPRISM_DATABASE_PASSWORD=你的数据库密码
MARIADB_PASSWORD=你的数据库密码
MARIADB_DATABASE=photoprism
MARIADB_USER=photoprism
MARIADB_ROOT_PASSWORD=你的root密码

PHOTOPRISM_UID=999
PHOTOPRISM_GID=988

HOST_STORAGE_PATH=/opt/photoprism/storage
HOST_ORIGINALS_PATH=/opt/photoprism/originals
HOST_DB_PATH=/opt/photoprism/database

PHOTOPRISM_WORKERS=1
PHOTOPRISM_ORIGINALS_LIMIT=500
# PHOTOPRISM_DISABLE_TENSORFLOW=true
```

关键点：
- `PHOTOPRISM_DATABASE_PASSWORD` 必须与 `MARIADB_PASSWORD` 一致。
- `MARIADB_DATABASE` / `MARIADB_USER` 必须配置，确保容器首次启动能自动建库和建用户。

### 2) `docker-compose.yml`

本项目已包含 `docker-compose.yml`，端口仅监听本地：

```
127.0.0.1:2342:2342
```

如需外网访问，建议通过反向代理对外提供服务。

## 启动流程

```bash
cd /home/kagoya/workspace/prism
sudo ./scripts/prep.sh
docker compose up -d
docker compose logs -f --tail=100 photoprism
```

`scripts/prep.sh` 会在缺少 `.env` 时自动生成，并尝试将当前用户加入 `docker` 组；如刚被加入需重新登录后再执行 `docker compose up -d`。

或者使用一键脚本（会先执行准备，再启动服务）：

```bash
cd /home/kagoya/workspace/prism
./scripts/up.sh
```

当日志出现 `waiting for the database to become available` 后，首次启动会等待数据库初始化。

## 登录信息

登录页用户名为 `admin`，密码为 `.env` 中的 `PHOTOPRISM_ADMIN_PASSWORD`。

## 用户管理

### 1) 创建 PhotoPrism 用户

```bash
cd /home/kagoya/workspace/prism
sudo docker compose exec photoprism photoprism users add -p "密码" -n "显示名称" 用户名
```

示例：

```bash
sudo docker compose exec photoprism photoprism users add -p "Alice123!" -n "Alice" alice
```

参数说明：
- `-p` 设置登录密码
- `-n` 设置显示昵称（可选）
- 最后一个参数为登录用户名

### 2) 修改用户密码

```bash
sudo docker compose exec photoprism photoprism users passwd -p "NewPass2026" alice
```

### 3) 查看用户列表

```bash
sudo docker compose exec photoprism photoprism users ls
```

## 常见问题与处理

### 1) 数据库认证失败（Error 1045）

原因通常为：
- `.env` 中 `PHOTOPRISM_DATABASE_PASSWORD` 与 `MARIADB_PASSWORD` 不一致
- `MARIADB_DATABASE` / `MARIADB_USER` 未配置，导致未创建用户

处理方式：
- 保留数据：进入 MariaDB 容器重置用户密码并授权
- 不保留数据：清空 `/opt/photoprism/database` 后重启容器让其重新初始化

### 2) 内存不足导致重启

可继续降低资源占用：

```
PHOTOPRISM_WORKERS=1
PHOTOPRISM_ORIGINALS_LIMIT=500
# PHOTOPRISM_DISABLE_TENSORFLOW=true
```

## 目录结构

```
/home/kagoya/workspace/prism/
├── .env
├── docker-compose.yml
└── README.md
```
