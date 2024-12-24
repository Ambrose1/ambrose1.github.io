---
title: Runloop源码阅读
date: 2024-12-24 10:24:33
tags: 
- runloop
- iOS
categories:
- iOS
- C
- Runloop
donate: true
---

# Runloop 源码阅读笔记

> runloop部分代码属于苹果开源部分，本次阅读代码来源 CF-CF-1153.18 2



## 一. 概述



## 二. 对外暴露api方法

### 2.1 对外暴露的结构体

1. 定义宏`CF_IMPLICIT_BRIDGING_ENABLED` 开放隐式桥接，（eg. CFString 类型转换NString 可以直接转换)。

2. 定义 `CF_EXTERN_C_BEGIN` 使用C风格的函数声明，避免C++编译器对C函数进行名称修饰。

3. 对外暴露结构体指针（Runloop对象、Source结构体、Observer结构体、Timer结构体） 其中Timer 显示桥接到NSTimer(CF_BRIDGED_MUTABLE_TYPE)。

```c

#define CF_IMPLICIT_BRIDGING_ENABLED _Pragma("clang arc_cf_code_audited begin")
#define CF_EXTERN_C_BEGIN extern "C" {

// CFRunLoop.h 类
typedef struct __CFRunLoop * CFRunLoopRef;

typedef struct __CFRunLoopSource * CFRunLoopSourceRef;

typedef struct __CFRunLoopObserver * CFRunLoopObserverRef;

typedef struct CF_BRIDGED_MUTABLE_TYPE(NSTimer) __CFRunLoopTimer * CFRunLoopTimerRef;
```

### 2.2 对外暴露管理Runloop对象的方法签名

```c
// RunLoop 的两个重要模式常量
CF_EXPORT const CFStringRef kCFRunLoopDefaultMode;    // 默认模式
CF_EXPORT const CFStringRef kCFRunLoopCommonModes;    // 公共模式

// 获取 RunLoop 的类型标识
CF_EXPORT CFTypeID CFRunLoopGetTypeID(void);

// 获取 RunLoop 实例的函数
CF_EXPORT CFRunLoopRef CFRunLoopGetCurrent(void);     // 获取当前线程的 RunLoop
CF_EXPORT CFRunLoopRef CFRunLoopGetMain(void);        // 获取主线程的 RunLoop

// RunLoop 模式相关操作
CF_EXPORT CFStringRef CFRunLoopCopyCurrentMode(CFRunLoopRef rl);    // 复制当前 RunLoop 的模式
CF_EXPORT CFArrayRef CFRunLoopCopyAllModes(CFRunLoopRef rl);        // 复制所有可用的模式
CF_EXPORT void CFRunLoopAddCommonMode(CFRunLoopRef rl, CFStringRef mode);  // 添加一个新的公共模式

// 定时器相关
CF_EXPORT CFAbsoluteTime CFRunLoopGetNextTimerFireDate(CFRunLoopRef rl, CFStringRef mode);  // 获取下次定时器触发时间

// RunLoop 运行控制
CF_EXPORT void CFRunLoopRun(void);    // 运行当前线程的 RunLoop
CF_EXPORT SInt32 CFRunLoopRunInMode(  // 在指定模式下运行 RunLoop
    CFStringRef mode,                  // 运行模式
    CFTimeInterval seconds,            // 运行时间
    Boolean returnAfterSourceHandled   // 处理完事件源后是否返回
);
CF_EXPORT Boolean CFRunLoopIsWaiting(CFRunLoopRef rl);  // 检查 RunLoop 是否在等待状态
CF_EXPORT void CFRunLoopWakeUp(CFRunLoopRef rl);        // 唤醒 RunLoop
CF_EXPORT void CFRunLoopStop(CFRunLoopRef rl);          // 停止 RunLoop

// Block 相关（仅在支持 Block 的环境下可用）
#if __BLOCKS__
CF_EXPORT void CFRunLoopPerformBlock(
    CFRunLoopRef rl,                  // 目标 RunLoop
    CFTypeRef mode,                   // 运行模式
    void (^block)(void)              // 要执行的 block
) CF_AVAILABLE(10_6, 4_0); 
#endif

// 输入源管理
CF_EXPORT Boolean CFRunLoopContainsSource(    // 检查是否包含特定源
    CFRunLoopRef rl,
    CFRunLoopSourceRef source,
    CFStringRef mode
);
CF_EXPORT void CFRunLoopAddSource(            // 添加输入源
    CFRunLoopRef rl,
    CFRunLoopSourceRef source,
    CFStringRef mode
);
CF_EXPORT void CFRunLoopRemoveSource(         // 移除输入源
    CFRunLoopRef rl,
    CFRunLoopSourceRef source,
    CFStringRef mode
);

// 观察者管理
CF_EXPORT Boolean CFRunLoopContainsObserver(  // 检查是否包含特定观察者
    CFRunLoopRef rl,
    CFRunLoopObserverRef observer,
    CFStringRef mode
);
CF_EXPORT void CFRunLoopAddObserver(          // 添加观察者
    CFRunLoopRef rl,
    CFRunLoopObserverRef observer,
    CFStringRef mode
);
CF_EXPORT void CFRunLoopRemoveObserver(       // 移除观察者
    CFRunLoopRef rl,
    CFRunLoopObserverRef observer,
    CFStringRef mode
);

// 定时器管理
CF_EXPORT Boolean CFRunLoopContainsTimer(     // 检查是否包含特定定时器
    CFRunLoopRef rl,
    CFRunLoopTimerRef timer,
    CFStringRef mode
);
CF_EXPORT void CFRunLoopAddTimer(             // 添加定时器
    CFRunLoopRef rl,
    CFRunLoopTimerRef timer,
    CFStringRef mode
);
CF_EXPORT void CFRunLoopRemoveTimer(          // 移除定时器
    CFRunLoopRef rl,
    CFRunLoopTimerRef timer,
    CFStringRef mode
);
```

