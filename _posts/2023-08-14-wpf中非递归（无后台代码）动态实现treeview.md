---
categories:
- WPF
date: 2023-08-14 19:40
last_modified_at: 2025-03-23 12:54:56 +0800
mtime: 2025-03-23 12:54:56
tags:
- WPF
- XAML
title: WPF中非递归（无后台代码）动态实现TreeView
---

在UI界面中，树形视图是比较常用的表示层级结构的方式，WPF中提供了TreeView控件。对于TreeView控件的基本使用已经有很多文章。大都是介绍如何在XAML中使用硬编码的固定信息填充Treeview控件，或者是后台代码递归遍历数据源，动态创建TreeView。这里我想介绍一下如何只通过XAML标记，不用一行后台代码遍历数据实现TreeView。

## 技术要点与实现
本文的技术关键点是层级式数据模板`HierarchicalDataTemplate`。`HierarchicalDataTemplate`是一个特殊的`DataTemplate`，它能够包装第二层模板。通过ItemsSource属性查找下一层级的数据集合，并将它提供给第二层模板。这样描述可能有点晦涩。接下来举例进行描述。

首先假设一个应用场景。用树形结构展现一个地区所有的学校->年级->班级->学生。首先定义几个Model
```
public class School : ObservableObject
{
    private bool _isOpen;
    /// <summary>
    /// 获取或设置是否展开
    /// </summary>
    [System.Xml.Serialization.XmlIgnore]
    public bool IsOpen { get { return _isOpen; } set { Set(ref _isOpen, value); } }

    private bool _isSelected;
    /// <summary>
    /// 获取或设置是否被选中
    /// </summary>
    [System.Xml.Serialization.XmlIgnore]
    public bool IsSelected { get { return _isSelected; } set { Set(ref _isSelected, value); } }
    
    public string SchoolID { get; set; }
    public string SchoolName { get; set; }
    public ObservableCollection<Grade> listGrade { get; set; }=new ObservableCollection<Grade>() { };
}

public class Grade : ObservableObject
{
    private bool _isOpen;
    [System.Xml.Serialization.XmlIgnore]
    public bool IsOpen { get { return _isOpen; } set { Set(ref _isOpen, value); } }

    private bool _isSelected;
    [System.Xml.Serialization.XmlIgnore]
    public bool IsSelected { get { return _isSelected; } set { Set(ref _isSelected, value); } }
    
    public string GradeID { get; set; }
    public string GradeName { get; set; }
    public ObservableCollection<ClassInfo> ListClass { get; set; }=new ObservableCollection<ClassInfo>() { };
}

public class ClassInfo : ObservableObject
{
    private bool _isOpen;
    [System.Xml.Serialization.XmlIgnore]
    public bool IsOpen { get { return _isOpen; } set { Set(ref _isOpen, value); } }

    private bool _isSelected;
    [System.Xml.Serialization.XmlIgnore]
    public bool IsSelected { get { return _isSelected; } set { Set(ref _isSelected, value); } }

    public string ClassID { get; set; }
    public string ClassName { get; set; }
    public ObservableCollection<Student> Students { get; set; }= new ObservableCollection<Student>() { };

}

public class Student : ObservableObject
{
    private bool _isSelected;
    [System.Xml.Serialization.XmlIgnore]
    public bool IsSelected { get { return _isSelected; } set { Set(ref _isSelected, value); } }

    public string Id { get; set; }
    public string Name { get; set; }
}
```
接下来根据定义好的Model定义层级式数据模板`HierarchicalDataTemplate`。
```
<HierarchicalDataTemplate DataType="{x:Type local:School}" ItemsSource="{Binding Path=listGrade}">
    <TextBlock Text="{Binding Path=SchoolName}" />
</HierarchicalDataTemplate>

<HierarchicalDataTemplate DataType="{x:Type local:Grade}" ItemsSource="{Binding Path=ListClass}">
    <TextBlock Text="{Binding Path=GradeName}" />
</HierarchicalDataTemplate>

<HierarchicalDataTemplate DataType="{x:Type local:ClassInfo}" ItemsSource="{Binding Path=Students}">
    <TextBlock Text="{Binding Path=ClassName}" />
</HierarchicalDataTemplate>

<HierarchicalDataTemplate DataType="{x:Type local:Student}">
    <CheckBox Command="{Binding SelectChangeCommand, ElementName=self}" CommandParameter="{Binding}" IsChecked="{Binding IsSelected}">
        <TextBlock Text="{Binding Path=Name}" />
    </CheckBox>
</HierarchicalDataTemplate>
```
其中最外层数据类型是`School`，它的下一层数据集合是`ObservableCollection<Grade> listGrade`，因此`HierarchicalDataTemplate`中的`ItemsSource`赋值为`listGrade`,这里我们再属性控件中只显示学校的名称，因此数据模板只是包含绑定了学校名称`SchoolName`的`TextBlock`，如果需要显示其他信息（比如学校年级数量或者学校图标），只需增加相应XAML元素即可。紧接着按照这个方式定义好数据类型`Grade`,`ClassInfo`,`Student`的层级式数据模板即可。
定义好了数据模型和相应的层级式数据模板`HierarchicalDataTemplate`后，就可以直接把数据元绑定到`TreeView`上了。假设要绑定的数据源实例是`ObservableCollection<School> schools`。只需如下调用即可。

```
<TreeView MaxHeight="480"
            ItemsSource="{Binding schools}"
            VirtualizingPanel.IsVirtualizing="True"
            VirtualizingPanel.VirtualizationMode="Recycling" />
```
这样使用`TreeView`是不是特别方便简洁。不用为了展示树形结构，特地定义一个递归类型的数据结构，UI展示全部交给XAML就行。JSON数据反序列化后直接绑定即可(XML或者DateSet也是类似的方法)。避免了递归遍历数据源的操作，也不用考虑递归带来的性能问题。

## 性能
前边提到不用考虑递归带来的性能问题。那本文介绍的方法对于大量数据的情况下性能到底怎样呢？接下来做一个测试，模拟100W的数据量，具体为240个学校，每个学校3个年级，每个年级20个班，每个班70个学生，总共数据量是240x3x20x70=1008000个。以下是测试结果：
![TreeViewSample](https://eb19df4.webp.li/2025/02/TreeViewSample.gif)

从图中可以看到模拟100w数据耗时1.5s，内存增加了160M左右，数据渲染到界面不到1s，内存增加20M左右。结果还是令人满意的。这是因为`TreeView`支持开启虚拟化（默认是关闭的，设置` VirtualizingPanel.IsVirtualizing="True"`开启虚拟化），渲染界面是不会一次把所有UI元素全部创建好，而是根据屏幕上可见区域计算需要渲染的元素个数，创建少量的UI元素，从而减少内存和CPU资源的使用。例如本例中有100w条数据，可见区能显示20条，TreeView只创建了41个UI元素。为什么不是创建20个呢？这是由于为了确保良好的滚动性能，实际会多创建一些UI元素。
> `TreeView` 默认关闭虚拟化，是因为早期的WPF发布版本中的VirtualizingStackPanel不支持层次化数据，虽然现在已支持，但是`TreeView`默认关闭虚拟化确保兼容性。