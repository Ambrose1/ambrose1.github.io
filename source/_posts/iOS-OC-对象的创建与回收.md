---
title: iOS OC 对象的创建与回收
abstract: 介绍iOS中对象的创建过程、销毁回收过程（源码级别
date: 2025-03-05 14:58:10
tags: iOS
categories:
 - iOS
---

创建过程

```cpp
/// runtime NSObject.mm
+ (id)alloc {
    return _objc_rootAlloc(self);
}

// Base class implementation of +alloc. cls is not nil.
// Calls [cls allocWithZone:nil].
id
_objc_rootAlloc(Class cls)
{
    return callAlloc(cls, false/*checkNil*/, true/*allocWithZone*/);
}


#define fastpath(x) (__builtin_expect(bool(x), 1))
#define slowpath(x) (__builtin_expect(bool(x), 0))
// Call [cls alloc] or [cls allocWithZone:nil], with appropriate
// shortcutting optimizations.
// 内联函数
static ALWAYS_INLINE id
callAlloc(Class cls, bool checkNil, bool allocWithZone=false)
{
    if (slowpath(checkNil && !cls)) return nil;
    if (fastpath(!cls->ISA()->hasCustomAWZ())) {
        return _objc_rootAllocWithZone(cls, nil);
    }

    // No shortcuts available.
    if (allocWithZone) {
        return ((id(*)(id, SEL, struct _NSZone *))objc_msgSend)(cls, @selector(allocWithZone:), nil);
    }
    return ((id(*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
}

NEVER_INLINE
id
_objc_rootAllocWithZone(Class cls, objc_zone_t)
{
    // allocWithZone under __OBJC2__ ignores the zone parameter
    return _class_createInstance(cls, 0, OBJECT_CONSTRUCT_CALL_BADALLOC);
}

/***********************************************************************
* class_createInstance
* fixme
* Locking: none
*
* Note: this function has been carefully written so that the fastpath
* takes no branch.
**********************************************************************/
static ALWAYS_INLINE id
_class_createInstance(Class cls, size_t extraBytes,
                      int construct_flags = OBJECT_CONSTRUCT_NONE,
                      bool cxxConstruct = true,
                      size_t *outAllocatedSize = nil)
{
    ASSERT(cls->isRealized());

    // Read class's info bits all at once for performance
    bool hasCxxCtor = cxxConstruct && cls->hasCxxCtor();
    bool hasCxxDtor = cls->hasCxxDtor();
    bool fast = cls->canAllocNonpointer();
    size_t size;

    size = cls->instanceSize(extraBytes);
    if (outAllocatedSize) *outAllocatedSize = size;

    id obj = objc::malloc_instance(size, cls);
    if (slowpath(!obj)) {
        if (construct_flags & OBJECT_CONSTRUCT_CALL_BADALLOC) {
            return _objc_callBadAllocHandler(cls);
        }
        return nil;
    }

    if (fast) {
        obj->initInstanceIsa(cls, hasCxxDtor);
    } else {
        // Use raw pointer isa on the assumption that they might be
        // doing something weird with the zone or RR.
        obj->initIsa(cls);
    }

    if (fastpath(!hasCxxCtor)) {
        return obj;
    }

    construct_flags |= OBJECT_CONSTRUCT_FREE_ONFAILURE;
    return object_cxxConstructFromClass(obj, cls, construct_flags);
}


inline void 
objc_object::initIsa(Class cls, bool nonpointer, UNUSED_WITHOUT_INDEXED_ISA_AND_DTOR_BIT bool hasCxxDtor)
{ 
    ASSERT(!isTaggedPointer()); 
    
    isa_t newisa(0);

    if (!nonpointer) {
        newisa.setClass(cls, this);
    } else {
        ASSERT(!DisableNonpointerIsa);
        ASSERT(!cls->instancesRequireRawIsa());


#if SUPPORT_INDEXED_ISA
        ASSERT(cls->classArrayIndex() > 0);
        newisa.bits = ISA_INDEX_MAGIC_VALUE;
        // isa.magic is part of ISA_MAGIC_VALUE
        // isa.nonpointer is part of ISA_MAGIC_VALUE
        newisa.has_cxx_dtor = hasCxxDtor;
        newisa.indexcls = (uintptr_t)cls->classArrayIndex();
#else
        newisa.bits = ISA_MAGIC_VALUE;
        // isa.magic is part of ISA_MAGIC_VALUE
        // isa.nonpointer is part of ISA_MAGIC_VALUE
#   if ISA_HAS_CXX_DTOR_BIT
        newisa.has_cxx_dtor = hasCxxDtor;
#   endif
        newisa.setClass(cls, this);
#endif
#if ISA_HAS_INLINE_RC
        newisa.extra_rc = 1;
#endif
    }

    // This write must be performed in a single store in some cases
    // (for example when realizing a class because other threads
    // may simultaneously try to use the class).
    // fixme use atomics here to guarantee single-store and to
    // guarantee memory order w.r.t. the class index table
    // ...but not too atomic because we don't want to hurt instantiation
    isa() = newisa;
}
```



