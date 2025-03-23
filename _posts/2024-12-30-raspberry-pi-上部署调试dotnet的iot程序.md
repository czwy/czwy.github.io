---
categories:
- 树莓派
date: 2024-12-30 10:19
last_modified_at: 2025-03-23 18:20:40 +0800
mtime: 2025-03-23 18:20:40
tags:
- 树莓派
- dotnet
- IoT
title: Raspberry pi 上部署调试dotnet的IoT程序
---

树莓派（Raspberry pi）是一款基于ARM 架构的单板计算机（Single Board Computer），可以运行各种 Linux 操作系统，其官方推荐使用的 Raspberry Pi OS 也是基于Debian开发的。因其低能耗、便携小巧、GPIO等特性，可用于IoT应用开发。.NET可在各种平台和体系结构上运行，并提供了 IoT 库支持与传感器、模数转换器、舵机、RFID这些专用硬件设备交互，使 .NET在树莓派运行 IoT 应用成为可能。
## 部署.NET的IoT程序
通常情况，在本机开发调试是最佳选择，但是树莓派的低能耗也制约了其性能，例如本文接下来描述操作的都是在 Raspberry Pi Zero 2 W 上进行的，其配备的Broadcom BCM2710A1 是一款四核 64 位 SoC（Arm Cortex-A53 @ 1GHz）的CPU，内存为512MB，在上边安装IDE编码和调试不太现实，因此需要在开发计算机上开发应用，然后将应用部署到树莓派上进行远程调试。
### 发布程序
完成程序编码后，在项目名称右键菜单中选择“发布”，然后在发布配置窗中选择目标为文件夹，然后下一步特定目标依旧选择文件夹。
![PublishConfigure](https://eb19df4.webp.li/2025/02/ConfigurationFileSetting.png)
完成后进行配置文件设置。配置选择`Debug|Any CPU` ；目标框架根据实际情况选择，这里选择了 `net8.0` ；部署模式可以选择依赖框架或者独立，由于远程调试时需要在树莓派上安装 .NET 运行时，所以这里选择依赖框架，可以减少程序大小；前边提到树莓派是 ARM 架构的，最新的操作系统也是64位的，所以目标运行时选择 `linux-arm64` 。
![ConfigurationFileSetting](https://eb19df4.webp.li/2025/02/MFRC522SampleRunning.png)
配置完成后，点击“发布”按钮，程序会发布到配置的目标位置。
### 部署到树莓派
#### 树莓派上安装配置.NET
首先使用 [dotnet-install 脚本](https://learn.microsoft.com/zh-cn/dotnet/core/tools/dotnet-install-script) 在树莓派上安装 .NET。
``` shell
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel LTS
```
> `--channel`参数是指定安装的源通道。 可能的值为：
> - `STS`：最新的标准期限支持版本。
> - `LTS`：最新的长期支持版本。
> - 表示特定版本的由两部分构成的 A.B 格式版本（例如 `3.1` 或 `8.0`）。
> - A.B.Cxx 格式的三部分版本，表示特定的 SDK 版本（例如 8.0.1xx 或 8.0.2xx）。 自 5.0 版本起可用。
{: .prompt-info }

然后将 `DOTNET_ROOT` 环境变量和 dotnet 目录添加到 `$PATH`
``` bash
echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/.dotnet' >> ~/.bashrc
source ~/.bashrc
```
#### 部署.NET程序
Windows 10 (build 1809）之后的版本具有 OpenSSH，其中包括预安装的 `scp`。可以使用scp命令把发布的文件拷贝到树莓派指定目录：
``` powershell
scp -r F:\Source\git\mfrcc522Sample\mfrcc522Sample\bin\Debug\net8.0\publish\linux-arm64 john@192.168.3.58:/home/john/Downloads/MFRC522
```
scp命令格式如下：
```
scp [选项] [[用户@]源主机:]文件路径 [[用户@]目标主机:]文件路径
```
常用选项包括：
- `-C`：允许压缩数据，提高传输效率。
- `-p`：保留文件的修改时间、访问时间和权限。
- `-r`：递归复制整个目录。
- `-q`：静默模式，不显示传输过程中的信息。
- `-v`：详细模式，显示传输过程中的详细信息。

进入程序目录，给程序添加可执行权限后运行程序
``` bash
cd Downloads/MFRC522/linux-arm64
chmod 755 mfrcc522Sample
./mfrcc522Sample
```
![MFRC522SampleRunning](https://eb19df4.webp.li/2025/02/attach-to-running-processes.png)
### 远程调试
程序在树莓派上运行后，在开发电脑上打开visual Studio，选择“调试”>“附加到进程…”，或者用快捷键`ctrl+alt+p` 打开"附加到进程"窗口，连接类型选择"SSH"，连接目标输入树莓派的ip，其格式为`<username>@<IP>`，点击查找按钮连接上树莓派后，进程列表会显示所有进程，选中目标进程。右下角代码类型下拉框选择”托管（.NET Core for unix）代码“，点击“附加”就可以开始远程调试了。
![attach-to-running-processes](https://eb19df4.webp.li/2025/02/Remote-Debug.png)
接下来就可以远程调试用户代码了
![Remote-Debug](https://eb19df4.webp.li/2025/02/Deselect-Enable-Just-MyCode.png)

#### 调试IoT库源码
在调试过程中出现了IoT库报的错误，通过"F12"可以查看到源码， 想进一步调试IoT的代码，则需要启用源码调试。步骤如下：
1. 在“**工具**”（或“**调试**”）>“**选项**”>“**调试**”>“**常规**”下，确保：
    - 取消选择“**启用仅我的代码**”。
    - 选择“**启用源链接支持**”。
![Deselect-Enable-Just-MyCode](https://eb19df4.webp.li/2025/02/Select-Microsoft-Symbol-Servers.png)
1. 在“**工具**”（或“**调试**”）>“**选项**”>“**调试**”>“**符号**”下，选择“**Microsoft 符号服务器**”。
![Select-Microsoft-Symbol-Servers](https://eb19df4.webp.li/2025/02/failed-Hit-breakpoint.png)
调试过程中可能遇到断点处显式红心圆和警告提示：“当前不会命中断点。还没有为该文档加载任何符号。”
![failed-Hit-breakpoint](https://eb19df4.webp.li/2025/02/Load-Symbols.png)
这时需要在导航栏选择“**调试**>**Windows**>**模块**”，检查模块是否已加载，如果显示没有加载符号，右键单击尚未加载符号的模块，点击”加载符号“，这时断点处会显示红色实心圆。
![Load-Symbols.png](https://eb19df4.webp.li/2025/02/Load-Symbols.png)
## 参考
1. [在 Linux 上不使用包管理器的情况下安装 .NET - .NET &#124; Microsoft Learn](https://learn.microsoft.com/zh-cn/dotnet/core/install/linux-scripted-manual#scripted-install)
2. [调试 .NET Framework 源代码 - Visual Studio (Windows) &#124; Microsoft Learn](https://learn.microsoft.com/zh-cn/visualstudio/debugger/how-to-debug-dotnet-framework-source?view=vs-2022)
3. [排查调试器中的断点问题 - Visual Studio &#124; Microsoft Learn](https://learn.microsoft.com/zh-cn/troubleshoot/developer/visualstudio/debuggers/troubleshooting-breakpoints?view=vs-2022)