---
title: iOS 属性修饰符
abstract: iOS 开发过程中，OC属性的一些修饰符介绍。
date: 2025-02-28 16:00:17
tags: iOS
categories: iOS
---

在 Objective-C 中，属性（`@property`）的修饰符用于控制属性行为的多个维度，包括**原子性**、**内存管理语义**、**读写权限**等。以下是详细分类及作用：

---

### 一、原子性（Atomicity）

控制属性读写操作的原子性，影响线程安全和性能。

| **修饰符**     | **作用**                                          | **性能** | **使用场景**          |
| ----------- | ----------------------------------------------- | ------ | ----------------- |
| `atomic`    | 默认值。保证 **setter/getter 的原子性**（操作完整执行，不被其他线程打断）。 | 较低     | 需简单线程同步（但非绝对线程安全） |
| `nonatomic` | 不保证原子性，**访问速度更快**。                              | 高      | 大多数场景（99%推荐使用）    |

**注意**：  

- `atomic` 仅保证单个操作的原子性，无法避免多线程同时修改属性值的竞态问题（需额外加锁）。  
- 例如：`atomic` 修饰的数组属性，可能被多个线程同时调用 `addObject:`，仍需使用锁或串行队列保证安全。

---

### 二、内存管理语义（Memory Management）

控制属性的引用计数和所有权，避免内存泄漏或野指针。

| **修饰符**             | **作用**                                 | **适用数据类型**              | **示例场景**                     |
| ------------------- | -------------------------------------- | ----------------------- | ---------------------------- |
| `strong` (ARC)      | **强引用**，持有对象，引用计数 +1。                  | Objective-C 对象          | 对象间父子关系（如 `UIView *`）        |
| `weak`              | **弱引用**，不持有对象，对象释放后自动置为 `nil`。         | Objective-C 对象          | 代理（`delegate`）、循环引用解         |
| `copy`              | 创建对象的**不可变副本**（调用 `copy` 方法）。          | 遵守 `NSCopying` 协议的对象    | `NSString`、`NSArray`、`Block` |
| `assign`            | **直接赋值**，不管理引用计数。                      | 基本数据类型（`int`、`CGFloat`） | `NSInteger`、结构体              |
| `unsafe_unretained` | 类似 `assign`，但用于对象类型（不自动置 `nil`，可能野指针）。 | Objective-C 对象          | 极少使用（兼容旧代码）                  |
| `retain` (MRC)      | 在 MRC 中表示强引用（ARC 中已被 `strong` 替代）。     | Objective-C 对象          | MRC 环境                       |

**关键区别**：  

- `strong` vs. `weak`：  
  
  ```objective-c
  @property (strong) NSObject *objA; // objA 被销毁时，属性仍指向原地址（可能野指针）
  @property (weak) NSObject *objB;   // objB 被销毁时，属性自动置 nil
  ```
- `copy` vs. `strong`（以 `NSString` 为例）：  
  
  ```objective-c
  @property (copy) NSString *name;    // 赋值时生成不可变副本，防止外部可变字符串修改
  @property (strong) NSString *name; // 直接引用原对象，若原对象是 NSMutableString 可能被意外修改
  ```

---

### 三、读写权限（Readability）

控制属性的访问接口生成规则。

| **修饰符**     | **作用**                         |
| ----------- | ------------------------------ |
| `readwrite` | 默认值。生成 **getter 和 setter** 方法。 |
| `readonly`  | 仅生成 **getter** 方法。             |

**自定义方法名示例**：  

```objective-c
@property (nonatomic, getter=isEnabled) BOOL enabled; // getter 方法名为 isEnabled
@property (nonatomic, setter=setVIPStatus:) BOOL vip; // setter 方法名为 setVIPStatus:
```

---

### 四、其他修饰符

| **修饰符**    | **作用**                             |
| ---------- | ---------------------------------- |
| `class`    | 声明类属性（Objective-C 2.0+ 支持）。        |
| `nullable` | 表示属性值可为 `nil`（Swift 可选类型兼容）。       |
| `nonnull`  | 表示属性值不可为 `nil`（默认行为，显式声明可提高代码可读性）。 |

---

### 五、最佳实践总结

1. **常规对象属性**：  
   
   ```objective-c
   @property (nonatomic, strong) NSObject *object; // 推荐 nonatomic + strong
   ```
2. **字符串/容器/Block**：  
   
   ```objective-c
   @property (nonatomic, copy) NSString *name;      // 防止可变字符串篡改
   @property (nonatomic, copy) void (^callback)(void); // Block 需用 copy
   ```
3. **代理与循环引用解**：  
   
   ```objective-c
   @property (nonatomic, weak) id<MyDelegate> delegate; // 避免循环引用
   ```
4. **基本数据类型**：  
   
   ```objective-c
   @property (nonatomic, assign) NSInteger count;      // 整型
   @property (nonatomic, assign) CGRect frame;         // 结构体
   ```

---

### 六、底层原理

- **`atomic` 实现**：  
  通过内部锁（如 `os_unfair_lock`）保证 setter 和 getter 的原子性。
  
  ```objc
  // 伪代码示例
  - (void)setName:(NSString *)name {
      lock();
      _name = name;
      unlock();
  }
  ```
- **`copy` 的实现**：  
  调用 `copy` 方法，具体行为取决于对象的 `NSCopying` 实现：
  
  ```objc
  - (void)setName:(NSString *)name {
      _name = [name copy]; // 若 name 是 NSMutableString，copy 返回不可变 NSString
  }
  ```

---

通过合理选择属性修饰符，开发者可以精确控制内存管理、线程安全和数据封装行为，避免常见的内存错误和性能瓶颈。
