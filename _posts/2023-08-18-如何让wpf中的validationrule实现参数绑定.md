---
categories:
- WPF
date: 2023-08-18 08:43
last_modified_at: 2025-03-23 12:08:30 +0800
mtime: 2025-03-23 12:08:30
tags:
- WPF
- XAML
title: 如何让WPF中的ValidationRule实现参数绑定
---

## 背景
应用开发过程中，常常会对用户输入内容进行验证，通常是基于类型、范围、格式或者特定的要求进行验证，以确保输入符合预期。例如邮箱输入框校验输入内容是否符合邮箱格式。在WPF中，数据模型允许将`ValidationRules`与`Binding`对象关联，可以通过继承`ValidationRule`类并重写`Validate`方法来创建自定义规则。

 ## 问题
尽管创建自定义校验规则可以满足大部分应用场景，但是当我们校验规则是动态变化的时候就有些麻烦了。例如，开发一个文件管理系统，要求文件名不能与系统中已有的文件重名。这个时候需要先获取到系统中已有文件的名称列表，并绑定到`ValidationRule`上。然而`ValidationRule`不是继承于`DepedencyObject`，不能添加依赖属性，自定义的验证规则中的参数不支持绑定。
###解决方案
接下来将给出一个解决方案，让ValidationRule支持参数绑定。思路如下：
首先自定义一个继承DepedencyObject的类ValidationParams，并在其中添加依赖属性用于绑定数据。
```
public class ValidationParams:DependencyObject
{
    public object Data
    {
        get { return (object)GetValue(DataProperty); }
        set { SetValue(DataProperty, value); }
    }

    public static readonly DependencyProperty DataProperty =
        DependencyProperty.Register("Data", typeof(object), typeof(ValidationParams), new PropertyMetadata(null));
}
```
然后在自定义校验规则FileNameValidationRule中添加ValidationParams类型的属性。
```
public class FileNameValidationRule : ValidationRule
{
    public ValidationParams Params { get; set; }

    public override ValidationResult Validate(object value, CultureInfo cultureInfo)
    {
        Regex reg = new Regex("[^()（）a-zA-Z0-9_\u4e00-\u9fa5]");
        if (reg.IsMatch(value.ToString()) || value.ToString().Trim() == "")
            return new ValidationResult(false, "请输入字母、数字、下划线或汉字");
        else if ((Params.Data as List<string>).Contains(value.ToString()))
            return new ValidationResult(false, "名称重复，请修改名称");
        else
            return new ValidationResult(true, null);
    }
}
```
最后在XAML中输入框数据绑定时添加校验规则，并把已有文件的名称列表绑定到校验规则参数中。
```xml
<ctoolkit:WatermarkTextBox x:Name="FileNameWTextBox" Watermark="请输入文件名称" ShowClearButton="True" Width="418" Height="30" HorizontalAlignment="Left" Margin="90,0,0,0">
    <TextBox.Text>
        <Binding Path="FileName" UpdateSourceTrigger="PropertyChanged">
            <Binding.ValidationRules>
                <chelper:FileNameValidationRule>
                    <chelper:FileNameValidationRule.Params>
                        <chelper:ValidationParams Data="{Binding DataContext.ListFileName,ElementName=self}"/>
                    </chelper:FileNameValidationRule.Params>
                </chelper:FileNameValidationRule>
            </Binding.ValidationRules>
        </Binding>
    </TextBox.Text>
</ctoolkit:WatermarkTextBox>
```
然而，事情并没有那么顺利，ValidationParams的Data始终是空的，也就是绑定不成功。这是为什么呢？经过研究发现，FileNameValidationRule并不在可视化树上，无法继承和访问到DataContext，因此绑定失败。

解决这个问题的方法也不太复杂（其实找解决办法也是花了点时间）。思路是利用资源字典和Freezable类。
* 即使不在逻辑树中的对象也可以通过key访问到资源。
* Freezable类的主要目的是定义具有可修改状态和只读状态的对象，但是比较幸运的是这个类的实例不在可视化树或逻辑树中也可以继承到DataContext，目前我也不清楚这里的原理。

根据这两点信息，首先定义一个继承于Freezable的类BindingProxy，包含一个用于绑定数据的依赖属性DataProperty。
```
public class BindingProxy : Freezable
{
    protected override Freezable CreateInstanceCore()
    {
        return new BindingProxy();
    }

    public object Data
    {
        get { return (object)GetValue(DataProperty); }
        set { SetValue(DataProperty, value); }
    }

    // Using a DependencyProperty as the backing store for Data.  This enables animation, styling, binding, etc...
    public static readonly DependencyProperty DataProperty =
        DependencyProperty.Register("Data", typeof(object), typeof(BindingProxy), new PropertyMetadata(null));
}
```
然后在WatermarkTextBox的资源字典中实例化BindingProxy，并绑定已有文件名称列表，然后在校验规则参数ValidationParams的Data中绑定BindingProxy实例。
```xml
<ctoolkit:WatermarkTextBox x:Name="FileNameWTextBox" Watermark="请输入文件名称" ShowClearButton="True" Width="418" Height="30" HorizontalAlignment="Left" Margin="90,0,0,0">
    <ctoolkit:WatermarkTextBox.Resources>
        <chelper:BindingProxy x:Key="FileNamesProxy" Data="{Binding DataContext.ListFileName,ElementName=self}"/>
    </ctoolkit:WatermarkTextBox.Resources>
    //上文中已有代码此处省略...
    <chelper:ValidationParams Data="{Binding Source={StaticResource FileNamesProxy},Path=Data}"/>
    //上文中已有代码此处省略...
</ctoolkit:WatermarkTextBox>
```
## 小结
在WPF中，默认情况下，DataContext是通过可视化树来传递的。父元素的DataContext会自动传递给其子元素，以便子元素可以访问父元素的数据对象。但是，不在可视化树上的对象，无法继承和直接绑定到DataContext。本文的案例也是在这个地方卡壳了，虽然最终解决了这个问题，但是Freezable类如何继承到DataContext的原理还有待研究。