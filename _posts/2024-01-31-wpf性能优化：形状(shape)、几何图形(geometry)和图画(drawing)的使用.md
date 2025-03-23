---
categories:
- WPF
date: 2024-01-31 20:52
last_modified_at: 2025-02-28 12:15:27 +0800
mtime: 2025-02-28 12:15:27
tags:
- WPF
- 性能
title: WPF性能优化：形状(Shape)、几何图形(Geometry)和图画(Drawing)的使用
---

在用户界面技术中，绘图是一个绕不开的话题。WPF提供了多种可根据应用程序要求进行优化的2D图形和图像的处理功能，包括画刷(Brush)、形状(Shape)、几何图形(Geometry)、图画(Drawing)和变换(Transform)等。其中形状(Shape)、几何图形(Geometry)和图画(Drawing)承担了基础的绘图功能，形状(Shape)使用方便简单，但占用资源相对较多，几何图形(Geometry)和图画(Drawing)则更轻量。

## 什么是形状、几何图形和图画
在WPF中，形状(Shape)是专门用于表示直线、椭圆、矩形以及多边形的绘图图元(primitive)，可以绘制到窗口或控件上。几何图形(Geometry)为形状定义了坐标和尺寸等细节（可以理解为只有线条轮廓），不能直接绘制到窗口和控件上。图画(Drawing)在几何图形的基础上增加了绘制图形的笔触、笔触样式和填充细节，也不能直接绘制到窗口和控件上。
### 形状(Shape)
WPF中的形状(Shape)都是派生自FrameworkElement类，所以也是UI元素，提供了布局和事件处理等实用功能，可以像其他元素一样支持事件，可以响应焦点、键盘以及鼠标事件。Shape类是一个抽象类，其自身不能执行任何工作，但定义了绘制轮廓以及填充背景的画刷相关的属性，包括`Fill`、`Stroke`、`StrokeThickness`、`StrokeStartLineCap`、`StrokeDashArray`、`StrokeLineJoin`等。具体的绘制工作由以下几个子类完成：
* **Line** 绘制直线元素，直线是最简单的图形元素，使用X1、Y1两个属性作为起点坐标，X2、Y2两个属性作为终点坐标。Stroke属性设置绘制直线的画刷(Brush),从基类(Shape)继承来的Fill属性不起作用
```
<Line Stroke="#0000ff" StrokeThickness="3" X1="30" X2="70" Y1="150" Y2="150" />
```
* **Rectangle** 绘制矩形的元素，通过笔触(Stroke)绘制矩形边框，使用填充(Fill)绘制背景色，这两个属性至少得设置一个，否则不会绘制矩形。从FrameworkElement继承来的Width和Height属性定义宽和高，默认值为Auto,将填充其可用的宽度或高度。Rectangle类增加了两个属性：RadiusX和RadiusY，通过这两个属性可以设置圆角，甚至可以绘制出椭圆效果。由于Rectangle是闭合的形状，所以从基类(Shape)继承来的StrokeStartLineCap和StrokeEndLineCap属性不起作用。
```
<Rectangle Width="80" Height="60" Fill="AliceBlue"/>
```
* **Ellipse** 绘制椭圆，用法和Rectangle一致，长和宽相等的椭圆即为圆形
```
<Ellipse Width="80" Height="60" Fill="AliceBlue"/>
```
* **Polyline** 绘制折线，有多段首尾相连的直线段组成。通过Points属性提供一些列X和Y坐标。尽管Polyline是非闭合的形状，但是设置了Fill属性时，Points属性中最后一个连接点和开始点形成的不可见虚拟线段与Polyline绘制的折线形成的闭合区间也会被填充。
```
<Polyline Fill="red" FillRule="Nonzero" Points="10,10 10,100 100,100 150,50" Stroke="Blue" StrokeThickness="3"/>
```
* **Polygon** 绘制多边形，与Polyline相似，有多条直线段组成形成闭合区域。与Polyline唯一的区别就是Polygon会把Points属性中最后一个连接点和开始点连接起来。
```
<Polygon Fill="red" FillRule="Nonzero" Points="10,10 10,100 100,100 150,50" Stroke="Blue" />
```
* **Path** 绘制路径，是最为灵活的图形，可以由一个或者若干个直线、圆弧、贝塞尔曲线组成。Path类通过Data属性定义绘制的形状。Data属性的类型是Geometry类，也就是接下来要介绍的几何图形(Geometry)。