### 2.3 Source的管理

 **CFRunLoopSourceContext（版本0）**

- 用于自定义输入源

- 处理应用程序定义的自定义事件

- 适用于一般性的事件处理

```c:CFRunLoop.h
typedef struct {
    CFIndex version;     // 版本号，用于区分不同版本的 Context
    void *info;         // 自定义信息的指针

    // 内存管理回调
    const void *(*retain)(const void *info);      // 保留信息的回调
    void (*release)(const void *info);            // 释放信息的回调

    // 调试和比较功能
    CFStringRef (*copyDescription)(const void *info);  // 创建描述字符串
    Boolean (*equal)(const void *info1, const void *info2);  // 比较两个信息是否相等
    CFHashCode (*hash)(const void *info);              // 计算哈希值

    // RunLoop 相关回调
    void (*schedule)(void *info, CFRunLoopRef rl, CFStringRef mode);  // 源被添加到 RunLoop 时调用
    void (*cancel)(void *info, CFRunLoopRef rl, CFStringRef mode);    // 源被从 RunLoop 移除时调用
    void (*perform)(void *info);  // 源被触发时执行的操作
} CFRunLoopSourceContext;
```

**CFRunLoopSourceContext1（版本1）**

- 专门用于基于端口的输入源

- 主要用于处理 Mach 端口相关的事件

- 系统底层进程间通信使用

```c:CFRunLoop.h
typedef struct {
    CFIndex version;    // 版本号
    void *info;        // 自定义信息指针

    // 内存管理回调（与版本0相同）
    const void *(*retain)(const void *info);
    void (*release)(const void *info);

    // 调试和比较功能（与版本0相同）
    CFStringRef (*copyDescription)(const void *info);
    Boolean (*equal)(const void *info1, const void *info2);
    CFHashCode (*hash)(const void *info);

    // 在 Mac/iOS 平台特有的功能
#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)) || (TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
    mach_port_t (*getPort)(void *info);     // 获取 Mach 端口
    void *(*perform)(void *msg, CFIndex size, CFAllocatorRef allocator, void *info);  // 处理 Mach 消息
#else
    void *(*getPort)(void *info);
    void (*perform)(void *info);
#endif
} CFRunLoopSourceContext1;
```

