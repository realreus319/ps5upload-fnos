# PS5Upload for fnOS — native directory review candidate

本分支仅供 CI 和真机验证，不发布 Release。使用官方镜像、Host 网络及飞牛 docker-project；应用进程以非 root UID/GID 运行。安装后自动创建 PS5Upload 共享目录，已有游戏目录通过飞牛应用设置 → 访问权限 → 添加，选择并授权一个目录（只读）。取消授权回到默认共享目录。安装向导没有公开的文件夹选择控件，故只提供说明，不要求手填路径。参考飞牛官方影视的安装后授权流程。

参考 basemetas-fileview 的 config_callback：比较容器实际挂载，变化时以相同项目名重建；不改动其他容器，不删除数据卷。应用脚本加入 docker 用户组，这是高权限（接近 root），用于 Docker 管理，未将 Docker socket 挂进业务容器。仅在手动安装测试时评估是否获准。配置及临时包使用原有固定命名卷。IP 白名单开放 IPv4，仅供可信网络，禁止直接暴露公网。

CI 调用真实生命周期脚本及官方镜像，模拟授权变更、撤销、重复保存、停止状态下修改、升级和数据保留。CI 无法模拟飞牛 ACL 和 appcenter 事件本身，必须真机确认授权回调、初次安装及升级顺序。参考：
- https://help.fnnas.com/articles/v1/media/media_install
- https://github.com/bug-yu/fnos-basemetas-fileview/blob/main/fpk/basemetas-fileview/cmd/config_callback
- https://github.com/conversun/fnos-apps/issues/290
