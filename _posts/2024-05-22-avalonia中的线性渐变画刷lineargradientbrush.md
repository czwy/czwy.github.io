---
categories:
- Avalonia
date: 2024-05-22 09:12
last_modified_at: 2025-02-28 00:44:20 +0800
mtime: 2025-02-28 00:44:20
tags:
- Avalonia
- XAML
title: Avalonia中的线性渐变画刷LinearGradientBrush
---

在WPF中使用Shape实现复杂线条动画后，尝试在Avalonia中也实现同样效果。尽管官方提供了从WPF到Avalonia的快速入门文档，但由于第一次使用Avalonia，体验过程中并不是很顺利，主要是卡在线性渐变画刷LinearGradientBrush的使用上。Avalonia中的线性渐变画刷与WPF中的略有差异，但相关文档并不多，故将此次经历记录下来并分享，希望能帮助大家少走弯路。

> 由于Avalonia在持续更新，本文所述内容仅针对Avalonia 11.0.10版本。
## WPF中的LinearGradientBrush
首先回顾一下WPF中LinearGradientBrush的使用，LinearGradientBrush是沿着`StartPoint`和`EndPoint`定义的直线渐变，并通过`GradientStops`属性设置画刷渐变停止点。默认情况下是沿着绘制区域的对角线进行渐变，也就是起点`StartPoint`是(0,0)，即绘制区域的左上角，终点`EndPoint`是(1,1)，即绘制区域的右下角。生成的渐变色沿对角线进行插值填充。例如：
```
<LinearGradientBrush x:Key="defaultLinearBrush">
    <GradientStop Offset="0.0" Color="Yellow" />
    <GradientStop Offset="0.25" Color="Red" />
    <GradientStop Offset="0.75" Color="Blue" />
    <GradientStop Offset="1" Color="LimeGreen" />
</LinearGradientBrush>
```
![defaultLinearBrush](https://eb19df4.webp.li/2025/02/defaultLinearBrush.png)

如果`StartPoint`是(0,0)，终点`EndPoint`是(1,0)，则是沿着水平方向从左到右渐变。
如果`StartPoint`是(0,0)，终点`EndPoint`是(0.5,0)，渐变效果如下图所示：
![HorizontalLinearGradientBrush](https://eb19df4.webp.li/2025/02/AvaloniaLinearGradientBrush1.png)

通过这个例子，可以看出`StartPoint`和`EndPoint`的值是相对于绘制区域的大小，渐变范围是从绘制区域最左边到1/2处，右侧1/2使用最后一个`GradientStop`设置的颜色填充。需要注意的是，`StartPoint`和`EndPoint`的值既可以是相对值，也可以是绝对值。这是由`LinearGradientBrush`的`MappingMode`属性决定的，`MappingMode`是枚举类型`BrushMappingMode`，枚举定义如下：

| 枚举                    | 取值  | 说明                                                                                    |
| --------------------- | --- | ------------------------------------------------------------------------------------- |
| Absolute              | 0   | 坐标系统与边界框无关。值直接在本地空间中解释。                                                               |
| RelativeToBoundingBox | 1   | **默认值。**坐标系统是相对于边界框的:0表示边界框的0%，1表示边界框的100%。例如，(0.5,0.5)描述边界框中间的一个点，(1,1)描述边界框右下角的一个点。 |

本例中绘制区域右侧1/2部分超出渐变区域的填充规则默认是用渐变向量末端的颜色值填充了剩余的空间，也可以使用 [SpreadMethod](https://learn.microsoft.com/en-us/dotnet/api/system.windows.media.gradientbrush.spreadmethod?view=windowsdesktop-8.0)属性指定填充规则，该枚举类型定义如下：

| 枚举      | 取值  | 说明                           |
| ------- | --- | ---------------------------- |
| Pad     | 0   | **默认值。**用渐变向量末端的颜色值填充了剩余的空间。 |
| Reflect | 1   | 在相反的方向重复这个渐变，直到空间被填满。        |
| Repeat  | 2   | 渐变沿着原方向重复，直到空间被填满。           |
## Avalonia中使用LinearGradientBrush走的弯路

查看Avalonia的API发现LinearGradientBrush也有`StartPoint`、`EndPoint`和`GradientStops`属性，便照搬了WPF中的代码。
```
<LinearGradientBrush x:Key="linearBrush" StartPoint="0 1" EndPoint="1 0">
    <GradientStop Offset="0.25" Color="#399953" />
    <GradientStop Offset="0.5" Color="#fbb300" />
    <GradientStop Offset="0.75" Color="#d53e33" />
    <GradientStop Offset="1" Color="#377af5" />
</LinearGradientBrush>
<Polygon Fill="{StaticResource linearBrush}" Points="240 19 240 40 220 19"/>
```

结果得到却是填充色为`#377af5`的三角形，通过查询资料得知在Avalonia中`StartPoint`、`EndPoint`要使用百分比的数值，即(0%，100%)。但是在修改为`StartPoint="0% 100%" EndPoint="100% 0%"`后依旧是填充色为`#377af5`的三角形。
我便怀疑是`LinearGradientBrush`写法上依旧有问题或者`Polygon`使用上有问题，于是写了一个矩形测试线性渐变色填充。
```
<Rectangle Width="20" Height="20" Fill="{StaticResource linearBrush}"/>
```
结果得到了线性渐变色填充的矩形。于是可以确定是`Polygon`的使用上不对，根据`Polygon`的填充色`#377af5`，我猜测跟`Polygon`的坐标有关，调整`Polygon`的位置后填充色会发生变化，于是修改`Polygon`的坐标，结果得到了想要的渐变色三角形。
```
<Polygon Fill="{StaticResource linearBrush}" Points="0 0 20 0 20 20" />
```

## 探索求证

经过刚才的一番尝试，我初步推测最初得到的填充色为`#377af5`三角形可能是由于三角形最右侧的点坐标是（240，19），Avalonia绘制了一个边长为240的渐变色正方形，而这个三角形所在的区域颜色刚好是`#377af5`。于是我绘制了一个6行6列共有36个40x40的正方形组成的大正方形。
```
<LinearGradientBrush x:Key="linearBrush" StartPoint="0% 100%" EndPoint="100% 0%">
    <GradientStop Offset="0.25" Color="#399953" />
    <GradientStop Offset="0.5" Color="#fbb300" />
    <GradientStop Offset="0.75" Color="#d53e33" />
    <GradientStop Offset="1" Color="#377af5" />
</LinearGradientBrush>

<Polygon Fill="{StaticResource linearBrush}" Points="0,0 40,0 40,40 0,40" />
<Polygon Fill="{StaticResource linearBrush}" Points="40,0 80,0 80,40 40,40" />
<Polygon Fill="{StaticResource linearBrush}" Points="80,0 120,0 120,40 80,40" />
<Polygon Fill="{StaticResource linearBrush}" Points="120,0 160,0 160,40 120,40" />
<Polygon Fill="{StaticResource linearBrush}" Points="160,0 200,0 200,40 160,40" />
<Polygon Fill="{StaticResource linearBrush}" Points="200,0 240,0 240,40 200,40" />

<Polygon Fill="{StaticResource linearBrush}" Points="0,40 40,40 40,80 0,80" />
<Polygon Fill="{StaticResource linearBrush}" Points="40,40 80,40 80,80 40,80" />
<Polygon Fill="{StaticResource linearBrush}" Points="80,40 120,40 120,80 80,80" />
<Polygon Fill="{StaticResource linearBrush}" Points="120,40 160,40 160,80 120,80" />
<Polygon Fill="{StaticResource linearBrush}" Points="160,40 200,40 200,80 160,80" />
<Polygon Fill="{StaticResource linearBrush}" Points="200,40 240,40 240,80 200,80" />

<Polygon Fill="{StaticResource linearBrush}" Points="0,80 40,80 40,120 0,120" />
<Polygon Fill="{StaticResource linearBrush}" Points="40,80 80,80 80,120 40,120" />
<Polygon Fill="{StaticResource linearBrush}" Points="80,80 120,80 120,120 80,120" />
<Polygon Fill="{StaticResource linearBrush}" Points="120,80 160,80 160,120 120,120" />
<Polygon Fill="{StaticResource linearBrush}" Points="160,80 200,80 200,120 160,120" />
<Polygon Fill="{StaticResource linearBrush}" Points="200,80 240,80 240,120 200,120" />

<Polygon Fill="{StaticResource linearBrush}" Points="0,120 40,120 40,160 0,160" />
<Polygon Fill="{StaticResource linearBrush}" Points="40,120 80,120 80,160 40,160" />
<Polygon Fill="{StaticResource linearBrush}" Points="80,120 120,120 120,160 80,160" />
<Polygon Fill="{StaticResource linearBrush}" Points="120,120 160,120 160,160 120,160" />
<Polygon Fill="{StaticResource linearBrush}" Points="160,120 200,120 200,160 160,160" />
<Polygon Fill="{StaticResource linearBrush}" Points="200,120 240,120 240,160 200,160" />

<Polygon Fill="{StaticResource linearBrush}" Points="0,160 40,160 40,200 0,200" />
<Polygon Fill="{StaticResource linearBrush}" Points="40,160 80,160 80,200 40,200" />
<Polygon Fill="{StaticResource linearBrush}" Points="80,160 120,160 120,200 80,200" />
<Polygon Fill="{StaticResource linearBrush}" Points="120,160 160,160 160,200 120,200" />
<Polygon Fill="{StaticResource linearBrush}" Points="160,160 200,160 200,200 160,200" />
<Polygon Fill="{StaticResource linearBrush}" Points="200,160 240,160 240,200 200,200" />

<Polygon Fill="{StaticResource linearBrush}" Points="0,200 40,200 40,240 0,240" />
<Polygon Fill="{StaticResource linearBrush}" Points="40,200 80,200 80,240 40,240" />
<Polygon Fill="{StaticResource linearBrush}" Points="80,200 120,200 120,240 80,240" />
<Polygon Fill="{StaticResource linearBrush}" Points="120,200 160,200 160,240 120,240" />
<Polygon Fill="{StaticResource linearBrush}" Points="160,200 200,200 200,240 160,240" />
<Polygon Fill="{StaticResource linearBrush}" Points="200,200 240,200 240,240 200,240" />

<Path
    Data="M0,40 L300,40 M0,80 L300,80 M0,120 L300,120 M0,160 L300,160 M0,200 L300,200 M0,240 L300,240 M40,0 L40,300 M80,0 L80,300 M120,0 L120,300 M160,0 L160,300 M200,0 L200,300 M240,0 L240,300"
    Stroke="#ddd"
    StrokeThickness="1" />
```

![AvaloniaLinearGradientBrush1](https://eb19df4.webp.li/2025/02/LinearGradientCompare.png)
结果得到如上图的效果，只是在有限的范围内渐变，而非整个大正方形区域内渐变。尽管和预期的效果不太一样，但依旧可以从中看出一些端倪：
* 对角线上的小正方形中符合预期的渐变色
* 渐变向量起点的颜色值填充了对角线左下方的空间，渐变向量末端的颜色值填充对角线右上方的空间
* 最初得到的填充色为`#377af5`三角形相对于大正方形的区域颜色也是`#377af5`

根据这几点现象结合已有的知识分析推测，线性渐变画刷只作用于第0行0列的小正方形，对角线上的正方形及其两侧相邻的正方形颜色是由于插值算法补充的渐变色，对角线两侧的颜色是如同WPF中SpreadMethod.Pad的填充效果。

到了这里不禁会想，`Points="240 19 240 40 220 19"`的`Polygon`真的没法实现渐变效果吗？Avalonia中`StartPoint`的百分比值能否超过100%？既然这个大正方形由六行六列的小正方形组成，那就把`StartPoint`的百分比值设为600%试试看，结果真的得到了预期的效果。下图是36个40x40的小正方形组成的大正方形和一个240x240的正方形的渐变效果对比，通过取色器抽查，每个坐标点颜色值一致。
![LinearGradientCompare](https://eb19df4.webp.li/2025/02/LinearGradientCompare.png)
到了这里，基本明白了Avalonia中线性画刷的机制，`StartPoint`设置相对值时需要用百分制的数值，与WPF中相对值模式不同的是，Avalonia中相对模式的百分比是基于绘制区域的尺寸，但坐标系统不是基于绘制区域边界，而是基于本地空间(local space)。这或许跟skiasharp的渲染机制有关。

由于相对模式的坐标系统是基于本地空间，这样并没有解决`Points="240 19 240 40 220 19"`的`Polygon`实现渐变效果的需求，继而需要寻求绝对值模式的解决方式。Avalonia中线性画刷是否支持绝对值呢？查阅了以下API，并没有找到`MappingMode`属性，难道真的不支持绝对值模式吗？回想一下，最初`StartPoint`设置为(0,1)是并没有报错，只是结果不是预期的，那看一下36个40x40的小正方形的画刷`StartPoint`设置为(0,1)是什么效果。
![AbsoluteModeLinearGradientBrush](https://eb19df4.webp.li/2025/02/AbsoluteModeLinearGradientBrush.png)
预览界面放大到800%后发现，渐变效果其实也是生效的，这里设置的(0,1)不就是绝对值嘛。当`StartPoint="0 240" EndPoint="240 0"`时，36个小正方形组成的240x240的区域也实现了预期的渐变效果。`StartPoint="220 40" EndPoint="240 19"`时就满足了`Points="240 19 240 40 220 19"`的`Polygon`实现渐变效果的需求。

## 总结

经过一番尝试和分析，对于Avalonia中线性渐变画刷有了基本了解。归纳了以下几点内容：
* Avalonia中线性渐变画刷既支持相对模式，也支持绝对模式。
* `StartPoint`和`EndPoint`的取值为百分比时使用的相对模式，取值为数值则是绝对模式。类似于WPF中设置`MappingMode`
* 相对模式下`StartPoint`和`EndPoint`的百分比值是基于绘制区域的尺寸，但坐标系统是基于本地空间(local space)，而非相对于绘制区域边界。
* Avalonia中线性渐变画刷也支持设置渐变范围以外区域的填充方式，和WPF中一样，通过设置`SpreadMethod`属性实现。