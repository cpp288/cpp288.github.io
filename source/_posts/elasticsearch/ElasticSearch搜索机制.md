---
title: ElasticSearch搜索机制
date: 2019-05-05 10:30:07
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

摘自《从Lucene到ElasticSearch：全文检索实战》

搜索流程图如下：

![](/images/elasticsearch/ElasticSearch搜索流程图.png)

* 第一象限：用户
* 第二象限：原始文档
* 第三象限：ElasticSearch
* 第四象限：搜索结果

索引过程：原始文档有 title 和 content 两个字段，当把这条文档写入到 ElasticSearch 之后，默认情况下会保存两份内容，一份是该文档的原始内容，也就是 _source 中的文档内容，另一份是索引时通过分词、过滤等一系列过程生成的倒排序索引文件（保存了词项和文档的对应关系）

搜索过程：ElasticSearch 收到用户查询关键词之后，到倒排序索引中进行查询，找到关键词对应的文档集合，然后做评分、排序、高亮处理，最终返回结果给用户