```c
// 获取 CFRunLoopSource 类型的唯一标识符
// 用于运行时类型检查和判断
CF_EXPORT CFTypeID CFRunLoopSourceGetTypeID(void);

// 创建一个新的 RunLoop 源
CF_EXPORT CFRunLoopSourceRef CFRunLoopSourceCreate(
    CFAllocatorRef allocator,         // 内存分配器，通常传 kCFAllocatorDefault
    CFIndex order,                    // 源的优先级顺序，数值越小优先级越高
    CFRunLoopSourceContext *context   // 源的上下文配置，包含各种回调函数
);

// 获取 RunLoop 源的优先级顺序
// 返回创建时指定的 order 值
CF_EXPORT CFIndex CFRunLoopSourceGetOrder(CFRunLoopSourceRef source);

// 使 RunLoop 源失效
// 使源无法再被触发，通常在不再需要源时调用
CF_EXPORT void CFRunLoopSourceInvalidate(CFRunLoopSourceRef source);

// 检查 RunLoop 源是否有效
// 返回 true 表示源仍然有效，false 表示已经失效
CF_EXPORT Boolean CFRunLoopSourceIsValid(CFRunLoopSourceRef source);

// 获取 RunLoop 源的上下文信息
// 将源的上下文信息复制到提供的 context 结构体中
CF_EXPORT void CFRunLoopSourceGetContext(
    CFRunLoopSourceRef source,        // 要获取上下文的源
    CFRunLoopSourceContext *context   // 接收上下文信息的结构体
);

// 标记 RunLoop 源为待处理状态
// 源下次被 RunLoop 处理时会触发其 perform 回调
CF_EXPORT void CFRunLoopSourceSignal(CFRunLoopSourceRef source);
```

### 2.4 Observer的管理

```c
// Observer 的上下文结构体，用于存储观察者的配置信息
typedef struct {
    CFIndex version;        // 版本号
    void *info;            // 自定义信息的指针
    // 内存管理回调函数
    const void *(*retain)(const void *info);      // 保留信息的回调
    void (*release)(const void *info);            // 释放信息的回调
    CFStringRef (*copyDescription)(const void *info);  // 创建描述信息的回调
} CFRunLoopObserverContext;

// Observer 的回调函数类型定义
// observer: 观察者对象
// activity: 当前发生的活动类型（如进入循环、退出循环等）
// info: 自定义信息指针
typedef void (*CFRunLoopObserverCallBack)(
    CFRunLoopObserverRef observer,
    CFRunLoopActivity activity,
    void *info
);

// 获取 CFRunLoopObserver 类型的唯一标识符
CF_EXPORT CFTypeID CFRunLoopObserverGetTypeID(void);

// 创建一个 RunLoop 观察者
CF_EXPORT CFRunLoopObserverRef CFRunLoopObserverCreate(
    CFAllocatorRef allocator,          // 内存分配器
    CFOptionFlags activities,          // 要观察的活动类型（组合标志）
    Boolean repeats,                   // 是否重复观察
    CFIndex order,                     // 观察者优先级
    CFRunLoopObserverCallBack callout, // 回调函数
    CFRunLoopObserverContext *context  // 观察者上下文
);

// 使用 Block 创建观察者（仅在支持 Block 的环境下可用）
#if __BLOCKS__
CF_EXPORT CFRunLoopObserverRef CFRunLoopObserverCreateWithHandler(
    CFAllocatorRef allocator,          // 内存分配器
    CFOptionFlags activities,          // 要观察的活动类型
    Boolean repeats,                   // 是否重复观察
    CFIndex order,                     // 观察者优先级
    // Block 形式的回调处理
    void (^block) (CFRunLoopObserverRef observer, CFRunLoopActivity activity)
) CF_AVAILABLE(10_7, 5_0);
#endif

// 获取观察者监听的活动类型
CF_EXPORT CFOptionFlags CFRunLoopObserverGetActivities(CFRunLoopObserverRef observer);

// 检查观察者是否重复观察
CF_EXPORT Boolean CFRunLoopObserverDoesRepeat(CFRunLoopObserverRef observer);

// 获取观察者的优先级顺序
CF_EXPORT CFIndex CFRunLoopObserverGetOrder(CFRunLoopObserverRef observer);

// 使观察者失效
CF_EXPORT void CFRunLoopObserverInvalidate(CFRunLoopObserverRef observer);

// 检查观察者是否有效
CF_EXPORT Boolean CFRunLoopObserverIsValid(CFRunLoopObserverRef observer);

// 获取观察者的上下文信息
CF_EXPORT void CFRunLoopObserverGetContext(
    CFRunLoopObserverRef observer,
    CFRunLoopObserverContext *context
);
```

### 2.5 Timer 的管理

