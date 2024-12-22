#!/bin/bash

# 提示用户输入自定义的commit文案内容
read -p "请输入commit文案（格式按照 [post][article]自定义内容 ）：" commit_message

# 添加所有更新的文件到暂存区
git add .

# 使用用户输入的commit文案进行提交
git commit -m "$commit_message"

# 将本地的提交推送到远程仓库的对应分支（这里假设是推送到origin的master分支，你可以根据实际情况修改）
git push origin master

echo "推送成功！"
