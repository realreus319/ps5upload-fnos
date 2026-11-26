# PS5Upload for fnOS — native directory review candidate

本分支是独立 CI 验证候选，不是发布版。保留飞牛 docker-project 和专用应用用户，不请求 root 权限，不修改上游镜像。安装自动创建 PS5Upload 共享目录，游戏目录只读，配置和临时包存于固定命名卷。IP 白名单固定开放 IPv4，仅用于可信网络，禁止直接暴露公网。

已有游戏目录的候选实现依赖飞牛把 TRIM_DATA_ACCESSIBLE_PATHS 注入 Compose，并在原生权限修改时重建容器。当前只支持一个授权目录；空值回退默认共享目录。上述 fnOS 行为需要在真实设备验证；CI 仅验证模拟环境变量、真实镜像启动、读写权限和 FPK 打包。首次安装向导的原生文件夹选择控件仍无公开接口证据，不作已实现声明。

不在 CI 发布 Release。部署测试通过后仍须真机验收。参考：官方资源、权限、环境变量文档及 conversun/fnos-apps 的 wizard 参数注入实现。
