---
title: 如何在sonarqube的pmd插件中整合阿里p3c开发规范
date: 2019-02-28 13:09:50
tags: 
- devops
- sonar
categories:
- devops
---

sonar-pmd是sonar官方的支持pmd的插件，但是还不支持p3c，需要在pmd插件源码中添加p3c支持(p3c是阿里在pmd基础上根据阿里巴巴开发手册实现了其中的49开发规则)

* 插件源码下载地址：https://github.com/mrprince/sonar-p3c-pmd
* 阿里p3c github：https://github.com/alibaba/p3c

此次使用的sonar版本：6.5

此源码工程已经添加了P3C支持：
```xml
<dependency>
    <groupId>com.alibaba.p3c</groupId>
    <artifactId>p3c-pmd</artifactId>
    <version>1.3.4</version>
</dependency>
```

在这个PMD插件中，已经在默认的268条规则上增加了48条阿里代码规则

# 修改PMD插件源码
相关文件：
* pmd.properties (src/main/resources/org/sonar/l10n/pmd.properties)
* rules-p3c.xml (src/main/resources/org/sonar/plugins/pmd/rules-p3c.xml)
* pmd-model.xml (src/main/resources/com/sonar/sqale/pmd-model.xml)

## 增加规则
该规范中少了一条 `AvoidManuallyCreateThreadRule` 规则，以添加该规则为例子

在 `pmd.properties` 中增加规则名称：
```properties
rule.pmd.AvoidManuallyCreateThreadRule.name=[p3c]avoid manually create thread.
```

在 `rules-p3c.xml` 中增加对应的p3c规则：
```xml
<rule key="AvoidManuallyCreateThreadRule">
    <priority>MAJOR</priority>
    <configKey><![CDATA[rulesets/java/ali-concurrent.xml/AvoidManuallyCreateThreadRule]]></configKey>
</rule>
```

在 `pmd-model.xml` 增加：
```xml
<chc>
    <rule-repo>pmd</rule-repo>
    <rule-key>AvoidManuallyCreateThreadRule</rule-key>
    <prop>
        <key>remediationFunction</key>
        <txt>CONSTANT_ISSUE</txt>
    </prop>
    <prop>
        <key>offset</key>
        <val>2</val>
        <txt>min</txt>
    </prop>
</chc>
```

在 `src/main/resources/org/sonar/l10n/pmd/rules/pmd-p3c` 包中增加相关sonar举例（必须增加，不然测试用例跑不通）：
```html
<p>Look for qualified this usages in the same class.</p>
<p>Examples:</p>
<pre>
    // 新增规则，没有示例
</pre>
```

如果要删除规则，按照上面的方式删除即可

## 其它设置
### 修改p3c提示语

可以下载阿里p3c源码，源码地址：https://github.com/alibaba/p3c

描述内容都在 `p3c/p3c-pmd/src/main/resources/messages.xml` 文件中，修改其中的描述内容即可

然后将其maven打包（可以deploy在公司的私有仓库中）

### 修改pmd插件在sonarqube中的插件显示名

可以修改 `sonar-p3c-pmd` 工程中的 `PmdConstants` 类 `REPOSITORY_NAME` 值即可

# sonar配置
## 整合插件

将 `sonar-p3c-pmd` 插件通过maven打包，然后将打好的jar包放在sonar目录下的 `extensions/plugins` 目录中

重启 `sonar` 服务，通过 `./bin/linux-x86-64/sonar.sh restart` 命令

查看插件是否安装正确（如果sonar启动失败，表示插件有问题）

![](/images/devops/sonar/sonar-p3c-pmd插件.png)

## 创建质量配置

在质量配置页面中，创建一个java规则

![](/images/devops/sonar/新建sonar java规则.png)

创建完成以后，进行激活规则操作，在资源库中找到上传的插件进行激活相关p3c规则

![](/images/devops/sonar/激活p3c规则.png)

在项目中配置对应的质量规则即可