---
title: ElasticSearch搜索排序
date: 2019-05-06 10:11:17
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

# 默认排序

ElasticSearch 是按照查询和文档的相关度进行排序的，默认按评分降序排序

```json
GET books/_search
{
    "query" : {
        "term" : {"title" : "java"}
    }
}
```

等价于

```json
GET books/_search
{
    "query" : {
        "term" : {"title" : "java"}
    },
    "sort" : {
        {
            "_score" : {"order" : "desc"}
        }
    }
}
```

对于 match_all 而言，由于只返回所有文档，不需要评分，文档的顺序为添加文档的顺序

# 多字段排序

和 SQL 一样，也支持多字段排序：

```json
GET books/_search
{
    "sort" : {
        {
            "price" : {"order" : "desc"},
            "year" : {"order" :  "asc"}
        }
    }
}
```

# 分片影响评分

ElasticSearch 是在每一个分片上单独打分的，分片的数量会影响打分的结果

同时，分词器也会影响评分，原因是使用不同的分词器会使倒排序索引中的词项数发生改变，最终影响得分