> 嗯，用户问的是关于Objective-C中`fastpath`和`slowpath`宏的使用，特别是在`callAlloc`方法中的那段代码。我需要先理解这两个宏的作用以及它们在代码中的具体应用。
> 
> 首先，根据搜索结果，用户提供的代码片段里有`fastpath`和`slowpath`的定义，这些宏使用了`__builtin_expect`指令。网页2、网页4、网页5和网页6都提到了这两个宏的作用，是告诉编译器条件判断的结果可能性，从而优化分支预测。比如，`fastpath(x)`表示x很可能为真，`slowpath(x)`则相反。在`callAlloc`函数中，`fastpath(!cls->ISA()->hasCustomAWZ())`这里判断是否类没有自定义的`allocWithZone:`方法，如果大概率没有，就走快速路径，直接分配内存。
> 
> 接下来需要解释这两个宏如何影响代码执行流程。网页2和网页6提到，使用这些宏可以减少指令重排带来的性能损耗，提升效率。比如，当`fastpath`条件满足时，编译器会优化代码，使得条件成立的分支更快执行。
> 
> 另外，代码中的`hasCustomAWZ()`方法检查类是否重写了`allocWithZone:`，如果没有，就调用`_objc_rootAllocWithZone`进行内存分配。这部分逻辑在网页4和网页5的源码分析中有提到，说明系统默认情况下使用高效的内存分配路径，而自定义的`allocWithZone:`则会走较慢的分支。
> 
> 还要注意，用户提供的代码片段中的`callAlloc`函数里，当`fastpath`条件成立时，会直接进入`_objc_rootAllocWithZone`，否则可能调用其他方法。需要结合搜索结果中的源码分析，说明这一步在对象创建过程中的作用，比如内存计算、分配和isa初始化，如网页1、网页4和网页5所述。
> 
> 最后，要综合多个网页的信息，解释这些宏如何在实际开发中影响性能，以及为什么在Objective-C运行时库中使用这些优化手段。例如，网页2和网页6都提到，编译器优化后的代码能减少分支误预测，提高CPU指令流水线的效率，这对于频繁执行的对象创建操作尤为重要。
> 
> 在 Objective-C 的运行时源码中，`fastpath` 和 `slowpath` 宏是用于优化分支预测的关键技术，结合 `callAlloc` 函数的逻辑，它们的核心作用如下：
> 
> ---
> 
> ### **1. 宏定义与编译器优化**
> 
> - **`fastpath(x)`**：  
>   定义为 `__builtin_expect(bool(x), 1)`，表示条件 `x` 为 **真** 的概率较高。编译器会优先将对应的分支代码放置在靠近主流程的位置，减少 CPU 流水线因分支预测失败导致的指令重排开销。  
>   例如，在 `fastpath(!cls->ISA()->hasCustomAWZ())` 中，假设类 `cls` 未重写 `allocWithZone:` 方法（默认行为），则直接进入高效的内存分配路径。
> 
> - **`slowpath(x)`**：  
>   定义为 `__builtin_expect(bool(x), 0)`，表示条件 `x` 为 **假** 的概率较高。例如 `slowpath(checkNil && !cls)` 表示 `cls` 为空是小概率事件，但需处理异常情况。
> 
> ---
> 
> ### **2. `callAlloc` 方法中的逻辑**
> 
> 在对象创建的 `callAlloc` 函数中，这两个宏用于控制执行流程：
> 
> ```objectivec
> if (slowpath(checkNil && !cls)) return nil;
> if (fastpath(!cls->ISA()->hasCustomAWZ())) {
>     return _objc_rootAllocWithZone(cls, nil);
> }
> ```
> 
> 1. **分支 1：`slowpath(checkNil && !cls)`**  
>    当传入的类 `cls` 为空时，直接返回 `nil`。由于这是异常情况（例如开发中未正确初始化类），标记为小概率事件，避免对主流程性能造成影响。
> 
> 2. **分支 2：`fastpath(!cls->ISA()->hasCustomAWZ())`**  
>    
>    - `hasCustomAWZ()` 检查类是否重写了 `allocWithZone:` 方法。  
>    - 若未重写（绝大多数情况），直接调用 `_objc_rootAllocWithZone`，进入高效内存分配流程：  
>      - **内存计算**：通过 `cls->instanceSize()` 计算对象所需内存大小。
>      - **内存分配**：调用 `calloc` 分配内存，并关联对象的 `isa` 指针。
>    - 若已重写（如自定义内存管理），则进入 `allocWithZone:` 的慢速路径。
> 
> ---
> 
> ### **3. 性能优化意义**
> 
> 1. **减少分支预测失败**：  
>    通过宏标记分支概率，编译器可以优化指令顺序，使 CPU 预取大概率执行的代码，减少流水线冲刷。
> 2. **高效内存分配路径**：  
>    默认情况下，对象分配通过 `_objc_rootAllocWithZone` 完成，绕过了 `allocWithZone:` 的动态派发开销，直接调用底层 `calloc` 和 `initInstanceIsa`，提升性能。
> 
> ---
> 
> ### **总结**
> 
> `fastpath` 和 `slowpath` 是 Objective-C 运行时对 GCC 内置指令 `__builtin_expect` 的封装，用于指导编译器优化分支预测。在 `callAlloc` 中，它们通过区分默认路径与异常/自定义路径，确保对象创建的高效性。这种设计在频繁调用的底层操作（如 `alloc`）中尤为重要，能显著减少性能损耗。

