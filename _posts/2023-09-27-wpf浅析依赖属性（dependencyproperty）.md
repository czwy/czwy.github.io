---
categories:
- WPF
date: 2023-09-27 22:02
last_modified_at: 2025-03-23 12:42:04 +0800
mtime: 2025-03-23 12:42:04
tags:
- WPF
title: WPF浅析依赖属性（DependencyProperty）
---

在WPF中，引入了依赖属性这个概念，提到依赖属性时通常都会说依赖属性能节省实例对内存的开销。此外依赖属性还有两大优势。
* 支持多属性值，依赖属性系统可以储存多个值，配合Expression、Style、Animation等可以给我们带来很强的开发体验。
* 加入了属性变化通知，限制、验证等功能。方便我们使用少量代码实现以前不太容易实现的功能。

本文将主要介绍依赖属性是如何存取数据的以及多属性值的取值优先级。

## CLR属性

CLR属性是private字段安全访问的封装

对象实例的每个private字段都会占用一定的内存，字段被CLR属性封装起来，每个实例看上去都带有相同的属性，但并不是每个实例的CLR属性都会多占一点内存。因为CLR属性是一个语法糖，本质是Get/Set方法，再多的实例方法也只有一个拷贝。

以TextBlock为例，共有107个属性，但通常使用的最多的属性是Text，FontSize，FontFamily，Foreground这几个属性，大概有100个左右属性是没有使用的。若按照CLR属性分配空间，假设每个属性都封装了一个4Byte的字段，一个5列1000行的列表浪费的空间就是4×100×5×1000≈1.9M。而依赖属性则是省下这些没有用到的属性所需的空间，其关键就在于依赖属性的声明和使用。

## 依赖属性的声明和使用
依赖属性的使用很简单，只需要以下几个步骤就可以实现：
1. 让所在类型直接或间接继承自`DependecyObject`。在WPF中，几乎所有的控件都间接继承自`DependecyObject`。
2. 声明一个静态只读的`DependencyProperty`类型变量，这个静态变量所引用的实例并不是通过new操作符创建，而是使用简单的单例模式通过`DependencyProperty.Register`创建的，下文会对这个方法进行介绍。
3. 使用依赖属性的实例化包装属性读写依赖属性。
按照以上步骤可以写出如下代码：
```
public class ValidationParams:DependencyObject
{
    public object Param1
    {
        get { return (object)GetValue(Param1Property); }
        set { SetValue(Param1Property, value); }
    }

    // Using a DependencyProperty as the backing store for Data.  This enables animation, styling, binding, etc...
    public static readonly DependencyProperty Param1Property =
        DependencyProperty.Register("Param1", typeof(object), typeof(ValidationParams), new PropertyMetadata(null));
}
```
代码中`Param1Property`才是真正的依赖属性，`Param1`是依赖属性的包装器，这里有一个命名约定，依赖属性的名称是对应包装器名称+`Property`组成。在Visual studio中输入`propdp`，然后`Tab`键就会自动生成依赖属性以及包装器的代码片段，然后根据实际情况修改相应的参数和类型。

`Register`方法的第一个参数为string类型，用来指明作为依赖属性包装器的CLR属性；第二个参数指定依赖属性存储什么类型的值，第三个参数指明依赖属性的宿主是什么类型,第四个参数是依赖属性元数据，包含默认值，PropertyChangedCallback，CoerceValueCallback，ValidateValueCallback等委托。

