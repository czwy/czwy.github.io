---
categories:
- WPF
date: 2024-03-12 17:29
last_modified_at: 2025-03-23 12:09:55 +0800
mtime: 2025-03-23 12:09:55
tags:
- WPF
title: 探究WPF中文字模糊的问题：TextOptions的用法
---

有网友问WPF中一些文字模糊是什么问题。之前我也没有认真思考过这个问题，只是大概知道和WPF的像素对齐（pixel snapping）、抗锯齿（anti-aliasing）有关，通过设置附加属性`TextOptions.TextFormattingMode`或者`TextOptions.TextRenderingMode`来解决。这次我也查了下资料，了解了这几个附加属性的取值范围以及用法。

## 像素对齐和抗锯齿
我们经常听到WPF具有分辨率无关性这个说法，因为WPF使用的是与设备无关的绘图系统，为字体和形状等内容指定大小或者尺寸的数值并不是真实的像素，在WPF中称之为设备无关单位。渲染过程中，WPF会自动把设备无关单位转换为物理像素，由于设备的差异以及DPI设置不同，转换之后的像素很少是整数，然而无法使用零点几个像素点去绘制，WPF会使用抗锯齿特性进行补偿。

例如绘制一条62.4992个像素长的红线时，WPF会正常填充前62个像素，然后使用直线颜色（红色）和背景色之间的颜色为第63个像素着色，但这个补偿也会带来新的问题，在绘制直线、矩形或者具有直角的多边形时，抗锯齿特性导致形状边缘出现一片模糊的区域。在实际应用中的体现就是前边说的文字模糊，奇数单位宽度的直线两侧有很细的淡色边缘，如果直线宽度只有1个设备无关单位，肉眼看到的线条颜色会比实际指定的颜色要浅一点。

## `TextOptions`的使用
`TextOptions`定义一组影响文本在元素中的显示方式的附加属性。总共包含三个附加属性：`TextFormattingMode`、`TextHintingMode`、`TextRenderingMode`。这三个附加属性类型都是与属性同名的枚举类型。

### `TextFormattingMode`附加属性
`TextFormattingMode`附加属性用于切换WPF在格式化文本时使用的文本度量。取值范围如下：

|枚举名|值|说明|
|------|--|----|
|Ideal|0|指示 TextFormatter 使用理想的字体规格布局文本。|
|Display|1|指示 TextFormatter 使用 GDI 兼容字体规格布局文本。|

官方文档上的这个描述看起来似乎很直观，但并不容易理解它俩的区别以及开发过程中选取哪一个值。

* Ideal：自推出WPF以来一直用于格式化文本的度量。绘制的字体形状与字体文件中的轮廓保持高保真。创建字形位图或者字形与字形之间的相对定位时，不会考虑最终位置。
* Display：WPF4.0中引入的新的格式化文本的度量模式。它使用GDI兼容的文本度量。该模式下每个字形的宽度都是整数个像素，字形的大小和换行与基于GDI的框架相似（比如WinForm）。这也就意味着字形的大小和换行不完全准确。

两种模式都有各自的优势和缺点，Ideal模式可以提供最佳的字形和间距，减少用户阅读疲劳，但是在较小的字体情况下，文字渲染会模糊。Display模式则是牺牲字体形状和间距为代价，提供像素对齐的清晰的文字。
大多数情况下，两种模式渲染的文字效果差异很小，Display模式主要是解决较小字体情况下文字模糊的问题。Ideal模式在大于15pt的字体情况下，和Display模式渲染的文字一样清晰，且具有更好的字形和间距。此外以下三种情况也应选择Ideal模式。
* 变换文本：Display模式只有在字形绘制在完整的像素上时才有清晰的效果，对文本进行变换时，Display模式的像素对齐存在偏差，因为该模式的优化是在所有变换之前应用的，应用变换后将不再对齐到像素边界，从而导致文字模糊。而Ideal模式在任何地方绘制文字都具有同样的渲染效果。
* 缩放文本：缩放其实也是变换的一种形式，但相比其他的2D变换，Display模式在缩放文本时渲染的效果更差，主要是因为该模式下的文本度量不会随着缩放倍数线性变化，为了保持缩放的准确性，Display模式是对原始尺寸文字的位图进行缩放，这导致在任何明显尺度变化时产生模糊和伪影。
* 字形高保真：对字形有非常高的要求时，Ideal模式具有更好的效果，这也是Ideal模式的主要优势之一。

### `TextRenderingMode`附加属性
`TextRenderingMode`附加属性用于控制渲染文字时使用的抗锯齿算法。取值范围如下：

|枚举名|值|说明|
|------|--|----|
|Auto|0|根据用于设置文本格式的布局模式，使用最合适的呈现算法呈现文本。除非操作系统已经被设置为在本机禁用ClearType，该模式将使用ClearType。|
|Aliased|1|使用双层抗锯齿功能呈现文本。(有的地方说不使用抗锯齿算法)|
|Grayscale|2|使用灰度抗锯齿功能呈现文本。|
|ClearType|3|使用最合适的ClearType呈现算法呈现文本。|

通常情况，不需要对该属性进行设置，除非操作系统已经设置在本机禁用ClearType，默认是会使用ClearType呈现算法呈现文本。在液晶显示器环境，ClearType技术增强了文本的清晰度和可读性。

ClearType使用亚像素呈现技术，通过将字符对齐到像素的小数部分，以更高的保真度显示文本的真实形状。超高的分辨率增加了文本显示中细节的清晰度，使其更便于长时间阅读。WPF中ClearType可以朝Y轴方向抗锯齿，使文本字符中平缓曲线的顶端和底端变得平滑。

### `TextHintingMode`附加属性
`TextHintingMode`附加属性用于设置静态文本或动态文本的呈现行为。取值范围如下：

|枚举名|值|说明|
|------|--|----|
|Auto|0|自动确定是否使用适用于动画文本或静态文本的质量设置来绘制文本。|
|Fixed|1|以最高静态质量呈现文本。|
|Animated|2|以最高动画质量呈现文本。|

Fixed模式使用的算法针对视觉上精确的字体平滑效果进行优化，但是将动画应用于字体元素的属性时，可能导致性能问题以及抖动，尤其是对于 转换和投影。Animated模式通过使用一个更高效、但视觉精确下降的平滑算法来针对动画进行优化。


## 参考
1. https://devblogs.microsoft.com/visualstudio/wpf-text-clarity-improvements/
2. https://learn.microsoft.com/en-us/archive/blogs/text/additional-wpf-text-clarity-improvements
3. https://learn.microsoft.com/en-us/archive/blogs/text/wpf-4-0-text-stack-improvements