# 释放

```cpp
// Replaced by NSZombies
- (void)dealloc {
    _objc_rootDealloc(self);
}

void
_objc_rootDealloc(id obj)
{
    ASSERT(obj);

    obj->rootDealloc();
}

inline void
objc_object::rootDealloc()
{
    if (isTaggedPointer()) return;  // fixme necessary?

#if !ISA_HAS_INLINE_RC
    object_dispose((id)this);
#else
    if (fastpath(isa().nonpointer                     &&
                 !isa().weakly_referenced             &&
                 !isa().has_assoc                     &&
#if ISA_HAS_CXX_DTOR_BIT
                 !isa().has_cxx_dtor                  &&
#else
                 !isa().getClass(false)->hasCxxDtor() &&
#endif
                 !isa().has_sidetable_rc))
    {
        assert(!sidetable_present());
        free(this);
    } 
    else {
        object_dispose((id)this);
    }
#endif // ISA_HAS_INLINE_RC
}

/***********************************************************************
* object_dispose
* fixme
* Locking: none
**********************************************************************/
id
object_dispose(id obj)
{
    if (!obj) return nil;

    objc_destructInstance(obj);
    free(obj);

    return nil;
}

/***********************************************************************
* objc_destructInstance
* Destroys an instance without freeing memory.
* Calls C++ destructors.
* Calls ARC ivar cleanup.
* Removes associative references.
* Returns `obj`. Does nothing if `obj` is nil.
**********************************************************************/
void *objc_destructInstance(id obj)
{
    if (obj) {
        // Read all of the flags at once for performance.
        bool cxx = obj->hasCxxDtor();
        bool assoc = obj->hasAssociatedObjects();

        // This order is important.
        if (cxx) object_cxxDestruct(obj);
        if (assoc) _object_remove_associations(obj, /*deallocating*/true);
        obj->clearDeallocating();
    }

    return obj;
}
inline void 
objc_object::clearDeallocating()
{
    sidetable_clearDeallocating();
}
void 
objc_object::sidetable_clearDeallocating()
{
    SideTable& table = SideTables()[this];

    // clear any weak table items
    // clear extra retain count and deallocating bit
    // (fixme warn or abort if extra retain count == 0 ?)
    table.lock();
    RefcountMap::iterator it = table.refcnts.find(this);
    if (it != table.refcnts.end()) {
        if (it->second & SIDE_TABLE_WEAKLY_REFERENCED) {
            weak_clear_no_lock(&table.weak_table, (id)this);
        }
        table.refcnts.erase(it);
    }
    table.unlock();
}
```