```c
// Timer 的上下文结构体，用于存储定时器的配置信息
typedef struct {
    CFIndex version;        // 版本号
    void *info;            // 自定义信息的指针
    // 内存管理回调函数
    const void *(*retain)(const void *info);      // 保留信息的回调
    void (*release)(const void *info);            // 释放信息的回调
    CFStringRef (*copyDescription)(const void *info);  // 创建描述信息的回调
} CFRunLoopTimerContext;

// Timer 的回调函数类型定义
typedef void (*CFRunLoopTimerCallBack)(
    CFRunLoopTimerRef timer,  // 触发的定时器
    void *info               // 自定义信息指针
);

// 获取 CFRunLoopTimer 类型的唯一标识符
CF_EXPORT CFTypeID CFRunLoopTimerGetTypeID(void);

// 创建一个 RunLoop 定时器
CF_EXPORT CFRunLoopTimerRef CFRunLoopTimerCreate(
    CFAllocatorRef allocator,          // 内存分配器
    CFAbsoluteTime fireDate,           // 首次触发时间
    CFTimeInterval interval,           // 重复间隔（0表示不重复）
    CFOptionFlags flags,               // 标志位
    CFIndex order,                     // 优先级顺序
    CFRunLoopTimerCallBack callout,    // 回调函数
    CFRunLoopTimerContext *context     // 定时器上下文
);

// 使用 Block 创建定时器（仅在支持 Block 的环境下可用）
#if __BLOCKS__
CF_EXPORT CFRunLoopTimerRef CFRunLoopTimerCreateWithHandler(
    CFAllocatorRef allocator,
    CFAbsoluteTime fireDate,
    CFTimeInterval interval,
    CFOptionFlags flags,
    CFIndex order,
    void (^block) (CFRunLoopTimerRef timer)  // Block 形式的回调
) CF_AVAILABLE(10_7, 5_0);
#endif

// 获取定时器下次触发时间
CF_EXPORT CFAbsoluteTime CFRunLoopTimerGetNextFireDate(CFRunLoopTimerRef timer);

// 设置定时器下次触发时间
CF_EXPORT void CFRunLoopTimerSetNextFireDate(CFRunLoopTimerRef timer, CFAbsoluteTime fireDate);

// 获取定时器的重复间隔
CF_EXPORT CFTimeInterval CFRunLoopTimerGetInterval(CFRunLoopTimerRef timer);

// 检查定时器是否重复
CF_EXPORT Boolean CFRunLoopTimerDoesRepeat(CFRunLoopTimerRef timer);

// 获取定时器的优先级顺序
CF_EXPORT CFIndex CFRunLoopTimerGetOrder(CFRunLoopTimerRef timer);

// 使定时器失效
CF_EXPORT void CFRunLoopTimerInvalidate(CFRunLoopTimerRef timer);

// 检查定时器是否有效
CF_EXPORT Boolean CFRunLoopTimerIsValid(CFRunLoopTimerRef timer);

// 获取定时器的上下文信息
CF_EXPORT void CFRunLoopTimerGetContext(CFRunLoopTimerRef timer, CFRunLoopTimerContext *context);

// 定时器容差相关函数
// 容差允许定时器在预定时间之后的一段时间内触发，以优化系统性能和电源使用
// 定时器会在预定时间和预定时间加上容差之间的任意时刻触发
// 对于重复定时器，建议将容差设置为间隔的至少10%

// 获取定时器的容差值
CF_EXPORT CFTimeInterval CFRunLoopTimerGetTolerance(CFRunLoopTimerRef timer) CF_AVAILABLE(10_9, 7_0);

// 设置定时器的容差值
CF_EXPORT void CFRunLoopTimerSetTolerance(CFRunLoopTimerRef timer, CFTimeInterval tolerance) CF_AVAILABLE(10_9, 7_0);
```



## 三. 内部实现

```c
// 这个函数 `__CFGetProcessPortCount` 用于获取当前进程的 Mach 端口数量。让我详细解释：
CF_PRIVATE uint32_t __CFGetProcessPortCount(void) {
    // Mach IPC 相关的数据结构
    ipc_info_space_t info;
    ipc_info_name_array_t table = 0;        // 端口表数组
    mach_msg_type_number_t tableCount = 0;  // 端口表计数
    ipc_info_tree_name_array_t tree = 0;    // 端口树数组
    mach_msg_type_number_t treeCount = 0;   // 端口树计数
    
    // 获取当前任务的端口空间信息
    kern_return_t ret = mach_port_space_info(
        mach_task_self(),  // 当前任务
        &info,             // 端口空间信息
        &table,            // 端口表
        &tableCount,       // 端口数量
        &tree,            // 端口树
        &treeCount        // 树节点数量
    );
    
    // 如果获取失败，返回0
    if (ret != KERN_SUCCESS) {
        return (uint32_t)0;
    }
    
    // 清理分配的内存
    if (table != NULL) {
        // 释放端口表内存
        ret = vm_deallocate(mach_task_self(), (vm_address_t)table, tableCount * sizeof(*table));
    }
    if (tree != NULL) {
        // 释放端口树内存
        ret = vm_deallocate(mach_task_self(), (vm_address_t)tree, treeCount * sizeof(*tree));
    }
    
    // 返回端口数量
    return (uint32_t)tableCount;
}
```

