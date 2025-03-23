---
categories:
- XAML
date: 2023-08-08 22:11
last_modified_at: 2025-03-23 12:55:44 +0800
mtime: 2025-03-23 12:55:44
tags:
- XAML
title: XAML格式化工具：XAML Styler
---

## XAML格式化的意义
在开发WPF应用过程中，编写XAML时需要手动去缩进或者换行，随着时间的推移或者参与开发的人增多，XAML文件内容的格式会越来越乱。要么属性全都写在一行，内容太宽一屏无法完整展现；要么属性单独占一行，难以直观的看清结构；另外xaml元素的属性无序，重要属性查找困难，手动维护属性使之规律有序也比较费时。

格式化XAML代码可以使代码布局整齐，减少冗余空格和换行符，使代码结构清晰、缩进一致。使代码更易于阅读和理解，开发人员能够更快速地编写和修改代码。此外，还可以确保整个项目中的代码风格一致，对于团队协作和代码维护非常重要。然而微软官方并未提供很好的XAML格式化方案，不过Visual Studio Marketplace中有个非常好用的插件[XAML Styler](https://github.com/Xavalon/XamlStyler)。

## 安装配置XAML Styler
在Visual Studio的扩展管理窗口中，搜索XAML Styler下载安装后重启Visual Studio即可完成安装。在"工具"->"选项"中找到"XAML Styler"可以进行详细配置。每一项具体含义参见[配置项说明](#DescriptionofConfig)
![XAMLStyler](https://eb19df4.webp.li/2025/02/XAMLStyler.png)
如果需要在XAML编辑器执行保存时自动格式化，需要把`Format XAML on save`设置为true。如果想手动格式化，则直接在XAML编辑器中右键菜单点击`Format XAML`或者使用快捷键进行格式化。
![FormatXAML](https://eb19df4.webp.li/2025/02/FormatXAML.png){: .normal }### 统一格式化标准
在团队开发中，即便所有的人都使用XAML Styler,也可能因个人习惯不同选择不同的设置，也会带来很多麻烦。针对这个问题，XAML Styler也提供了解决方案。

在项目的根目录创建一个名为"Settings.XamlStyler"的文件（不必引入到项目中），内容可参考[Default Configuration](https://github.com/Xavalon/XamlStyler/wiki/External-Configurations),XAML Styler会根据这个文件而不是Visual Studio中的全局配置进行格式化，既解决了项目的统一格式化标准问题，也允许开发人员按照自己的习惯开发非团队项目。
<a id="DescriptionofConfig"></a>

"Settings.XamlStyler"配置项及注释如下,大家可根据自身习惯酌情修改
```JSON
{
    "IndentSize": 4,  //缩进空格数，4【默认】
    "IndentWithTabs": false   //是否使用制表符进行缩进，false【默认】
    "AttributesTolerance": 2, //单行最大属性数，2【默认】，如果元素属性数不大于此数就不会换行
    "KeepFirstAttributeOnSameLine": false, //第一个属性是否与开始标记在同一行，false【默认】
    "MaxAttributeCharactersPerLine": 0, //多个属性大于多少个字符就该换行，0【默认】
    "MaxAttributesPerLine": 1, //大于几个属性就该换行，1【默认】
    "NewlineExemptionElements": "RadialGradientBrush, GradientStop, LinearGradientBrush, ScaleTransform, SkewTransform, RotateTransform, TranslateTransform, Trigger, Condition, Setter", //属性不应该跨行中断的元素
    "SeparateByGroups": false, //是否应该按照属性的分组进行分行，false【默认】
    "AttributeIndentation": 0,  //属性缩进空格字符数（-1不缩进；0【默认】缩进4个空格；其它个数则指定）
    "AttributeIndentationStyle": 1, //属性缩进风格（0混合，视情况使用制表符和空格；1【默认】使用空格）
    "RemoveDesignTimeReferences":  false, //是否移除自动添加的控件和设计时引用内容，false【默认】
    "IgnoreDesignTimeReferencePrefix": false, //排序时是否忽略带有设计时引用命名空间前缀的属性，false【默认】
    "EnableAttributeReordering": true, //是否启用属性的自动排序，true【默认】
    /*属性排序和分组规则*/
    "AttributeOrderingRuleGroups": [
        "x:Class",
        "xmlns, xmlns:x",
        "xmlns:*",
        "x:Key, Key, x:Name, Name, x:Uid, Uid, Title",
        "Grid.Row, Grid.RowSpan, Grid.Column, Grid.ColumnSpan, Canvas.Left, Canvas.Top, Canvas.Right, Canvas.Bottom",
        "Width, Height, MinWidth, MinHeight, MaxWidth, MaxHeight",
        "Margin, Padding, HorizontalAlignment, VerticalAlignment, HorizontalContentAlignment, VerticalContentAlignment, Panel.ZIndex",
        "*:*, *",
        "PageSource, PageIndex, Offset, Color, TargetName, Property, Value, StartPoint, EndPoint",
        "mc:Ignorable, d:IsDataSource, d:LayoutOverrides, d:IsStaticText",
        "Storyboard.*, From, To, Duration",
        "TargetType",
        "BasedOn"
    ],
    "FirstLineAttributes": "x:Name,Grid.Row,Grid.Column",  //应该在第一行的属性，例如x:Name 和x:Uid等等,None【默认】
    "OrderAttributesByName": true, //是否按照属性名称进行排序
    "PutEndingBracketOnNewLine": false, //结束括号是否独占一行，false【默认】
    "RemoveEndingTagOfEmptyElement": true, //是否移除空元素的结束标签，true【默认】
    "SpaceBeforeClosingSlash": true, //自闭合元素的末尾斜杠前是否要有空格，true【默认】
    "RootElementLineBreakRule": 0, //是否将根元素的属性分成多行（0【默认】；1始终；2从不）
    "ReorderVSM": 2, //是否重新排序visualstateManager（0未定义；1移到最前；2【默认】移到最后）
    "ReorderGridChildren": false, //是否重新排序Grid的子元素，false【默认】
    "ReorderCanvasChildren": false, //是否重新排序Canvas的子元素，false【默认】
    "ReorderSetters": 0, //是否重新排序Setter（0【默认】不排序；1按属性名；2按目标名；3先按目标名再按属性名）
    "FormatMarkupExtension": true, //是否格式化标记扩展的属性，true【默认】
    "NoNewLineMarkupExtensions": "x:Bind, Binding",     //始终放在一行上的标记扩展，"x:Bind, Binding"【默认】
    "ThicknessSeparator": 2, //Thickness类型的属性应该用哪种分隔符(0不格式化；1空格；2【默认】逗号）
    "ThicknessAttributes": "Margin, Padding, BorderThickness, ThumbnailClipMargin",     //被认定为Thickness的元素应该是哪些，"Margin, Padding, BorderThickness, ThumbnailClipMargin"【默认】
    "FormatOnSave": true, //是否在保存时进行格式化，true【默认】
    "CommentPadding": 2, //注释的间距应该是几个空格，2【默认】
}
```

部分属性配置选项
* AttributeIndentationStyle
    * Mixed = 0  混合，视情况使用制表符和空格
    * Spaces = 1 【默认】使用空格
* RootElementLineBreakRule
    * Default = 0 【默认】
    * Always = 1 始终
    * Never = 2 从不
* ReorderVSM
    * None = 0 未定义
    * First = 1 移到最前
    * Last = 2 【默认】移到最后
* ReorderSetters
    * None = 0 【默认】不排序
    * Property = 1 按属性名
    * TargetName = 2 按属性名
    * TargetNameThenProperty = 3 先按目标名再按属性名
* ThicknessSeparator
    * None = 0 不格式化
    * Space = 1 空格
    * Comma = 2 【默认】逗号


如果对于上述配置中每一项的注释没有直观的感受，可以通过[wiki](https://github.com/Xavalon/XamlStyler/wiki/Attribute-Formatting)查看每项配置对应代码格式化后的效果。