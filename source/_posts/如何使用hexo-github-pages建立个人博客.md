---
title: 如何使用hexo + github pages建立个人博客
date: 2019-02-26 15:56:47
tags: 
- hexo
categories: 
- 其它
---

# hexo

Hexo 是一个快速、简洁且高效的博客框架。Hexo 使用 [Markdown](http://daringfireball.net/projects/markdown/)（或其他渲染引擎）解析文章，在几秒内，即可利用靓丽的主题生成静态网页。

## 安装

hexo官方文档：https://hexo.io/zh-cn/docs/

按照官网文档安装hexo，安装hexo之前需要先安装 node（推荐使用 nvm 安装） 和 git

## 基本使用

1. 初始化网站：
```
hexo init <dirName> # 也可以新建一个空目录，然后执行 hexo init
npm install # npm安装
```

2. 生成静态文件：
```
hexo g # 或者使用 hexo generate
```

3. 启动本地服务：
```
hexo s # 或者使用 hexo server，然后通过http://127.0.0.1:4000访问
```

常用命令：
```
hexo n == hexo new			# 新建文章、页面等
hexo g == hexo generate		# 生成静态文件
hexo s == hexo server		# 启动服务
hexo d == hexo deploy		# 发布
```

## 主题

官方主题地址：https://hexo.io/themes/

这里使用的是 next，地址：http://theme-next.iissnan.com/

只要将主题放到 themes 目录下，然后修改**站点配置文件** `_config.yml` 中的 theme 值即可

具体设置可以参考上面的next文档

# 使用github部署hexo

修改**站点配置文件** `_config.yml` ：
```yml
deploy:
    type: git
    repo: git@github.com:cpp288/cpp288.github.io.git  #这里的网址填你自己的
    branch: master  
```

配置github ssh key：

1. `ssh-keygen -t rsa -C "邮件地址@youremail.com"`  生成新的key文件，邮箱地址填你的Github地址，后面直接回车进行
2. 将生成的工钥 `id_rsa.pub` 配置到 github 上
3. 执行 `ssh -T git@github.com` 如下提示则成功
   ```
   Hi cpp288! You've successfully authenticated, but GitHub does not provide shell access.
   ```

安装扩展：
```
npm install hexo-deployer-git --save 
```

部署到 github：
```
hexo d
```

# 相关问题
**电脑重装了系统/多台电脑写博客？**

参考博客：
* https://www.zhihu.com/question/21193762
* https://blog.csdn.net/heimu24/article/details/81210640

**如何添加本地图片？**

在 source 目录下新建目录，将图片放在其中（可以建多级目录），hexo 会在 generate 时将图片放到 public 中，使用 markdown 图片语法即可

# 相关博客
* [我是如何利用Github Pages搭建起我的博客，细数一路的坑](https://www.cnblogs.com/jackyroc/p/7681938.html)
* [Hexo Next主题开启字数统计和阅读时长统计](https://vwin.github.io/2018/08/02/Hexo-Next%E4%B8%BB%E9%A2%98%E5%BC%80%E5%90%AF%E5%AD%97%E6%95%B0%E7%BB%9F%E8%AE%A1%E5%92%8C%E9%98%85%E8%AF%BB%E6%97%B6%E9%95%BF%E7%BB%9F%E8%AE%A1/)