```c
// 停止当前进程中除了调用线程外的所有线程，返回被挂起的线程列表
CF_PRIVATE CFArrayRef __CFStopAllThreads(void) {
    // 创建一个可变数组用于存储被挂起的线程
    CFMutableArrayRef suspended_list = CFArrayCreateMutable(kCFAllocatorSystemDefault, 0, NULL);
    
    // 获取当前任务（进程）的端口
    mach_port_t my_task = mach_task_self();
    // 获取当前线程的端口
    mach_port_t my_thread = mach_thread_self();
    
    // 用于存储线程列表的变量
    thread_act_array_t thr_list = 0;     // 线程数组
    mach_msg_type_number_t thr_cnt = 0;  // 线程数量

    // 获取当前任务中的所有线程
    // 注释提示：实际上应该循环执行停止操作，直到连续N次都没有新线程加入列表
    kern_return_t ret = task_threads(my_task, &thr_list, &thr_cnt);
    
    if (ret == KERN_SUCCESS) {
        // 遍历所有线程
        for (CFIndex idx = 0; idx < thr_cnt; idx++) {
            thread_act_t thread = thr_list[idx];
            
            // 跳过当前线程（不能挂起自己）
            if (thread == my_thread) continue;
            
            // 如果线程已经在挂起列表中，跳过
            if (CFArrayContainsValue(suspended_list, 
                CFRangeMake(0, CFArrayGetCount(suspended_list)), 
                (const void *)(uintptr_t)thread)) continue;
            
            // 尝试挂起线程
            ret = thread_suspend(thread);
            if (ret == KERN_SUCCESS) {
                // 挂起成功，将线程添加到列表中
                CFArrayAppendValue(suspended_list, (const void *)(uintptr_t)thread);
            } else {
                // 挂起失败，释放线程端口
                mach_port_deallocate(my_task, thread);
            }
        }
        
        // 释放线程列表占用的内存
        vm_deallocate(my_task, (vm_address_t)thr_list, sizeof(thread_t) * thr_cnt);
    }
    
    // 释放当前线程的端口
    mach_port_deallocate(my_task, my_thread);
    
    // 返回被挂起的线程列表
    return suspended_list;
}
```



在 Mach 内核中，任务（Task）和线程（Thread）是两个不同层次的概念：

Task 对应的是用户空间的进程。

Task (进程)
  |
  |-- Thread 1 (线程1)
  |-- Thread 2 (线程2)
  |-- Thread 3 (线程3)
  |
  |-- 共享资源
      |-- 内存空间
      |-- 文件描述符
      |-- 端口权限
      |-- 其他系统资源



### 3.1 RunloopMode

```c
struct __CFRunLoopMode {
    // 基础运行时信息
    CFRuntimeBase _base;                    // Core Foundation 对象的基础结构
    
    // 同步控制
    pthread_mutex_t _lock;                  // 模式的互斥锁
    
    // 基本信息
    CFStringRef _name;                      // 模式名称（如 kCFRunLoopDefaultMode）
    Boolean _stopped;                       // 模式是否已停止
    char _padding[3];                       // 字节对齐的填充
    
    // 事件源管理
    CFMutableSetRef _sources0;              // 非基于端口的源（如手动触发）
    CFMutableSetRef _sources1;              // 基于端口的源（如系统事件）
    CFMutableArrayRef _observers;           // RunLoop 观察者列表
    CFMutableArrayRef _timers;             // 定时器列表
    
    // 端口管理
    CFMutableDictionaryRef _portToV1SourceMap;  // 端口到源的映射
    __CFPortSet _portSet;                       // 当前模式的端口集合
    
    // 观察者掩码
    CFIndex _observerMask;                      // 观察者事件掩码
    
    // GCD定时器支持
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    dispatch_source_t _timerSource;        // GCD定时器源
    dispatch_queue_t _queue;               // GCD队列
    Boolean _timerFired;                   // 定时器是否已触发
    Boolean _dispatchTimerArmed;           // GCD定时器是否已装备
#endif
    
    // MK定时器支持
#if USE_MK_TIMER_TOO
    mach_port_t _timerPort;               // MK定时器端口
    Boolean _mkTimerArmed;                // MK定时器是否已装备
#endif
    
    // Windows特定支持
#if DEPLOYMENT_TARGET_WINDOWS
    DWORD _msgQMask;                      // 消息队列掩码
    void (*_msgPump)(void);               // 消息泵函数指针
#endif
    
    // 定时器截止时间
    uint64_t _timerSoftDeadline;          // 软截止时间
    uint64_t _timerHardDeadline;          // 硬截止时间
};
```

