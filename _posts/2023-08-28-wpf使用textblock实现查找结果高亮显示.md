---
categories:
- WPF
date: 2023-08-28 09:06
last_modified_at: 2025-03-23 12:48:59 +0800
mtime: 2025-03-23 12:48:59
tags:
- WPF
- XAML
title: WPF使用TextBlock实现查找结果高亮显示
---

在应用开发过程中，经常遇到这样的需求：通过关键字查找数据，把带有关键字的数据显示出来，同时在结果中高亮显示关键字。在web开发中，只需在关键字上加一层标签，然后设置标签样式就可以轻松实现。

在WPF中显示文本内容通常采用`TextBlock`控件，也可以采用类似的方式，通过内联流内容元素`Run`达到同样的效果：
```
<TextBlock FontSize="20">
    <Run Text="Hel" /><Run Foreground="Red" Text="lo " /><Run Text="Word" />
</TextBlock>
```
>需要注意的是每个`Run`之间不要换行，如果换行的话，每个`Run`之间会有间隙，看起来像增加了空格。

通过这种方式实现查找结果中高亮关键字，需要把查找结果拆分成三部分，然后绑定到`Run`元素的`Text`属性，或者在后台代码中使用`TextBlock`的`Inlines`属性添加`Run`元素
```
textBlock1.Inlines.Add(new Run("hel"));
textBlock1.Inlines.Add(new Run("lo ") { Foreground=new SolidColorBrush(Colors.Red)});
textBlock1.Inlines.Add(new Run("world"));
```
这种方法虽然可以达到效果，但显然与MVVM的思想不符。接下来本文介绍一种通过附加属性实现`TextBlock`中指定内容高亮。
![TextblockHighlight](https://eb19df4.webp.li/2025/02/TextblockHighlight.gif)

## 技术要点与实现
通过`TextEffect`的`PositionStart`、`PositionCount`以及`Foreground`属性设置字符串中需要高亮内容的起始位置、长度以及高亮颜色。定义附加属性允许`TextBlock`设置需要高亮的内容位置以及颜色。
* 首先定义类`ColoredLettering`(并不要求继承`DependencyObject`)。
* 在`ColoredLettering`中注册自定义的附加属性，注册附加属性方式与注册依赖属性类似，不过附加属性是用`DependencyProperty.RegisterAttached`来注册。
* 给附加属性注册属性值变化事件，事件处理逻辑中设置`TextEffect`的`PositionStart`、`PositionCount`以及`Foreground`实现内容高亮。
```csharp
public class ColoredLettering
{
    public static void SetColorStart(TextBlock textElement, int value)
    {
        textElement.SetValue(ColorStartProperty, value);
    }

    public static int GetColorStart(TextBlock textElement)
    {
        return (int)textElement.GetValue(ColorStartProperty);
    }

    // Using a DependencyProperty as the backing store for ColorStart.  This enables animation, styling, binding, etc...
    public static readonly DependencyProperty ColorStartProperty =
        DependencyProperty.RegisterAttached("ColorStart", typeof(int), typeof(ColoredLettering), new FrameworkPropertyMetadata(0, OnColorStartChanged));

    private static void OnColorStartChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        TextBlock textBlock = d as TextBlock;
        if (textBlock != null)
        {
            if (e.NewValue == e.OldValue) return;
                if (e.NewValue is int)
                {
                    int count = GetColorLength(textBlock);
                    Brush brush = GetForeColor(textBlock);
                    if ((int)e.NewValue <= 0 || count <= 0 || brush == TextBlock.ForegroundProperty.DefaultMetadata.DefaultValue) return;
                    if (textBlock.TextEffects.Count != 0)
                    {
                        textBlock.TextEffects.Clear();
                    }
                    TextEffect textEffect = new TextEffect()
                    {
                        Foreground = brush,
                        PositionStart = (int)e.NewValue,
                        PositionCount = count
                    };
                    textBlock.TextEffects.Add(textEffect);
                }
        }
    }

    public static void SetColorLength(TextBlock textElement, int value)
    {
        textElement.SetValue(ColorLengthProperty, value);
    }

    public static int GetColorLength(TextBlock textElement)
    {
        return (int)textElement.GetValue(ColorLengthProperty);
    }

    // Using a DependencyProperty as the backing store for ColorStart.  This enables animation, styling, binding, etc...
    public static readonly DependencyProperty ColorLengthProperty =
        DependencyProperty.RegisterAttached("ColorLength", typeof(int), typeof(ColoredLettering), new FrameworkPropertyMetadata(0, OnColorLengthChanged));

    private static void OnColorLengthChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        TextBlock textBlock = d as TextBlock;
            if (textBlock != null)
            {
                if (e.NewValue == e.OldValue) return;
                if (e.NewValue is int)
                {
                    int start = GetColorStart(textBlock);
                    Brush brush = GetForeColor(textBlock);
                    if ((int)e.NewValue <= 0 || start <= 0 || brush == TextBlock.ForegroundProperty.DefaultMetadata.DefaultValue) return;
                    if (textBlock.TextEffects.Count != 0)
                    {
                        textBlock.TextEffects.Clear();
                    }
                    TextEffect textEffect = new TextEffect()
                    {
                        Foreground = brush,
                        PositionStart = start,
                        PositionCount = (int)e.NewValue
                    };
                    textBlock.TextEffects.Add(textEffect);
                }
            }
    }

    public static void SetForeColor(TextBlock textElement, Brush value)
    {
        textElement.SetValue(ColorStartProperty, value);
    }

    public static Brush GetForeColor(TextBlock textElement)
    {
        return (Brush)textElement.GetValue(ForeColorProperty);
    }

    // Using a DependencyProperty as the backing store for ForeColor.  This enables animation, styling, binding, etc...
    public static readonly DependencyProperty ForeColorProperty =
        DependencyProperty.RegisterAttached("ForeColor", typeof(Brush), typeof(ColoredLettering), new PropertyMetadata(TextBlock.ForegroundProperty.DefaultMetadata.DefaultValue, OnForeColorChanged));

    private static void OnForeColorChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        TextBlock textBlock = d as TextBlock;
        if (textBlock != null)
        {
            if (e.NewValue == e.OldValue) return;
            if (e.NewValue is Brush)
            {
                int start = GetColorStart(textBlock);
                int count = GetColorLength(textBlock);
                if (start <= 0 || count <= 0) return;
                if (textBlock.TextEffects.Count != 0)
                {
                    textBlock.TextEffects.Clear();
                }
                TextEffect textEffect = new TextEffect()
                {
                    Foreground = (Brush)e.NewValue,
                    PositionStart = start,
                    PositionCount = count
                };
                textBlock.TextEffects.Add(textEffect);
            }
        }
    }
}
```
调用时只需在`TextBlock`指定需要高亮内容的开始位置，内容长度以及高亮颜色即可。
```
<TextBlock local:ColoredLettering.ColorLength="{Binding Count}"
           local:ColoredLettering.ColorStart="{Binding Start}"
           local:ColoredLettering.ForeColor="{Binding ForeColor}"
           FontSize="20"
           Text="Hello World" />
```
## 总结
本文介绍的方法只是高亮第一个匹配到的关键字，如果需要高亮匹配到的所有内容，只需要对附加属性进行改造，以支持传入一组位置和颜色信息。
最后分享一个可以解析一组有限的HTML标记并显示它们的WPF控件[HtmlTextBlock ](https://www.codeproject.com/Articles/33196/WPF-Html-supported-TextBlock)，通过这个控件也可以实现查找结果中高亮关键字，甚至支持指定内容触发事件做一些逻辑操作。