### 几何图形(Geometry)
前边提到几何图形(Geometry)为形状定义了坐标和尺寸，但不能直接绘制到窗口和控件上，而Path形状元素的Data属性就是Geometry类，没错，几何图形(Geometry)是与Path形状结合使用的。
与Shape类一样，Geometry类也是抽象类，具体的形状的定义是通过它的子类实现的。Geometry类的子类包括：
* **LineGeometry** 直线几何图形，相当于Line形状。
* **RectangleGeometry** 矩形几何图形，与Rectangle形状一样，可以定义圆角。
* **EllipseGeometry** 椭圆几何图形，相当于Ellipse形状。
* **GeometryGroup** 由多个几何图形(Geometry)组合在一起形成几何图形组，实现为单个路径(Path)添加任意多个几何图形(Geometry)，可以使用EvenOdd或者NonZero填充规则来确定要填充的区域，默认的填充规则是EvenOdd。
* **CombinedGeometry** 将两个几何图形合并为一个形状。可以使用CombineMode属性选择如何组合两个几何图形。
* **PathGeometry** 表示更为复杂的由弧线、曲线以及直线段构成的图形，并且可以是闭合的，也可以是不闭合的。
* **StreamGeometry** 相当于是PathGeometry的只读轻量级类。StreamGeometry的优点是可以节省内存，因为它不在内存中同事保存路径的所有单个分段。缺点是一旦被创建就不能再修改，并且不支持Binding、动画等功能。

`LineGeometry`、`RectangleGeometry`、`EllipseGeometry`与前边介绍的`Line`、`Rectangle`、`Ellipse`形状对应，使用起来也很简单。以矩形为例，使用Rectangle的xaml描述:
```
<Rectangle Width="80" Height="60" Fill="AliceBlue"/>
```
使用Path结合RectangleGeometry的xaml描述为：
```
<Path Fill="AliceBlue">
    <Path.Data>
        <RectangleGeometry Rect="0,0 80,60"/>
    </Path.Data>
</Path>
```
#### GeometryGroup
这样看起来使用几何图形(Geometry)来绘图编码更为繁琐，开篇提到的几何图形(Geometry)更轻量，占用资源更少的优点并没有体现出来。接下来要介绍的`GeometryGroup`则能很好的体现出几何图形(Geometry)更轻量这个优点。
比如绘制一个铜钱这样一个外圆内方的图案，使用形状(Shape)的xaml描述：
```
<Grid>
    <Ellipse Width="50" Height="50" Fill="AliceBlue" Stroke="Blue"/>
    <Rectangle Width="20" Height="20" Stroke="Blue" Fill="Transparent"/>
</Grid>
```
使用`GeometryGroup`的xaml描述：
```
<Path Stroke="Blue" Fill="AliceBlue">
    <Path.Data>
        <GeometryGroup>
            <EllipseGeometry Center="25 25" RadiusX="25" RadiusY="25" />
            <RectangleGeometry Rect="15 15 20 20"/>
        </GeometryGroup>
    </Path.Data>
</Path>
```
上述两种方法实现了类似的视觉效果。第一种方法使用了`Ellipse`和`Rectangle`两个UI元素，而第二种方案只用了一个`Path`元素，这意味减少了一个UI元素的开销。通常，一个包含N个几何图形(Geometry)的形状(Shape)比N个形状(Shape)直接进行绘制图案的性能要好。因为形状(Shape)派生自`FrameworkElement`类，需要维护布局、事件等功能的开销，几何图形(Geometry)则不需要。在只有几十个形状的窗口中这个差距并不明显，但对于需要成百上千个形状的窗口中，这个性能差异就值得考虑了。
> `GeometryGroup`在性能上优于多个形状(Shape)的组合，但是不能为组合中的每个几何图形(Geometry)设置笔触、填充和注册事件，灵活性上稍逊一筹。

