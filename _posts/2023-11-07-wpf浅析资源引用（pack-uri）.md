---
categories:
- WPF
date: 2023-11-07 19:42
last_modified_at: 2025-03-23 13:10:39 +0800
mtime: 2025-03-23 13:10:39
tags:
- WPF
title: WPF浅析资源引用（pack URI）
---

WPF中我们引用资源时常常提到一个概念：`pack URI`，这是WPF标识和引用资源最常见的方式，但不是唯一的方式。本文将介绍WPF中引用资源的几种方式，并回顾一下`pack URI`标识引用在不同位置的资源文件的写法。

## WPF中引用资源的几种方式
WPF中使用URI标识和加载位于各种位置的文件，包括当前程序集资源文件、其他程序集资源文件、本地磁盘文件、网络共享文件、web站点文件。
### 程序集资源文件
程序集资源文件是最常见的一种情况。这里程序集资源指的是资源文件属性的生成操作(Build Action)为`Resource`的文件，而非`嵌入的资源(Emmbedded Resource)`。程序集中的资源文件通常使用相对URI来引用，例如：
```
<ImageBrush x:Key="imgbrush" ImageSource="images/111.jpg"/>   //本地程序集中资源引用的写法
<ImageBrush x:Key="imgbrush" ImageSource="/ResourceDll;component/images/111.jpg"/>   //引用的程序集中资源引用的写法
```
也可以使用绝对`Pack URI`语法，例如
```
<ImageBrush x:Key="imgbrush" ImageSource="pack://application:,,,/images/111.jpg"/>     //本地程序集中资源引用的写法
<ImageBrush x:Key="imgbrush" ImageSource="pack://application:,,,/ResourceDll;component/images/111.jpg"/>   //引用的程序集中资源引用的写法
```


### 本地磁盘文件
直接引用本地磁盘文件的方式不常见。这种方式引用本地文件会占用文件，本地文件无法修改或者删除，因此不推荐此方式。这里只是举例讲解。
```
<ImageBrush x:Key="imgbrush" ImageSource="d:\\tmp\\新建文件夹\\123.jpg"/> 
```

### 网络共享文件
网络共享文件和本地磁盘文件类似，会占用文件。可以使用UNC或者URI的方式引用。
```
<ImageBrush x:Key="imgbrush" ImageSource="\\192.168.0.1\tmp\新建文件夹\123.jpg"/>    UNC方式引用
<ImageBrush x:Key="imgbrush" ImageSource="file://192.168.0.1\tmp\新建文件夹\123.jpg"/>    URI方式引用
```

### web站点文件
少数场景下会在WPF中使用web站点资源，比如用户头像。web站点资源主要以http/https协议的url加载，url作为URI的子集，因此可以直接引用。实际开发中不建议直接引用url，因为请求网络资源需要时间，这可能导致UI短暂卡顿。建议开启线程把网络资源读到内存中使用。
```
<ImageBrush x:Key="imgbrush" ImageSource="https://pic.cnblogs.com/default-avatar.png"/>
```

上述示例中都是在XAML中声明式的语法引用资源，本质还是使用Uri类，因此在后台代码中使用Uri类就行。
```
// 绝对URI (默认)
Uri absoluteUri = new Uri("pack://application:,,,/images/111.jpg", UriKind.Absolute);
// 相对URI
Uri relativeUri = new Uri("images/111.jpg", UriKind.Relative);
```

## Pack URI方案

