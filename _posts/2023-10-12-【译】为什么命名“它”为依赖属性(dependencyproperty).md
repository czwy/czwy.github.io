---
categories:
- 译文
date: 2023-10-12 22:21
last_modified_at: 2025-03-12 22:33:09 +0800
mtime: 2024-07-31 11:19:53
tags:
- 译文
- WPF
title: 【译】为什么命名“它”为依赖属性(DependencyProperty)
---

当我们创建新的类和成员时，我们花费了大量的时间和精力是它们尽可能的好用，好理解，好发现。通常我们会遵循[.Net框架设计指南](https://learn.microsoft.com/en-us/dotnet/standard/design-guidelines/)，尤其是会不断地研究这个新类与其他类，未来计划等内容之间的关系。

当命名依赖属性(DependencyProperty)和依赖对象(DependencyObject)的时候也是遵循这个原则，仅仅讨论如何命名，我们就大概花了几个小时。依赖属性(DPs)最终归结为属性计算和依赖的跟踪。属性计算并不是很特别，很多属性都是这样的，所以DP的本质特征就是依赖的跟踪，因此命名为依赖属性。

这里有一个例子，实际上是一段示例代码，显示了几个依赖跟踪的例子:
``` xml
<StackPanel DataContext="Hello, world" TextBlock.FontSize="22">
    <StackPanel.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="FontWeight" Value="Bold" />
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="Red" />
                </Trigger>
            </Style.Triggers>
        </Style>
    </StackPanel.Resources>
    <TextBlock Text="{Binding}" />
</StackPanel>
```
代码示例中`TextBlock`的属性有不少依赖：
* `TextBlock.Text`依赖于绑定(Binding)，而这里的绑定(Binding)依赖于`DataContext`，`DataContext`是从父元素`StackPanel`继承下来的，因此，`TextBlock.Text`也依赖于树的形状；如果`TextBlock`从`StackPanel`移除，`StackPanel`的值也会发生变化。
* `TextBlock.FontSize`也依赖于树。在这里，你可以看到它从`StackPanel`继承。 
* 所有的`TextBlock`属性都依赖于`TextBlock.style`。例如，这里是`TextBlock.FontWeight`来自样式(Style)。
* 同样的，`TextBlock.Background`也依赖样式(Style)。但在这个示例中，它在触发器(Trigger)中设置。所以`TextBlock.Background`在这种情况下也取决于`TextBlock.IsMouseOver`。

有时，如果编写自己的依赖属性，则需要在跟踪依赖项上做一些辅助。当需要重新计算属性时，可以通过调用`InvalidateProperty`来实现，通常是因为在`CoerceValueCallback`中引用了它。

例如，这里有一个名为`Foo`的依赖属性和一个名为`FooPlus1`的只读依赖属性。`FooPlus1`只是有一个计算“Foo+1”的`CoerceValueCallback`。因此，`Foo`有一个`PropertyChangedCallback`，当`Foo`发生变化时，它会使`FooPlus1`失效。
``` c#
public int Foo
{
    get { return (int)GetValue(FooProperty); }
    set { SetValue(FooProperty, value); }
}

// Using a DependencyProperty as the backing store for Foo.  This enables animation, styling, binding, etc...
public static readonly DependencyProperty FooProperty =
    DependencyProperty.Register("Foo", typeof(int), typeof(Window1), new PropertyMetadata(FooChangedCallback));



static void FooChangedCallback(DependencyObject d, DependencyPropertyChangedEventArgs args)
{
    // Whenever Foo changes, we need to invalidate FooPlus1, so that
    // the DependencyProperty system knows to update it (call its
    // CoerceValueCallback again).
    (d as Window1).InvalidateProperty(Window1.FooPlus1Property);
}

        
public int FooPlus1
{
    get { return (int)GetValue(FooPlus1Property); }
}

static readonly DependencyPropertyKey FooPlus1PropertyKey =
    DependencyProperty.RegisterReadOnly("FooPlus1", typeof(int), typeof(Window1), new PropertyMetadata(0, null, CoerceFooPlus1Callback));

static readonly DependencyProperty FooPlus1Property = FooPlus1PropertyKey.DependencyProperty;

static object CoerceFooPlus1Callback(DependencyObject d, object baseValue)
{
    return (d as Window1).Foo + 1;
}
```

---
原文链接：https://learn.microsoft.com/en-us/archive/blogs/mikehillberg/why-is-it-called-a-dependencyproperty