# Magisk 模块 - Move User Certs

此模块用于解决高版本 Android 无法复制用户证书到系统证书区问题。


注：只在 Android 11、12、13测试过，14应该也可以。

### 使用方法

1.下载最新的 [release](https://github.com/fany0r/MoveUserCertificate/releases) ZIP 文件。
2.给设备安装证书。
3.通过 Magisk 安装本模块。
4.重启设备，证书即会被成功复制到系统证书区。

### 添加证书

正常流程安装证书，重启设备。

### 删除证书

如需从系统区域中删除证书，只需要在设置中把用户级证书删除，然后重启即可。

### 参考连接

- https://weibo.com/3322982490/Ni21tFiR9
- https://github.com/ys1231/MoveCertificate/tree/iyue
- https://github.com/nccgroup/ConscryptTrustUserCerts
- https://github.com/lupohan44/TrustUserCertificates
- https://jesse205.github.io/MagiskChineseDocument/guides.html
