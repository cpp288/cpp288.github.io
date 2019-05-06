---
title: ElasticSearch搜索高亮
date: 2019-05-06 09:57:54
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

# 自定义高亮片段

ElasticSearch 默认会用 `<em></em>` 标签标记关键字。想要自定义标签，只要在高亮属性中给需要高亮的字段加上 pre_tags 和 post_tags 即可：

```json
GET books/_search
{
    "query" : {
        "match" : {"title" : "java"}
    },
    "highlight" : {
        "fields" : {
            "title" : {
                "pre_tags" : ["<strong>"],
                "post_tags" : ["</strong>"]
            }
        }
    }
}
```

# 多字段高亮

比如，搜索 title 字段的时候，希望 description 字段中的关键字也可以高亮，这时候就需要把 require_field_match 属性设置为 false（默认为true）

```json
GET books/_search
{
    "query" : {
        "match" : {"title" : "java"}
    },
    "highlight" : {
        "require_field_match" : false,
        "fields" : {
            "title" : {},
            "description" : {}
        }
    }
}
```

# 高亮性能分析

ElasticSearch 提供了三种高亮器：
* highlighter
    > 默认高亮器，需要对 _source 中保存的文档进行二次分析，速度最慢，优点是不需要额外的存储空间
* postings-highlighter
    > 不需要二次分析，但是需要在字段的映射中设置 index_options 参数为 offsets（即保存关键词的偏移量），速度快于 highlighter
* fast-vector-highlighter
    > 速度最快，但是需要在字段的映射中设置 ter_vector 参数为 with_positions_offsets（即保存关键字的位置和偏移量），占用的空间最大，是典型的空间换时间的做法

