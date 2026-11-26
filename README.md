# PS5Upload for fnOS

飞牛原生 Docker FPK 薄壳，使用 PS5Upload 官方镜像，Host 网络，端口 19113。不增加业务后台，不挂 Docker Socket，不加入 docker 用户组，不用脚本生成 Compose。

安装配置：游戏目录、PS5 IP（可选）、临时安装包目录、应用数据目录（可选）。目录通过文本框填写宿主机绝对路径，默认游戏目录使用 PS5Upload 共享目录，默认临时目录使用应用数据目录。指定临时目录时，程序使用其下的 ps5upload-staging 子目录。外部目录需要预先存在，应用用户必须拥有读取或写入权限；不自动修改用户文件权限。游戏目录只读，应用状态默认保存在飞牛应用数据目录（TRIM_PKGVAR），直接读写挂载到 `/data`；填写已有的宿主机绝对路径（例如 `/vol1/1000/ps5upload/data`）可覆盖默认位置。目录必须可由应用用户读写。0.1.3 及更早版本使用具名卷 `ps5upload-fnos_ps5upload-data`，本版本不自动迁移或删除旧卷；已有用户应先停服务、备份并复制旧数据，再升级。服务无密码，开放 IPv4，仅供可信网络使用，禁止直接暴露公网。

安装向导字段直接进入 Compose，参考 WechatOnCloud（https://github.com/Gloridust/WechatOnCloud/tree/main/fnos/woc）及 Transmission（https://github.com/conversun/fnos-apps/issues/290）。镜像更新由飞牛 Docker 管理器负责。配置保存后是否重建及重建时参数是否保留，需要真机验证；如果系统没有重建，不应宣称配置已生效。当前不实现图形化选择器，不使用安装后授权来冒充安装向导选择器。CI 仅验证真实镜像、模拟向导参数、读写与数据保留及 FPK 构建。真机安装、权限、更新和配置变更仍待验证。发布包通过 CI 容器测试与官方 fnpack 打包后上传至 Releases。

## 目录校验

安装与配置阶段检查所有非空自定义目录的格式、存在性及运行脚本身份的访问权限，错误时返回非零并写入可用的 TRIM_TEMP_LOGFILE。留空不检查系统尚未创建的默认目录。Compose 禁止自动创建绑定源目录。原生向导未公开宿主机路径实时校验接口，因此不存在的目录在安装前置阶段报错，不保证在点击下一步时直接显示字段内错误；实际回调时序与提示仍须在 fnOS 真机确认。

## 桌面入口

官方 WebUI 设置 SAMEORIGIN 和 frame-ancestors self，不能直接从飞牛桌面跨端口 iframe。候选版使用飞牛统一网关和仅监听 Unix Socket 的 nginx 反代，保留上游响应头与 Host 网络，不新增 TCP 监听。直接访问路径为 http://NAS-IP:19113/app/ps5upload/（仅可信局域网）。网关代理需要飞牛转发管理员 Header；CI 模拟该 Header，并不代表飞牛真机登录态已验收。公开域名可能被上游 Host 校验拒绝，本版不关闭该安全检查。Docker Host 网络没有端口映射图标，这是正常现象。
