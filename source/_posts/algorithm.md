---
title: algorithm
abstract: 刷题方法论 - 反思
date: 2025-05-13 22:27:48
tags: algorithm
categories:
---

# 概述

记录/思考/
2901. 最长相邻不相等子序列 II

求最长子序列 符合两个条件

求最长子序列需要动态规划，在动态规划的基础上，怎么内嵌新的条件。

怎么记录path -》 使用前缀数组，记录走过的路径。

dp i 和 dp 0..<i 的关系。