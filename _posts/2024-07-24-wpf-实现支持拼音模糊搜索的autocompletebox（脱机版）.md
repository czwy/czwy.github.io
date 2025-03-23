---
categories:
- WPF
date: 2024-07-24 14:22
last_modified_at: 2025-03-23 13:28:25 +0800
mtime: 2025-03-23 12:29:29
tags:
- WPF
title: WPF 实现支持拼音模糊搜索的AutoCompleteBox（脱机版）
---

AutoCompleteBox是一个常见的提高输入效率的组件，很多WPF的第三方控件库都提供了这个组件，但基本都是字符串的子串匹配，不支持拼音模糊匹配，例如无法通过输入`ldh`或`liudehua`匹配到`刘德华`。要实现拼音模糊搜索功能，通常会采用分词、数据库等技术对待匹配数据集进行预处理。某些场景受制于条件限制，无法对数据进行预处理，本文将介绍在这种情况下如何实现支持拼音模糊搜索的AutoCompleteBox，先来看下实现效果。
![fuzzyMatch](https://eb19df4.webp.li/2025/02/fuzzyMatch.gif)
## 主要思路
WPF中并没有AutoCompleteBox控件，我们可以使用`TextBox`输入搜索内容，用`Popup`+`ListBox`显示匹配到的提示内容。拼音模糊匹配汉字则采用字符串匹配的方式来解决，也就是搜索字符串和待匹配数据集的内容全部转换为拼音字符串，然后进行子串匹配。这里有三个问题需要解决。
1. **汉字转换为拼音。** 
2. **拼音如何匹配。** 例如`ldh`、`lidh`、`ldhua`、`liudehua`、`dhua`、`hua`等都能匹配到`刘德华`
3. **匹配后的内容高亮显示。** 当输入`dhua`匹配到`刘德华`时需要把`德华`两个字高亮。

## 汉字转换拼音
微软为了开发者实现国际化语言的互转，提供了Microsoft Visual Studio International Pack，这个扩展包里面有中文、日文、韩文、英语等各国语言包，并提供方法实现互转、获取拼音、获取字数、甚至获取笔画数等等。下载[Microsoft Visual Studio International Pack 1.0 SR1](http://www.microsoft.com/zh-cn/download/details.aspx?id=15251)安装后，在安装目录中找到`ChnCharInfo.dll`，然后在项目中添加引用。
`ChnCharInfo.dll`获取汉字的拼音时只能传入单个字符，因此只能把汉字字符串拆分成一个个字符处理，由于汉字存在多音字情况以及缺少语义信息，获取的拼音组合可能是多个，例如输入`长江`，返回的是`changjiang`和`zhangjiang`。汉字转拼音的方法如下：
``` c#
/// <summary>
/// 获取汉字拼音
/// </summary>
/// <param name="str">待处理包含汉字的字符串</param>
/// <param name="split">拼音分隔符</param>
/// <returns></returns>
public static List<string> GetChinesePhoneticize(string str, string split = "")
{
    List<string> result = new List<string>();
    char[] chs = str.ToCharArray();
    Dictionary<int, List<string>> totalPhoneticizes = new Dictionary<int, List<string>>();
    for (int i = 0; i < chs.Length; i++)
    {
        var phoneticizes = new List<string>();
        if (ChineseChar.IsValidChar(chs[i]))
        {
            ChineseChar cc = new ChineseChar(chs[i]);
            phoneticizes.AddRange(cc.Pinyins.Where(r => !string.IsNullOrWhiteSpace(r)).ToList<string>().ConvertAll(p => Regex.Replace(p, @"\d", "").ToLower()).Distinct());
        }
        else
        {
            phoneticizes.Add(chs[i].ToString());
        }
        if (phoneticizes.Any())
            totalPhoneticizes[i] = phoneticizes;
    }

    foreach (var phoneticizes in totalPhoneticizes)
    {
        var items = phoneticizes.Value;
        if (result.Count <= 0)
        {
            result = items;
        }
        else
        {
            var newtotalPhoneticizes = new List<string>();
            foreach (var totalPingYin in result)
            {
                newtotalPhoneticizes.AddRange(items.Select(item => totalPingYin + split + item));
            }
            newtotalPhoneticizes = newtotalPhoneticizes.Distinct().ToList();
            result = newtotalPhoneticizes;
        }
    }
    return result;
}
```

## 拼音匹配算法
汉字转换后的拼音字符串有多组，只要搜索字符串转换的拼音组合有一组与待匹配字符串转换的拼音组合中匹配，则认为匹配成功，为了后续高亮显示，需要记录下匹配的起始位置以及匹配的子串长度。代码如下：
``` c#
public static bool fuzzyMatchChar(string character, string input, out int matchStart, out int matchCount)
{
    List<string> regexs = GetChinesePhoneticize(input);
    List<string> targetStr = GetChinesePhoneticize(character, " ");
    matchStart = -1;
    matchCount = 0;
    foreach (string regex in regexs)
    {
        foreach (string target in targetStr)
        {
            if (PhoneticizeMatch(regex, target.Split(' '), out matchStart, out matchCount))
                return true;
        }
    }
    return false;
}
```

这里的`PhoneticizeMatch`方法是拼音匹配算法的核心，是在[【算法】拼音匹配算法](https://www.cnblogs.com/bomo/archive/2012/12/02/2798229.html)这篇博文中算法的基础上稍作修改，详细的思路及图解可阅读这篇博文。

## 高亮匹配的子串
WPF中可以通过`TextEffect`的`PositionStart`、`PositionCount`以及`Foreground`属性设置字符串中需要高亮内容的起始位置、长度以及高亮颜色。前面拼音匹配算法中获取了匹配成功子串的起始位置和长度，也正是为此做准备。之前在<a href="/posts/wpf使用textblock实现查找结果高亮显示/">WPF使用TextBlock实现查找结果高亮显示</a>一文中有详细介绍思路和代码，此处不再赘述。

## 小结
本文介绍了在不依赖数据库及分词的情况下如何实现拼音模糊搜索并在目标字符串中高亮显示，方法中也存在诸多不足需要完善的地方。
1. 匹配策略存在误匹配。例如输入`石`，可以匹配出拼音为`shi`的所有汉字。
2. 匹配算法效率不够高。测试过程中，待匹配数据集中模拟了500条数据，匹配耗时大概在400~500ms左右。