### 3.2 Runloop

```c
// Block项结构体 - 用于管理待执行的blocks
struct _block_item {
    struct _block_item *_next;      // 链表中的下一个block项
    CFTypeRef _mode;                // block执行的模式(CFString)或模式集合(CFSet)
    void (^_block)(void);           // 要执行的block
};

// 每次运行循环的数据结构
typedef struct _per_run_data {
    uint32_t a;                     // 魔数 'CFRL'
    uint32_t b;                     // 魔数 'CFRL'
    uint32_t stopped;               // 停止标志 (0x53544F50 'STOP' 表示已停止)
    uint32_t ignoreWakeUps;        // 忽略唤醒标志 (0x57414B45 'WAKE' 表示忽略)
} _per_run_data;

// RunLoop主结构体
struct __CFRunLoop {
    CFRuntimeBase _base;            // CF对象基础结构
    pthread_mutex_t _lock;          // 访问模式列表的互斥锁
    __CFPort _wakeUpPort;          // 用于唤醒RunLoop的端口
    Boolean _unused;                // 未使用的布尔值
    
    // 每次运行的状态数据
    volatile _per_run_data *_perRunData;  // 运行时数据，每次运行都会重置
    
    // 线程相关
    pthread_t _pthread;             // RunLoop所属的pthread
    uint32_t _winthread;           // Windows线程ID（仅Windows平台）
    
    // 模式管理
    CFMutableSetRef _commonModes;    // 通用模式名称集合
    CFMutableSetRef _commonModeItems; // 通用模式项目集合
    CFRunLoopModeRef _currentMode;   // 当前运行的模式
    CFMutableSetRef _modes;          // 所有模式的集合
    
    // Block管理
    struct _block_item *_blocks_head; // Block链表头
    struct _block_item *_blocks_tail; // Block链表尾
    
    // 时间统计
    CFAbsoluteTime _runTime;         // 运行时间
    CFAbsoluteTime _sleepTime;       // 睡眠时间
    
    CFTypeRef _counterpart;          // 相关联的对象引用
};
```

```c
RunLoop
    |
    |-- _modes (所有模式)
    |     |-- Mode1
    |     |-- Mode2
    |     `-- Mode3
    |
    |-- _commonModes (通用模式名称)
    |     |-- "Default"
    |     `-- "Common"
    |
    `-- _currentMode (当前模式)
```

### 3.3 Source

```c
struct __CFRunLoopSource {
    CFRuntimeBase _base;
    uint32_t _bits;
    pthread_mutex_t _lock;
    CFIndex _order;			/* immutable */
    CFMutableBagRef _runLoops;
    union {
	CFRunLoopSourceContext version0;	/* immutable, except invalidation */
        CFRunLoopSourceContext1 version1;	/* immutable, except invalidation */
    } _context;
};

