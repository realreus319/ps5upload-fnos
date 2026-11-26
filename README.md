# PS5Upload for fnOS

飞牛 FPK 薄壳，直接使用 [PS5Upload 官方镜像](https://github.com/phantomptr/ps5upload)，不修改上游业务代码。

## 状态

0.1.0 开发预览；未通过 fnOS 实机安装验收。当前向导使用路径文本输入，不是图形目录选择器；需要先在飞牛授权游戏目录，确保应用 UID/GID 可以读取。没有实现 FN Connect 网关或 HTTPS 串流入口。

## 构建

安装官方 fnpack，使用 Linux 和 Python 3，在仓库根目录执行 `bash build.sh`。构建脚本生成图标并设置脚本执行权限，再调用 fnpack build。将生成的 FPK 在飞牛应用中心手动安装。

## 使用

- 安装向导填写实际游戏目录和可信局域网 CIDR（不要直接暴露服务到公网）。
- 官方镜像使用 host 网络、TCP 19113；游戏目录只读挂载到 /pkgs，应用数据单独保存在 TRIM_PKGVAR/data。
- 飞牛桌面点击 PS5Upload 图标，使用 iframe 打开原始 WebUI。
- 应用设置可修改目录及可信网段；修改前结束安装和串流任务。
- 更新：使用飞牛 Docker 管理器对 ps5upload-fnos 项目拉取镜像并重建容器，保留原 Compose、环境变量和数据映射。不要删除数据目录。
- 如使用浏览器串流，需要 HTTPS 及 WebSocket 代理；本版本不提供公网访问或认证代理。

## 实机验收

1. 安装前确认 19113 未被占用，目录已授权。
2. 检查 install_callback 写入的 .env 是否在 Docker 项目首次启动前被读取。
3. 检查飞牛 Docker 项目是否使用 ps5upload-fnos 名称，容器 UID/GID 对游戏目录及数据目录是否具备所需权限。
4. 验证桌面小窗、PS5 发现、读取游戏文件及流式安装。
5. 修改目录后验证容器重新创建、旧数据保留。
6. 更新镜像后验证配置保留；启停、卸载行为由飞牛管理。
7. 后续验证图形目录授权及网关接入，不视为当前已完成能力。

参考：[飞牛 Docker 应用案例](https://developer.fnnas.com/docs/examples/docker/) · [上游 Compose](https://github.com/phantomptr/ps5upload/blob/main/engine/compose.yaml)
