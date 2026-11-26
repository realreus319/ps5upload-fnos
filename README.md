# PS5Upload for fnOS — review candidate

飞牛原生 Docker FPK 薄壳，使用 PS5Upload 官方镜像，Host 网络，端口 19113。不增加业务后台，不挂 Docker Socket，不加入 docker 用户组，不用脚本生成 Compose。

安装配置：游戏目录、PS5 IP（可选）、临时安装包目录。目录通过文本框填写宿主机绝对路径，默认游戏目录使用 PS5Upload 共享目录，默认临时目录使用应用数据目录。指定临时目录时，程序使用其下的 ps5upload-staging 子目录。外部目录需要预先存在，应用用户必须拥有读取或写入权限；不自动修改用户文件权限。游戏目录只读，应用状态保存在原有固定命名卷。服务无密码，开放 IPv4，仅供可信网络使用，禁止直接暴露公网。

安装向导字段直接进入 Compose，参考 WechatOnCloud（https://github.com/Gloridust/WechatOnCloud/tree/main/fnos/woc）及 Transmission（https://github.com/conversun/fnos-apps/issues/290）。镜像更新由飞牛 Docker 管理器负责。配置保存后是否重建及重建时参数是否保留，需要真机验证；如果系统没有重建，不应宣称配置已生效。当前不实现图形化选择器，不使用安装后授权来冒充安装向导选择器。CI 仅验证真实镜像、模拟向导参数、读写与数据保留及 FPK 构建。真机安装、权限、更新和配置变更仍待验证。本分支不发布 Release。