```

### 3.4 Observers

```c
struct __CFRunLoopObserver {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;
    CFRunLoopRef _runLoop;
    CFIndex _rlCount;
    CFOptionFlags _activities;		/* immutable */
    CFIndex _order;			/* immutable */
    CFRunLoopObserverCallBack _callout;	/* immutable */
    CFRunLoopObserverContext _context;	/* immutable, except invalidation */
};
```

### 3.5 Timers

```c
struct __CFRunLoopTimer {
    CFRuntimeBase _base;
    uint16_t _bits;
    pthread_mutex_t _lock;
    CFRunLoopRef _runLoop;
    CFMutableSetRef _rlModes;
    CFAbsoluteTime _nextFireDate;
    CFTimeInterval _interval;		/* immutable */
    CFTimeInterval _tolerance;          /* mutable */
    uint64_t _fireTSR;			/* TSR units */
    CFIndex _order;			/* immutable */
    CFRunLoopTimerCallBack _callout;	/* immutable */
    CFRunLoopTimerContext _context;	/* immutable, except invalidation */
};
```

### 3.6 Runloop 的释放

创建在释放方法下面，暂时不详细介绍释放，后续复习时补充。

1. __CFRunLoopCleanseSources

2. __CFRunLoopDeallocateSources

3. __CFRunLoopDeallocateObservers

4. __CFRunLoopDeallocateTimers

5. __CFRunLoopDeallocate

### 3.7 Runloop的创建

```c
// 为指定线程创建一个新的 RunLoop
static CFRunLoopRef __CFRunLoopCreate(pthread_t t) {
    CFRunLoopRef loop = NULL;
    CFRunLoopModeRef rlm;
    
    // 计算需要分配的内存大小（减去基础结构体大小）
    uint32_t size = sizeof(struct __CFRunLoop) - sizeof(CFRuntimeBase);
    
    // 创建 RunLoop 实例
    loop = (CFRunLoopRef)_CFRuntimeCreateInstance(
        kCFAllocatorSystemDefault,    // 使用默认内存分配器
        CFRunLoopGetTypeID(),         // RunLoop 类型 ID
        size,                         // 分配大小
        NULL                          // 无额外配置
    );
    
    // 创建失败则返回 NULL
    if (NULL == loop) {
        return NULL;
    }
    
    // 初始化每次运行数据
    (void)__CFRunLoopPushPerRunData(loop);
    
    // 初始化互斥锁
    __CFRunLoopLockInit(&loop->_lock);
    
    // 分配唤醒端口
    loop->_wakeUpPort = __CFPortAllocate();
    if (CFPORT_NULL == loop->_wakeUpPort) HALT;  // 分配失败则终止
    
    // 设置忽略唤醒标志
    __CFRunLoopSetIgnoreWakeUps(loop);
    
    // 创建通用模式集合并添加默认模式
    loop->_commonModes = CFSetCreateMutable(
        kCFAllocatorSystemDefault,    // 默认分配器
        0,                            // 初始容量（自动增长）
        &kCFTypeSetCallBacks         // 标准 CF 类型回调
    );
    CFSetAddValue(loop->_commonModes, kCFRunLoopDefaultMode);
    
    // 初始化其他字段
    loop->_commonModeItems = NULL;    // 通用模式项目
    loop->_currentMode = NULL;        // 当前模式
    loop->_modes = CFSetCreateMutable(// 创建模式集合
        kCFAllocatorSystemDefault, 
        0, 
        &kCFTypeSetCallBacks
    );
    
    // 初始化 block 链表
    loop->_blocks_head = NULL;
    loop->_blocks_tail = NULL;
    
    loop->_counterpart = NULL;        // 相关联对象
    
    // 设置线程信息
    loop->_pthread = t;               // 关联的 pthread
    
#if DEPLOYMENT_TARGET_WINDOWS
    // Windows 平台特定：获取当前线程 ID
    loop->_winthread = GetCurrentThreadId();
#else
    loop->_winthread = 0;
#endif
    
    // 创建并初始化默认运行模式
    rlm = __CFRunLoopFindMode(loop, kCFRunLoopDefaultMode, true);
    if (NULL != rlm) __CFRunLoopModeUnlock(rlm);  // 解锁模式
    
    return loop;
}
```

```c
// 仅供 Foundation 调用
// t==0 时表示"主线程"（始终有效）
CF_EXPORT CFRunLoopRef _CFRunLoopGet0(pthread_t t) {
    // 如果是空线程ID，则获取主线程
    if (pthread_equal(t, kNilPthreadT)) {
        t = pthread_main_thread_np();
    }
    
    // 加锁访问全局 RunLoop 字典
    __CFLock(&loopsLock);
    
    // 首次调用时初始化全局 RunLoop 字典
    if (!__CFRunLoops) {
        __CFUnlock(&loopsLock);  // 临时解锁以避免死锁
        
        // 创建存储所有 RunLoop 的字典
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(
            kCFAllocatorSystemDefault, 
            0, 
            NULL, 
            &kCFTypeDictionaryValueCallBacks
        );
        
        // 创建主线程的 RunLoop
        CFRunLoopRef mainLoop = __CFRunLoopCreate(pthread_main_thread_np());
        CFDictionarySetValue(dict, pthreadPointer(pthread_main_thread_np()), mainLoop);
        
        // 原子操作设置全局字典
        if (!OSAtomicCompareAndSwapPtrBarrier(NULL, dict, (void * volatile *)&__CFRunLoops)) {
            CFRelease(dict);  // 如果设置失败，释放资源
        }
        CFRelease(mainLoop);
        __CFLock(&loopsLock);
    }
    
    // 查找指定线程的 RunLoop
    CFRunLoopRef loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
    __CFUnlock(&loopsLock);
    
    // 如果没找到，创建新的 RunLoop
    if (!loop) {
        CFRunLoopRef newLoop = __CFRunLoopCreate(t);
        __CFLock(&loopsLock);
        
        // 双重检查，确保没有其他线程已经创建
        loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
        if (!loop) {
            CFDictionarySetValue(__CFRunLoops, pthreadPointer(t), newLoop);
            loop = newLoop;
        }
        __CFUnlock(&loopsLock);
        CFRelease(newLoop);
    }
    
    // 如果是当前线程，设置线程特定数据
    if (pthread_equal(t, pthread_self())) {
        // 存储 RunLoop 到线程本地存储
        _CFSetTSD(__CFTSDKeyRunLoop, (void *)loop, NULL);
        
        // 设置 RunLoop 计数器和清理函数
        if (0 == _CFGetTSD(__CFTSDKeyRunLoopCntr)) {
            _CFSetTSD(__CFTSDKeyRunLoopCntr, 
                     (void *)(PTHREAD_DESTRUCTOR_ITERATIONS-1),
                     (void (*)(void *))__CFFinalizeRunLoop);
        }
    }
    
    return loop;
}
```

runloop 执行block事件

```c
// 执行 RunLoop 中的 blocks，需要在 RunLoop 和 RunLoopMode 都已锁定的情况下调用
static Boolean __CFRunLoopDoBlocks(CFRunLoopRef rl, CFRunLoopModeRef rlm) {
    // 快速检查：如果没有 blocks 或模式无效则返回
    if (!rl->_blocks_head) return false;
    if (!rlm || !rlm->_name) return false;
    
    Boolean did = false;  // 标记是否执行了任何 block
    
    // 保存当前 blocks 链表状态并清空
    struct _block_item *head = rl->_blocks_head;
    struct _block_item *tail = rl->_blocks_tail;
    rl->_blocks_head = NULL;
    rl->_blocks_tail = NULL;
    
    // 保存当前上下文信息
    CFSetRef commonModes = rl->_commonModes;
    CFStringRef curMode = rlm->_name;
    
    // 解锁以执行 blocks（避免死锁）
    __CFRunLoopModeUnlock(rlm);
    __CFRunLoopUnlock(rl);
    
    // 遍历所有 blocks
    struct _block_item *prev = NULL;
    struct _block_item *item = head;
    while (item) {
        struct _block_item *curr = item;
        item = item->_next;
        
        // 判断是否应该执行此 block
        Boolean doit = false;
        if (CFStringGetTypeID() == CFGetTypeID(curr->_mode)) {
            // 模式是字符串：检查是否匹配当前模式或通用模式
            doit = CFEqual(curr->_mode, curMode) || 
                  (CFEqual(curr->_mode, kCFRunLoopCommonModes) && 
                   CFSetContainsValue(commonModes, curMode));
        } else {
            // 模式是集合：检查是否包含当前模式或通用模式
            doit = CFSetContainsValue((CFSetRef)curr->_mode, curMode) || 
                  (CFSetContainsValue((CFSetRef)curr->_mode, kCFRunLoopCommonModes) && 
                   CFSetContainsValue(commonModes, curMode));
        }
        
        // 不执行则保留在链表中
        if (!doit) prev = curr;
        
        // 执行 block
        if (doit) {
            // 更新链表
            if (prev) prev->_next = item;
            if (curr == head) head = item;
            if (curr == tail) tail = prev;
            
            // 获取 block 并释放结构
            void (^block)(void) = curr->_block;
            CFRelease(curr->_mode);
            free(curr);
            
            // 执行 block
            if (doit) {
                __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__(block);
                did = true;
            }
            
            // 释放 block（在重新加锁之前完成，避免死锁）
            Block_release(block);
        }
    }
    
    // 重新加锁
    __CFRunLoopLock(rl);
    __CFRunLoopModeLock(rlm);
    
    // 如果还有未执行的 blocks，将它们重新加入队列
    if (head) {
        tail->_next = rl->_blocks_head;
        rl->_blocks_head = head;
        if (!rl->_blocks_tail) rl->_blocks_tail = tail;
    }
    
    return did;  // 返回是否执行了任何 block
}
```

12.24 更新至1664行

未完待续......
