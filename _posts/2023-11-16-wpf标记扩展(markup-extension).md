---
categories:
- WPF
date: 2023-11-16 17:46
last_modified_at: 2025-03-23 12:30:40 +0800
mtime: 2025-03-23 12:30:40
tags:
- WPF
title: WPF标记扩展(Markup Extension)
---

XAML是基于XML的语言，其遵循并扩展了XML的语法规则。其中一项扩展就是标记扩展(Markup Extension)，比如我们经常使用的绑定`Binding`和`x:Type`。

## 什么是标记扩展
标记扩展允许在XAML标记中使用特殊的语法来动态地为特性（Attribute）赋值或执行其他操作。简单来说，在XAML中，所有为XAML元素特性（Attribute）赋值时，使用花括号{}包裹起来的语句就是标记扩展。这么定义不是特别严谨，因为转义序列也是以花括号{}作为标记的，但不是标记扩展。[^1] 后边提到的`x:Array`标记扩展使用的是<>。

标记扩展的语法是`{标记扩展类 参数}`，所有的标记扩展类都是派生自`System.Windows.MarkupExtension`基类实现的。开篇提到的`Binding`和`x:Type`都是WPF框架内置的标记扩展。细心的朋友会发现这两个标记扩展一个带`x:`前缀，一个不带。这就不得不提WPF中的两类标记扩展。
* XAMl定义的标记扩展
* 特定于 WPF 的标记扩展。

### XAML定义的标记扩展
XAML定义的标记扩展在`System.Xaml`程序集中，位于XAML命名空间内，并非WPF特定的实现。这类标记扩展通常由`x:`前缀标识。主要有以下几种：
* `x:Static` 用于引用以符合公共语言规范 (CLS) 的方式定义的任何静态按值代码实体。 可使用引用的静态属性在 XAML 中提供属性的值。
* `x:Type` 为命名类型提供 Type 对象。此扩展最常用于样式和模板。
* `x:Array` 通过标记扩展提供对 XAML 中对象的数组的一般支持。需要注意的是，在 XAML 2009 中，`x:Array`定义为语言基元而不是标记扩展。[^2]
* `x:Null` 将 null 指定为属性的值，可用于特性或属性元素值。

### 特定于WPF的标记扩展
最常见的标记扩展是支持资源引用的标记扩展（StaticResource 和 DynamicResource），和支持数据绑定的标记扩展 (Binding)。特定于WPF的标记扩展有以下几种：[^3]
* `StaticResource` 通过查找对已定义资源的引用，为任何 XAML 属性提供值。 查找该资源的行为类似于加载时查找，将查找当前 XAML 页面先前的标记以及其他应用程序源中加载的资源，并将生成该资源值作为运行时对象中的属性值。**该标记扩展要求引用的资源必须在引用之前声明，否则加载时找不到资源报错。**
* `DynamicResource` 通过将值推迟为对资源的运行时引用来为属性提供值。 动态资源引用强制在每次访问此类资源时都进行新查找。**该标记扩展引用的资源则对声明的位置没有太多要求，因为它在运行的时候采取查找资源。**
* `Binding` 将属性值延迟为数据绑定值，创建中间表达式对象并在运行时解释应用于元素及其绑定的数据上下文。此标记扩展相对复杂，因为它会启用大量内联语法来指定数据绑定。
* `RelativeSource` 在设置 XAML 中创建的 Binding 元素的 RelativeSource 属性时使用。例如嵌套在 Binding 扩展内
```
<object property="{Binding RelativeSource={RelativeSource modeEnumValue} ...}" ... />
```
* `TemplateBinding` 使控件模板能够使用模板化属性的值，这些属性来自于将使用该模板的类的对象模型定义属性。换言之，模板定义中的属性可访问仅在应用了模板之后才存在的上下文。
* `ColorConvertedBitmap` 提供方法来指定没有嵌入配置文件的位图源。 颜色上下文/配置文件由 URI 指定，与图像源 URI 一样。
```
<object property="{ColorConvertedBitmap imageSource sourceIIC destinationIIC}" ... />
```
* `ComponentResourceKey` 定义和引用从外部程序集加载的资源的键。 这使资源查找能够在程序集中指定目标类型，而不是在程序集中或类上指定显式资源字典。
* `ThemeDictionary` 为集成第三方控件的自定义控件创作者或应用程序提供一种方法，用于加载要在设置控件样式时使用的特定于主题的资源字典。
 

## 自定义标记扩展
上文提到所有的标记扩展类都是派生自`System.Windows.MarkupExtension`基类实现的。因此自定义标记扩展也需派生自这个基类。`MarkupExtension`仅提供一个简单的`ProvideValue(IServiceProvider serviceProvider)`方法来获取所期望的数值。接下来用个简单的例子进行说明：
```
public class AddExtension : MarkupExtension
{
    private string _value;

    private string _value1;

    public string Value1
    {
        get => _value1;
        set => _value1 = value;
    }

    public AddExtension()
    {

    }

    public AddExtension(string par)
    {
        _value = par;
    }

    public override object ProvideValue(IServiceProvider serviceProvider)
    {
        if (_value == null) { throw new InvalidOperationException(); }

        int iv, iv1;
        if (int.TryParse(_value, out iv) && int.TryParse(Value1, out iv1))
        {
            return iv + iv1;
        }
        else
            return _value;
    }
}
```
这个自定义的标记扩展定义了一个带参构造函数和一个属性用于接收参数，并通过重写`ProvideValue`方法返回两个参数的和。以下代码是使用该标记扩展的示例。
```
<Button Content="{local:Add 2,Value1=5}"/>
```
根据约定，标记扩展的命名都是以`Extension`结尾，在引用扩展类时可以省略最后一个单词`Extension`，示例中紧跟在`local:Add`后的2是作为构造函数的参数，`Value1=5`则是给标记扩展中定义的属性`Value1`赋值。

## 小结
本文介绍了WPF的基础概念标记扩展，并列举了WPF框架内置了两大类标记扩展。最后用一个不太有实际意义的简单示例展示了如何自定义标记扩展。由于`MarkupExtension`并非派生自`DependencyObject`，因此不能直接定义依赖属性，但可以通过定义一个依赖对象结合附加属性的方式实现扩展标记属性的绑定。

## 参考
[^1]: https://learn.microsoft.com/zh-cn/dotnet/desktop/xaml-services/escape-sequence-markup-extension
[^2]: https://learn.microsoft.com/zh-cn/dotnet/desktop/xaml-services/types-for-primitives
[^3]: https://learn.microsoft.com/zh-cn/dotnet/desktop/wpf/advanced/wpf-xaml-extensions?view=netframeworkdesktop-4.8