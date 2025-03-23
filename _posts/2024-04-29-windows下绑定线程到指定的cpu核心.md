---
categories:
- windows
date: 2024-04-29 17:35
last_modified_at: 2025-02-28 11:14:10 +0800
mtime: 2025-02-28 11:14:10
tags:
- windows
title: Windows下绑定线程到指定的CPU核心
---

在某些场景下，需要把程序绑定到指定CPU核心提高执行效率。通过[微软官方文档](https://learn.microsoft.com/zh-cn/windows/win32/procthread/process-and-thread-functions)查询到Windows提供了两个Win32函数：[**SetThreadAffinityMask**](https://learn.microsoft.com/zh-cn/windows/desktop/api/WinBase/nf-winbase-setthreadaffinitymask)和[**SetProcessAffinityMask**](https://learn.microsoft.com/zh-cn/windows/desktop/api/WinBase/nf-winbase-setprocessaffinitymask) 为指定线程和进程设置处理器关联掩码。通俗的讲就是在指定的CPU核心上执行线程或者进程。

> 这里的CPU核心指的是逻辑核心，而非物理核心。
## SetThreadAffinityMask

SetThreadAffinityMask用于设置指定线程的处理器关联掩码，从而实现线程对处理器的绑定。
### SetThreadAffinityMask函数定义
SetThreadAffinityMask的定义如下：
``` c++
DWORD_PTR SetThreadAffinityMask(
  [in] HANDLE    hThread,
  [in] DWORD_PTR dwThreadAffinityMask
);
```
从函数的定义看需要传递两个参数：
* **hThread**：指向要设置处理器关联的线程句柄。如果是想设置当前线程的关联掩码，可以使用 GetCurrentThread() 函数获取句柄。
* **dwThreadAffinityMask**：处理器的关联掩码。是一个DWORD_PTR类型的值，长度共8个字节（64bit），每一bit代表一个cpu核。

> 如果需要支持超过64核的CPU时，则需要使用[**SetThreadGroupAffinity**](https://learn.microsoft.com/zh-cn/windows/win32/api/processtopologyapi/nf-processtopologyapi-setthreadgroupaffinity)函数

为了更清晰的表达`dwThreadAffinityMask`的含义，下边用二进制数表示该值。比如，需要把线程绑定到
第0个核：则dwThreadAffinityMask=0B_0001;（0x01）
第1个核：则dwThreadAffinityMask=0B_0010;（0x02）
第2个核：则dwThreadAffinityMask=0B_0100;（0x04）
第3个核：则dwThreadAffinityMask=0B_1000;（0x08）
……
如果要绑定到多个cpu核心，比如绑定到第1和2个cpu核时，dwThreadAffinityMask=0B_0110，对应的十六进制数也就是0x06。

### 调用示例
首先引入Win32API
```
[DllImport("kernel32.dll")]
static extern UIntPtr SetThreadAffinityMask(IntPtr hThread, UIntPtr dwThreadAffinityMask);

[DllImport("kernel32.dll")]
static extern IntPtr GetCurrentThread();
```

由于dwThreadAffinityMask的值是按照$2^n$的指数递增，与通常习惯指定第n个核心不符，并且不同的设备CPU核心数不一样，指定CPU核心时可能超出CPU核心数量，因此可以对指定CPU核心做个简单的处理：
```
static ulong SetCpuID(int lpIdx)
{
    ulong cpuLogicalProcessorId = 0;
    if (lpIdx < 0 || lpIdx >= System.Environment.ProcessorCount)
    {
        lpIdx = 0;
    }
    //通过移位运算转换lgidx->dwThreadAffinityMask:0->1,1->2,2->4,3->8,……
    cpuLogicalProcessorId |= 1UL << lpIdx;
    return cpuLogicalProcessorId;
}
```

接下来就可以进行测试了
```
ulong LpId = SetCpuID((int)lpIdx);
SetThreadAffinityMask(GetCurrentThread(), new UIntPtr(LpId));

Stopwatch stopwatch = new Stopwatch();
stopwatch.Start();
for (int i = 0; i < 1000000; i++)
{
    for (int j = 0; j < 1000000; j++)
    {
        int _data = j;
    }
}
stopwatch.Stop();
Console.WriteLine("运行时间: " + stopwatch.ElapsedMilliseconds.ToString());
```

效果如图如下：
![BandThreadToCPU](https://eb19df4.webp.li/2025/02/BandThreadToCPU.gif)

## SetProcessAffinityMask
SetProcessAffinityMask与SetThreadAffinityMask非常相似，不同的是其作用于整个进程，可以决定进程内的所有线程共同运行在指定的处理器上。
函数定义如下：
```C++
BOOL SetProcessAffinityMask(
  [in] HANDLE    hProcess,
  [in] DWORD_PTR dwProcessAffinityMask
);
```
和SetThreadAffinityMask一样，也是需要传递两个参数，只不过第一个参数传递的是线程的句柄。

## 小结
在某些场景可以通过[**SetThreadAffinityMask**](https://learn.microsoft.com/zh-cn/windows/desktop/api/WinBase/nf-winbase-setthreadaffinitymask)和[**SetProcessAffinityMask**](https://learn.microsoft.com/zh-cn/windows/desktop/api/WinBase/nf-winbase-setprocessaffinitymask) 提高程序执行效率，主要是基于以下几个原因：
* 提高性能：通过将线程绑定到特定的处理器，可以减少线程在不同处理器之间的切换开销，尤其是在多核系统中，有助于提升程序的执行效率。
* 避免缓存抖动：确保线程始终在同一个处理器上运行，可以减少缓存未命中，因为相关的数据更可能保留在该处理器的高速缓存中。
* 实时系统和并发控制：在需要严格控制线程执行位置的场景下，比如实时系统或者某些并发控制策略中，通过设定处理器关联可以满足特定的调度需求。
需要注意的是，SetThreadAffinityMask和SetProcessAffinityMask并不是独占CPU核心，如果关联的CPU核心本身负载就很高，这个时候程序执行效率反而会降低。