## 依赖属性存取值的机制
从修饰符可以看出依赖属性是一个静态的只读变量，要确保不同实例的依赖属性正确赋值，肯定不能把数据直接保存到这个静态变量中。这里其实也是依赖属性机制的核心。
与依赖属性存取数据有三个关键的类型:`DependencyProperty`、`DependencyObject`、`EffectiveValueEntry`。
* `DependencyProperty`：依赖属性实例都是单例，其中`DefaultMetadata`存储了依赖属性的默认值，提供变化通知、限制、检验等回调以及子类override依赖属性的渠道。`GlobalIndex`用于检索`DependencyProperty`的实例。应用程序中注册的所有`DependencyProperty`的实例都存放于名为`PropertyFromName`的Hashtable中。
* `DependencyObject`：依赖属性的宿主对象，`_effectiveValues`是一个私有的有序数组，用来存储本对象实例中修改过值得依赖属性，`GetValue`、`SetValue`方法用于读写依赖属性的数值。
* `EffectiveValueEntry`：存储依赖属性真实数值的对象。它可以实现多属性值，具体来说就是内部可以存放多个值，根据当前的状态确定对外暴露哪一个值（这里涉及到多个值选取的优先顺序的问题）。
![DependencyProperty](https://eb19df4.webp.li/2025/02/DependencyProperty.png)


前边提到依赖属性实例是使用简单的单例模式通过`DependencyProperty.Register`创建的。通过阅读源码发现，所有的`DependencyProperty.Register`方法重载都是对`DependencyProperty.RegisterCommon`的调用。为了方便介绍，下文只是提取`RegisterCommon`方法中的关键代码
```
private static DependencyProperty RegisterCommon(string name, Type propertyType, Type ownerType, PropertyMetadata defaultMetadata, ValidateValueCallback validateValueCallback)
{
    FromNameKey key = new FromNameKey(name, ownerType);
    .....略去校验以及默认元数据代码

    // Create property
    DependencyProperty dp = new DependencyProperty(name, propertyType, ownerType, defaultMetadata, validateValueCallback);

    // Map owner type to this property
    // Build key
    lock (Synchronized)
    {
        PropertyFromName[key] = dp;
    }

    return dp;
}
```
代码的大致意思是生成一个`FromNameKey`类型的key,然后构造一个`DependencyProperty`实例`dp`，并存放到名为`PropertyFromName`的Hashtable中，最后返回这个实例`dp`。
`FromNameKey`是`DependencyProperty`中的内部私有类，其代码如下：
```
private class FromNameKey
{
    public FromNameKey(string name, Type ownerType)
    {
        _name = name;
        _ownerType = ownerType;
        _hashCode = _name.GetHashCode() ^ _ownerType.GetHashCode();
    }

    public override int GetHashCode()
    {
        return _hashCode;
    }
    ...略去部分代码
    private string _name;
    private Type _ownerType;
    private int _hashCode;
}
```
这里特地介绍这个类是因为`FromNameKey`对象是依赖属性实例的key，它的hashcode是由`Register`的第一个参数（依赖属性包装器属性名称字符串）的hashcode和第三个参数（依赖属性宿主类型）的hashcode做异或运算得来的，这样设计确保了每个`DependecyObject`类型中不同名称的依赖属性的实例是唯一的。

接下来就是使用（读写）依赖属性了，前边提到`DependecyObject`中提供了`GetValue`、`SetValue`方法用于读写依赖属性。先看下`GetValue`方法，代码如下：
```
public object GetValue(DependencyProperty dp)
{
    // Do not allow foreign threads access.
    // (This is a noop if this object is not assigned to a Dispatcher.)
    //
    this.VerifyAccess();

    ArgumentNullException.ThrowIfNull(dp);

    // Call Forwarded
    return GetValueEntry(
            LookupEntry(dp.GlobalIndex),
            dp,
            null,
            RequestFlags.FullyResolved).Value;
}
```
方法前几行是线程安全性和参数有效性检测，最后一行是获取依赖属性的值。`LookupEntry`是根据`DependencyProperty`实例的`GlobalIndex`在`_effectiveValues`数组中查找依赖属性的有效值`EffectiveValueEntry`，找到后返回其索引对象`EntryIndex`。`EntryIndex`主要包含`Index`和`Found`两个属性，`Index`表示查找到的索引值，`Found`表示是否找到目标元素。

`GetValueEntry`根据`LookupEntry`方法返回的`EntryIndex`实例查找有效值`EffectiveValueEntry`。如果`entryIndex.Found`为true，则根据`Index`返回`_effectiveValues`中的元素，否则new一个`EffectiveValueEntry`实例。

`SetValue`方法也是先通过`GetValueEntry`查找有效值对象，找到则修改旧数据，反之则new一个`EffectiveValueEntry`实例赋值，并添加到`_effectiveValues`中。

至此，我们也大致了解了依赖属性存取值的秘密。`DependencyProperty`并不保存实际数值，而是通过其`GlobalIndex`属性来检索属性值。每一个`DependencyObject`对象实例都有一个`EffectiveValueEntry`数组，保存着已赋值的依赖属性的数据，当要读取某个依赖属性的值时，会在这个数组中去检索，如果没有检索到，会从`DependencyProperty`保存的DefaultMetadata中读取默认值（这里只是简单的描述这个过程，真实情况还涉及到元素的style、Theme、父节点的值等）。

## 依赖属性值的优先级
前边提到依赖属性支持多属性值，WPF中可以通过多种方法为一个依赖项属性赋值，如通过样式、模板、触发器、动画等为依赖项属性赋值的同时，控件本身的声明也为属性进行了赋值。在这种情况下，WPF只能选择其中的一种赋值作为该属性的取值，这就涉及到取值的优先级问题。
从上一小节的图中可以看到`EffectiveValueEntry`中有两个属性：`ModifiedValue`和`BaseValueSourceInternal`，`ModifiedValue`用于跟踪依赖属性的值是否被修改以及被修改的状态。`BaseValueSourceInternal`是一个枚举，它用于表示依赖属性的值是从哪里获取的。在与`ModifiedValue`一起使用，可以确定最终呈现的属性值。
`EffectiveValueEntry`中`GetFlattenedEntry`方法中以下代码及注释可以看出强制值>动画值>表达式值这样得优先级
```
internal EffectiveValueEntry GetFlattenedEntry(RequestFlags requests)
{
    ......略去部分代码

    // Note that the modified values have an order of precedence
    // 1. Coerced Value (including Current value)
    // 2. Animated Value
    // 3. Expression Value
    // Also note that we support any arbitrary combinations of these
    // modifiers and will yet the precedence metioned above.
    if (IsCoerced)
    {
        ......略去部分代码
    }
    else if (IsAnimated)
    {
        ......略去部分代码
    }
    else
    {
        ......略去部分代码
    }
    return entry;
}
```
其中表达式值包含样式、模板、触发器、主题、控件本身对属性赋值或者绑定表达式。其优先级则是在`BaseValueSourceInternal`中定义的。枚举元素排列顺序与取值优先级顺序刚好相反。
```
// Note that these enum values are arranged in the reverse order of
// precendence for these sources. Local value has highest
// precedence and Default value has the least. Note that we do not
// store default values in the _effectiveValues cache unless it is
// being coerced/animated.
[FriendAccessAllowed] // Built into Base, also used by Core & Framework.
internal enum BaseValueSourceInternal : short
{
    Unknown                 = 0,
    Default                 = 1,
    Inherited               = 2,
    ThemeStyle              = 3,
    ThemeStyleTrigger       = 4,
    Style                   = 5,
    TemplateTrigger         = 6,
    StyleTrigger            = 7,
    ImplicitReference       = 8,
    ParentTemplate          = 9,
    ParentTemplateTrigger   = 10,
    Local                   = 11,
}
```
综合起来依赖属性取值优先级列表如下：
1. 强制：在`CoerceValueCallback`对依赖属性约束的强制值。
2. 活动动画或具有Hold行为的动画。
3. 本地值：通过CLR包装器调用`SetValue`设置的值，或者XAML中直接对元素本身设置值（包括`binding`、`StaticResource`、`DynamicResource`）
4. TemplatedParent模板的触发器
5. TemplatedParent模板中设置的值
6. 隐式样式
7. 样式触发器
8. 模板触发器
9. 样式
10. 主题样式的触发器
11. 主题样式
12. 继承。这里的继承Inherited是xaml树中的父元素，要区别于面向对象语言子类继承（derived，译为派生更合适）与父类
13. 依赖属性元数据中的默认值

WPF对依赖属性的优先级支持分别使用了`ModifiedValue`和`BaseValueSourceInternal`，大概是因为约束强制值和动画值是临时性修改，希望在更改结束后能够恢复依赖属性原有值。而对于样式、模板、触发器、主题这些来说相对固定，不需要像动画那样结束后恢复原来的值。

## 总结
依赖属性是WPF中一个非常核心的概念，涉及的知识点也非常多。像`RegisterReadOnly`、`PropertyMetadata`、`OverrideMetadata`、`AddOwner`都能展开很多内容。要想真正掌握依赖属性，这些都是需要熟悉的。