#### CombinedGeometry
`GeometryGroup`可以把多个几何图形(Geometry)组合成复杂的图形，但是多个图形的边界存在交叉重叠时，可能无法得到预期的效果。这个时候可以使用`CombinedGeometry`来处理了。`CombinedGeometry`用于把两个重叠在一起的几何图形(Geometry)合并成一个，通过`Geometry1`和`Geometry2`属性提供需要合并的几何图形(Geometry)，尽管`CombinedGeometry`只能合并两个几何图形(Geometry)，但是可以把合并后得到的几何图形(Geometry)与第三个进行合并，以此类推可以实现多个几何图形的合并。`GeometryCombineMode`属性定义了合并的方式，`GeometryCombineMode`枚举有以下四个值:
|名称|说明|
|----|----|
|Union|创建包含两个几何图形所有区域的Geometry|
|Intersect|创建包含两个几何图形共有区域的Geometry|
|Xor|创建包含两个几何图形非共有区域的Geometry。也就是先使用Union合并几何图形，再去掉使用Intersect合并的那部分|
|Exclude|创建的Geometry包含第一个几何图形所有区域，但不包含第二个几何图形的区域|

用数学中集合的概念可以把Union、Intersect、Exclude理解为并集、交集和差集。下图显示了四种合并方式的区别（合并后的图形设置了填充便于表示合并后包含的区域）。
![GeometryCombineMode](https://eb19df4.webp.li/2025/02/GeometryCombineMode.png)

#### PathGeometry
前边几种方式都是以WPF内置的几何图形(Geometry)绘制或者组合来定义形状，`PathGeometry`则提供更小粒度的绘制元素`PathSegment`，`PathSegment`可以表示几何图形中的一段直线、弧线或者贝塞尔曲线，`PathSegment`是一个抽象类，具体的绘制由其派生类实现。
|派生类名称|说明|
|----------|----|
|LineSegment|在PathFigure中的两个点之间创建一条直线。|
|ArcSegment|在PathFigure中的两个点之间创建一条椭圆弧。|
|BezierSegment|在PathFigure中的两个点之间创建一条三次贝塞尔曲线|
|QuadraticBezierSegment|在PathFigure中的两个点之间创建一条二次贝塞尔曲线|
|PolyLineSegment|表示由 PointCollection 定义的线段集合，可用多个LineSegment得到相同效果，但使用单个PolyLineSegment更加简明|
|PolyBezierSegment|创建一条或多条三次贝塞尔曲线|
|PolyQuadraticBezierSegment|创建一条或多条二次贝塞尔曲线|

使用`PathGeometry`创建路径很简单，以`LineSegment`为例。在`PathGeometry`的`PathFigure`属性中设置`StartPoint`作为起点，并增加一个`LineSegment`,其`Point`属性表示该条线段的结束点以及下一条线段的起点。
```
<Path Stroke="Blue">
    <Path.Data>
        <PathGeometry>
            <PathFigure StartPoint="50 100">
                <LineSegment Point="100 100"/>
                <LineSegment Point="100 50"/>
            </PathFigure>
        </PathGeometry>
    </Path.Data>
</Path>
```
如果要绘制多个不连续的线段，则使用`PathFigures`属性，在其中添加多个`PathFigures`即可。
```
<Path Stroke="Blue">
    <Path.Data>
        <PathGeometry>
            <PathGeometry.Figures>
            <PathFigure StartPoint="50 100">
                <LineSegment Point="100 100"/>
                <LineSegment Point="100 50"/>
            </PathFigure>
                <PathFigure StartPoint="150 50">
                    <LineSegment Point="150 100"/>
                    <LineSegment Point="100 150"/>
                </PathFigure>
            </PathGeometry.Figures>
        </PathGeometry>
    </Path.Data>
</Path>
```

#### StreamGeometry
与`PathGeometry`类一样，`StreamGeometry`可以定义包含曲线、弧线和直线的复杂几何图形。与`PathGeometry`不同的是，`StreamGeometry`的内容不支持数据绑定、动画或修改。 当需要描述复杂几何图形，但又不希望产生支持数据绑定、动画或修改的开销时，建议使用 `StreamGeometry`。由于`StreamGeometry`类的高效性，该类是描述装饰器的不错选择。以下是`StreamGeometry`实现与上文中`PathGeometry`绘制多个不连续线段同样效果的代码：
```
<Path Stroke="Blue" Data="M50,100 L100,100 100,50 M150,50 L150,100 100,150"/>
```
在给`Data`属性复制的时候，是使用几何图形微语言(Geometry mini-language)创建了一个`StreamGeometry`。示例中的几何图形微语言包含了6条指令。第一条指令(M50,100)创建了一个PathFigure，并把起点设置为(50,100)，接下来的指令(L100,100 100,50)其实是(L100,100 L100,50)的简写，是创建两个创建直线段并设置每个线段终点的指令。第四条指令(M150,50)创建了一个PathFigure，并把起点设置为(150,50)，接下来的指令是两条创建直线段的指令。

几何图形微语言通常是和`StreamGeometry`一起使用，但并不是`StreamGeometry`的专属。WPF中有两个类可以使用几何图形微语言：`StreamGeometry`和`PathFigureCollection`。在设置`PathGeometry`的`Figures`属性时，可以通过`PathFigureCollection`使用几何图形微语言。
```
<Path Stroke="Blue" >
    <Path.Data>
        <PathGeometry Figures="M50,100 L100,100 100,50 M150,50 L150,100 100,150" />
    </Path.Data>
</Path>
```
### 图画(Drawing)
几何图形(Geometry)为可以描述形状或者路径，图画(Drawing)在几何图形的基础上增加了绘制图形的笔触、笔触样式和填充细节，包含了显示矢量图或者位图的信息。

图画(Drawing)也是抽象类，描述矢量图或者位图的具体工作由其派生类完成。这些类包括
|类名|说明|主要属性|
|----|----|--------|
|GeometryDrawing|使用指定的画刷(Brush)和画笔(Pen)绘制几何图形。|Geometry、Brush、Pen|
|ImageDrawing|使用指定图像（通常是基于文件的位图）和矩形边界绘制图像|ImageSource、Rect|
|VideoDrawing|结合播放视频文件的媒体播放器，使用指定矩形边界绘制（复制）播放器中当前画面|Player、Rect|
|GlyphRunDrawing|表示渲染GlyphRun的绘图对象|GlyphRun、ForegroundBrush|
|DrawingGroup|组合各种类型的图画(Drawing)创建混合图画，并可以使用它的一个属性一次性为整个组合应用效果|BitmapEffect、BitmapEffectInput、Children、ClipGeometry、GuidelineSet、OpacityMask、Opacity、Transform|

与几何图形(Geometry)类似，图画(Drawing)也不能把自身绘制在窗口或者控件上。为了显示图画，WPF提供了以下三个类。
|类|基类|说明|
|--|----|----|
|DrawingImage|ImageSource|使用ImageSource封装图画(Drawing)，从而在Image元素中显示或者作为ImageBrush绘制UI元素|
|DrawingBrush|Brush|使用画刷封装图画(Drawing)，从而作为画刷绘制UI元素|
|DrawingVisual|Visual|允许在低级的可视化对象化中放置图画。|

#### DrawingImage和DrawingBrush
`DrawingImage`和`DrawingBrush`都包含了Drawing属性，从而可以使用更少的资源绘制矢量图或者位图。例如绘制一个关闭按钮，可以先用`PathGeometry`定义一个X的几何图形，然后用这个几何图形为`GeometryDrawing`的`Geometry`属性赋值，紧接着用`DrawingBrush`把`GeometryDrawing`封装为画刷，为按钮的`Background`赋值。
```
<Button Width="16" Height="16" BorderBrush="Transparent">
    <Button.Background>
        <DrawingBrush>
            <DrawingBrush.Drawing>
                <GeometryDrawing Brush="Red">
                    <GeometryDrawing.Geometry>
                        <PathGeometry Figures="M562.281173 510.800685l294.996664-293.466821c13.94971-13.878079 14.020318-36.367279 0.14224-50.316989-13.913894-13.984503-36.367279-14.020318-50.316989-0.14224L512.034792 460.377272 219.528855 166.982082c-13.842263-13.878079-36.367279-13.94971-50.316989-0.071631-13.913894 13.878079-13.948687 36.403095-0.071631 50.352805L461.576587 510.587837 166.721139 803.876604c-13.94971 13.878079-14.020318 36.367279-0.14224 50.316989 6.939039 6.974855 16.084327 10.497075 25.229614 10.497075 9.073656 0 18.148335-3.451612 25.087375-10.354835l294.926056-293.360398 295.17472 296.064996c6.939039 6.974855 16.048511 10.462283 25.193799 10.462283 9.109472 0 18.184151-3.487428 25.12319-10.390651 13.913894-13.878079 13.94971-36.367279 0.071631-50.316989L562.281173 510.800685z"/>
                    </GeometryDrawing.Geometry>
                </GeometryDrawing>
            </DrawingBrush.Drawing>
        </DrawingBrush>
    </Button.Background>
</Button>
```

#### DrawingVisual
`DrawingVisual`是一个轻量级绘图类，用于呈现形状、图像或文本，由于不支持布局、输入、焦点和事件处理，所以绘图性能较好。可用于绘制背景，或者脉冲图。
使用`DrawingVisual`绘图时，需要一个派生自`FrameworkElement`类的对象作为宿主容器来呈现图画。这个宿主容器类负责管理其`DrawingVisual`对象的集合，并通过重写`FrameworkElement`的以下两个属性为WPF提供需要绘制的内容。
* GetVisualChild：从`Visual`对象集合中返回指定索引处的`Visual`对象。
* VisualChildrenCount：获取此元素内可视子元素的数目。
```
public class MyVisualHost : FrameworkElement
{
    // 创建`Visual`对象的集合
    private VisualCollection _children;

    public MyVisualHost()
    {
        _children = new VisualCollection(this);
        _children.Add(CreateDrawingVisualRectangle());
        _children.Add(CreateDrawingVisualText());
        _children.Add(CreateDrawingVisualEllipses());

        // 注册MouseLeftButtonUp事件处理
        this.MouseLeftButtonUp += new System.Windows.Input.MouseButtonEventHandler(MyVisualHost_MouseLeftButtonUp);
    }

    // 重写VisualChildrenCount成员提供此UI元素（宿主容器）内可视子元素的数目.
    protected override int VisualChildrenCount
    {
        get { return _children.Count; }
    }

    // 重写GetVisualChild方法返回指定索引处的`Visual`对象
    protected override Visual GetVisualChild(int index)
    {
        if (index < 0 || index >= _children.Count)
        {
            throw new ArgumentOutOfRangeException();
        }

        return _children[index];
    }
}
```
上面代码中在宿主容器类的构造方法里给`Visual`对象的集合添加了三个`DrawingVisual` 对象。接下来以`CreateDrawingVisualRectangle`为例介绍`DrawingVisual`对象的创建。`DrawingVisual`类没有绘图内容，需要通过`RenderOpen`方法获取`DrawingContext`对象，并在其中进行绘制来添加文本、图形或图像内容，`DrawingContext`提供了绘制直线、矩形、椭圆、文本以及几何图形等一系列方法。用法上和Winform中GDI+绘图比较相似。
```
private DrawingVisual CreateDrawingVisualRectangle()
{
    DrawingVisual drawingVisual = new DrawingVisual();

    DrawingContext drawingContext = drawingVisual.RenderOpen();

    Rect rect = new Rect(new System.Windows.Point(160, 100), new System.Windows.Size(320, 80));
    drawingContext.DrawRectangle(System.Windows.Media.Brushes.LightBlue, (System.Windows.Media.Pen)null, rect);

    drawingContext.Close();

    return drawingVisual;
}
```

## 小结
* 形状(Shape)作为WPF中的UI元素，提供了便捷的绘图功能，以及布局、焦点和事件处理等实用功能，但绘制复杂图形相对繁琐，性能也相对较差。
* 几何图形(Geometry)是与Path形状结合使用，为绘制形状提供了轻量的实现，并通过减少UI元素获得更好的性能，其中使用几何图形微语言创建`StreamGeometry`的方式可以像`PathGeometry`一样实现复杂的图形，并且具有更好的性能。除了绘制形状外，还可以用于设置Clip属性，对任何UI元素进行裁剪。但几何图形(Geometry)只定义了形状（线条轮廓），不能直接作为绘制UI元素的画刷。
* 图画(Drawing)包含了显示矢量图或者位图需要的所有信息，并且可以封装几何图形(Geometry)或者位图作为画刷，为UI元素设置`Background`、`BorderBrush`等属性。`DrawingVisual`作为一个轻量级的图画类，具有较好的性能，在需要大量绘制工作的场景中是一个不错的选择。