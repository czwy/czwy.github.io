---
categories:
- WPF
date: 2023-08-10 19:43
last_modified_at: 2025-03-23 12:43:53 +0800
mtime: 2025-03-23 12:43:53
tags:
- WPF
- XAML
title: WPF实现类似ChatGPT的逐字打印效果
---

## 背景
前一段时间ChatGPT类的应用十分火爆，这类应用在回答用户的问题时逐字打印输出，像极了真人打字回复消息。出于对这个效果的兴趣，决定用WPF模拟这个效果。
>真实的ChatGPT逐字输出效果涉及其语言生成模型原理以及服务端与前端通信机制，本文不做过多阐述，重点是如何用WPF模拟这个效果。


## 技术要点与实现
对于这个逐字输出的效果，我想到了两种实现方法:
* **方法一**：根据字符串长度n，添加n个关键帧`DiscreteStringKeyFrame`，第一帧的`Value`为字符串的第一个字符，紧接着的关键帧都比上一帧的`Value`多一个字符，直到最后一帧的`Value`是完整的目标字符串。实现效果如下所示：
![TypedEffectwithDiscreteStringKeyFrame](https://eb19df4.webp.li/2025/02/TypedEffectwithDiscreteStringKeyFrame.gif)
* **方法二**：首先把`TextBlock`的字体颜色设置为透明，然后通过`TextEffect`的`PositionStart`和`PositionCount`属性控制应用动画效果的子字符串的起始位置以及长度，同时使用`ColorAnimation`设置`TextEffect`的`Foreground`属性由透明变为目标颜色（假定是黑色）。实现效果如下所示：
![TypedEffectwithColorAnimation](https://eb19df4.webp.li/2025/02/TypedEffectwithColorAnimation.gif)

由于方案二的思路与<a href="/posts/wpf实现跳动的字符效果/">WPF实现跳动的字符效果</a>中的效果实现思路非常类似，具体实现不再详述。接下来我们看一下方案一通过关键帧动画拼接字符串的具体实现。
```
public class TypingCharAnimationBehavior : Behavior<TextBlock>
{
    private Storyboard _storyboard;

    protected override void OnAttached()
    {
        base.OnAttached();

        this.AssociatedObject.Loaded += AssociatedObject_Loaded; ;
        this.AssociatedObject.Unloaded += AssociatedObject_Unloaded;
        BindingOperations.SetBinding(this, TypingCharAnimationBehavior.InternalTextProperty, new Binding("Tag") { Source = this.AssociatedObject });
    }

    private void AssociatedObject_Unloaded(object sender, RoutedEventArgs e)
    {
        StopEffect();
    }

    private void AssociatedObject_Loaded(object sender, RoutedEventArgs e)
    {
        if (IsEnabled)
            BeginEffect(InternalText);
    }

    protected override void OnDetaching()
    {
        base.OnDetaching();

        this.AssociatedObject.Loaded -= AssociatedObject_Loaded;
        this.AssociatedObject.Unloaded -= AssociatedObject_Unloaded;
        this.ClearValue(TypingCharAnimationBehavior.InternalTextProperty);

        if (_storyboard != null)
        {
            _storyboard.Remove(this.AssociatedObject);
            _storyboard.Children.Clear();
        }
    }

    private string InternalText
    {
        get { return (string)GetValue(InternalTextProperty); }
        set { SetValue(InternalTextProperty, value); }
    }

    private static readonly DependencyProperty InternalTextProperty =
    DependencyProperty.Register("InternalText", typeof(string), typeof(TypingCharAnimationBehavior),
    new PropertyMetadata(OnInternalTextChanged));

    private static void OnInternalTextChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var source = d as TypingCharAnimationBehavior;
        if (source._storyboard != null)
        {
            source._storyboard.Stop(source.AssociatedObject);
            source._storyboard.Children.Clear();
        }
        source.SetEffect(e.NewValue == null ? string.Empty : e.NewValue.ToString());
    }

    public bool IsEnabled
    {
        get { return (bool)GetValue(IsEnabledProperty); }
        set { SetValue(IsEnabledProperty, value); }
    }

    public static readonly DependencyProperty IsEnabledProperty =
        DependencyProperty.Register("IsEnabled", typeof(bool), typeof(TypingCharAnimationBehavior), new PropertyMetadata(true, (d, e) =>
        {
            bool b = (bool)e.NewValue;
            var source = d as TypingCharAnimationBehavior;
            source.SetEffect(source.InternalText);
        }));

    private void SetEffect(string text)
    {
        if (string.IsNullOrEmpty(text) || this.AssociatedObject.IsLoaded == false)
        {
            StopEffect();
            return;
        }

        BeginEffect(text);

    }

    private void StopEffect()
    {
        if (_storyboard != null)
        {
            _storyboard.Stop(this.AssociatedObject);
        }
    }

    private void BeginEffect(string text)
    {
        StopEffect();

        int textLength = text.Length;
        if (textLength < 1  || IsEnabled == false) return;

        if (_storyboard == null)
            _storyboard = new Storyboard();
        double duration = 0.15d;

        StringAnimationUsingKeyFrames frames = new StringAnimationUsingKeyFrames();

        Storyboard.SetTargetProperty(frames, new PropertyPath(TextBlock.TextProperty));

        frames.Duration = TimeSpan.FromSeconds(textLength * duration);

        for(int i=0;i<textLength;i++)
        {
            frames.KeyFrames.Add(new DiscreteStringKeyFrame()
            {
                Value = text.Substring(0,i+1),
                KeyTime = TimeSpan.FromSeconds(i * duration),
            });
        }

        _storyboard.Children.Add(frames);
        _storyboard.Begin(this.AssociatedObject, true);
    }
}
```
由于每一帧都在修改`TextBlock`的`Text`属性的值，如果`TypingCharAnimationBehavior`直接绑定`TextBlock`的`Text`属性，当`Text`属性的数据源发生变化时，无法判断是关键帧动画修改的，还是外部数据源变化导致`Text`的值被修改。因此这里用`TextBlock`的`Tag`属性暂存要显示的字符串内容。调用的时候只需要把需要显示的字符串变量绑定到`Tag`，并在TextBlock添加Behavior即可，代码如下：
```
<TextBlock x:Name="source"
            IsEnabled="True"
            Tag="{Binding TypingText, ElementName=self}"
            TextWrapping="Wrap">
    <i:Interaction.Behaviors>
        <local:TypingCharAnimationBehavior IsEnabled="True" />
    </i:Interaction.Behaviors>
</TextBlock>
```
## 小结
两种方案各有利弊：
* 关键帧动画拼接字符串这个方法的优点是最大程度还原了逐字输出的过程，缺点是需要额外的属性来辅助，另外遇到英文单词换行时，会出现单词从上一行行尾跳到下一行行首的问题；
* 通过`TextEffect`设置字体颜色这个方法则相反，不需要额外的属性辅助，并且不会出现单词在输入过程中从行尾跳到下一行行首的问题，开篇中两种实现方法效果图中能看出这一细微差异。但是一开始就把文字都渲染到界面上，只是通过透明的字体颜色骗过用户的眼睛，逐字改变字体颜色模拟逐字打印的效果。