`pack URI`的语法看起来很奇怪，它是来自[开放式打包约定 (OPC)](https://www.ecma-international.org/publications-and-standards/standards/ecma-376/)规范中XPS(XML Paper Specification)标准，有使用openxml解析Word/PPT文件经验的朋友可能熟悉这个规范。OPC 规范利用`RFC 2396`（统一资源标识符 (URI)：一般语法）的扩展性来定义`pack URI`方案。

`URI`所指定的方案(schemes)由其前缀定义；`http`、`ftp`、`telnet`和`file` 是比较常见的协议方案(schemes)。`pack URI`使用“pack”作为它的方案(schemes)，并且包含两个组件：授权和路径。 `pack URI`的格式为：`pack://authority/path`。authority指定包含部件的包的类型，而path 指定部件在包内的位置。前边示例代码中`application:,,,`就是授权(authority)，`/images/111.jpg`或者`/ResourceDll;component/images/111.jpg`就是路径(path)。这里也可以理解为嵌套在方案(schemes)为`pack://`的uri中的uri。由于是嵌套在内部的uri，授权(authority)原本应是`application:///`中的斜杠转义为逗号。路径中必须对保留字符（如“%”和“?”）进行转义。详细信息可参阅[开放式打包约定 (OPC)](https://www.ecma-international.org/publications-and-standards/standards/ecma-376/)规范

> 标准的`URI`协议方案有30种左右，由隶属于国际互联网资源管理的非营利社团 ICANN（Internet Corporation for Assigned Names and Numbers，互联网名称与数字地址分配机构）的 IANA（Internet Assigned Numbers Authority，互联网号码分配局）管理颁布。详细协议方案参见:http://www.iana.org/assignments/uri-schemes

在WPF中，用程序（包）可以包含一个或多个文件（部件），包括：
* 当前程序集内的资源文件
* 引用的程序集内的资源文件
* 内容文件
* 源站点文件

为了访问这些类型的文件，WPF 支持两种授权：`application:///`和`siteoforigin:///`。[^1] application:/// 授权标识在编译时已知的应用程序数据文件，包括资源文件和内容文件。 siteoforigin:/// 授权标识源站点文件。 下图显示了每种授权的范围。

![iamge](https://learn.microsoft.com/zh-cn/dotnet/desktop/wpf/app-development/media/pack-uris-in-wpf/wpf-pack-uri-scheme.png?view=netframeworkdesktop-4.8)

## pack URI语法示例
前边提到`pack URI`由授权和路径组成，当前程序集、引用的程序集内的资源文件，以及内容文件的授权都是`application:///`，源站点文件的授权是`siteoforigin:///`（用于XAML浏览器应用程序）。

### 当前程序集资源文件
当前程序集资源文件的路径是资源文件相对程序集项目文件夹根目录的路径。**需要注意的是这里所说的相对于程序集项目文件夹根目录表达的是从哪里开始作为根目录进行寻址，当使用`pack://`这样绝对`URI`表示时，路径应该用根目录符号`/`开始**。下图中`111.jpg`位于项目的根目录，它的`pack URI`就是：
```
pack://application:,,,/111.jpg
```
`BlindsShader.ps`位于子目录中，它的`pack URI`就是：
```
pack://application:,,,/Shader/ShaderSource/BlindsShader.ps
```
![packURI](https://eb19df4.webp.li/2025/02/packURI.jpg)

### 引用程序集资源文件
当需要引用另一个程序集中的资源文件时，路径需要指明程序集的名称。路径需符合以下的格式：
```
pack://application:,,,AssemblyShortName{;Version}{;PublicKey};component/ResourceName
```
* **AssemblyShortName**是引用的程序集的短名称，是必选项
* ***Version***是引用的程序集的版本。此部分在加载两个或多个具有相同短名称的引用程序集时使用，是可选项。
* ***PublicKey***是引用的程序集的签名公钥。此部分在加载两个或多个具有相同短名称的引用程序集时使用，是可选项。
* **component**指定所引用的程序集是从本地程序集引用的，此处是固定写法
* **ResourceName**是资源文件的名称，包括其相对于所引用程序集的项目文件夹根目录的路径。

### 内容文件
前边提到的资源文件都是生成操作（Build Action）为`Resource`的文件，是会编译到程序集中。内容文件是生成操作（Build Action）为`内容(Content)`的文件，并不会编译到程序集中，通常是将文件属性中`复制到输出目录(CopyToOutputDirectory)`选为`始终复制(Always)`或者`如果较新则复制(PreserveNewest)`，将文件保存到程序运行目录中。内容文件主要可以解决以下问题：
* 改变资源文件时，需要重新编译应用程序；
* 资源文件比较大，导致编译的程序集也比较大；
* WPF声音文类不支持程序集资源，无法从资源流中析取音频文件并播放。

内容文件本质上也是本地磁盘文件，但生成项目时，会将` AssemblyAssociatedContentFileAttribute` 属性编译到每个内容文件的程序集的元数据内，`AssemblyAssociatedContentFileAttribute` 的值表示内容文件相对于其在项目中的位置的路径[^2]，可以采用`pack URI`的方式加载。内容文件的路径是其相对于应用程序的主可执行程序集的文件系统位置的路径。其格式如下：
```
pack://application:,,,/ContentFile.wav
```

### 源站点文件
源站点文件主要针对XAML浏览器应用程序(XBAP)设计，编译XAML浏览器应用程序(XBAP)将资源文件分离出程序集，减少文件大小，在需要请求下载源站点文件时，才下载它们到客户端计算机[^2]。现在基本不使用该技术，本文不再详细介绍，感兴趣可以查看文末参考资料。

## 参考
[^1]: https://learn.microsoft.com/zh-cn/dotnet/desktop/wpf/app-development/pack-uris-in-wpf?view=netframeworkdesktop-4.8
[^2]: https://learn.microsoft.com/zh-cn/dotnet/desktop/wpf/app-development/wpf-application-resource-content-and-data-files?view=netframeworkdesktop-4.8