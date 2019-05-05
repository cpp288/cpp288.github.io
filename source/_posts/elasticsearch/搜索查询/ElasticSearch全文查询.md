---
title: ElasticSearch全文查询
date: 2019-05-05 10:19:04
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

高级别的全文搜索通常用于在全文字段上进行全文搜索，通过全文查询理解被查询字段是如何被索引和分析的，在执行之前将每个字段的分词器应用于查询字符串（摘自《从Lucene到ElasticSearch：全文检索实战》）

# match query

match query 会对查询语句进行分词，分词后查询语句中的任何一个词项被匹配，文档就会被搜索到：

```json
GET books/_search
{
    "query" : {
        "match" : {
            "title" : {
                "query" : "java",
                "operator" : "or"
            }
        }
    }
}
```

# match_phrase query

match_phrase query 首先会把 query 内容分词，分词器可以自定义，同时文档需要满足以下两个条件才会被搜索到：
1. 分词后所有词项都要出现在该字段中
2. 字段中的词项顺序要一致

下面只有前两个文档会被匹配：

```json
GET test/_search
{
    "query" : {
        "match_phrase" : {
            "foo" : "hello world"
        }
    }
}

// 1
{
    "foo" : "I just said hello world"
}
// 2
{
    "foo" : "Hello world"
}
// 3
{
    "foo" : "World Hello"
}
```

# match_phrase_prefix query

与 match_phrase 类似，只不过 match_phrase_prefix 支持最后一个 term 前缀匹配

```json
GET test/_search
{
    "query" : {
        "match_phrase_prefix" : {
            "foo" : "hello w"
        }
    }
}
```

# multi_match query

multi_match 是 match 的升级，用于搜索多个字段

```json
GET books/search
{
    "query" : {
        "multi_match" : {
            "query" : "java",
            "fields" : ["title", "description"]
        }
    }
}
```

multi_match 支持对要搜索的字段的名称使用通配符：

```json
GET books/search
{
    "query" : {
        "multi_match" : {
            "query" : "java",
            "fields" : ["title", "*_name"]
        }
    }
}
```

也可以用指数符指定搜索字段的权重，指定关键字出现在 title 中的权重是出现在 description 字段中的3倍：

```json
GET books/search
{
    "query" : {
        "multi_match" : {
            "query" : "java",
            "fields" : ["title^3", "description"]
        }
    }
}
```

# common_terms query

common_terms query 是一种在不牺牲性能的情况下替代停用词提高搜索准确率和召回率的方案

查询中的每个词项都有一定的代价，以搜索"The brown fox"为例，query会解析成三个词项"the"、"brown"和"fox"，每个词项都会到索引中执行一次查询。很显然包含"the"的文档非常多，传统的解决方案是把"the"当作停用词处理，去除停用词之后可以减少索引大小，同时在搜索时减少对停用词的收缩

虽然停用词对文档评分影响不大，但是当停用词仍然有重要意义的时候，就无法区分"happy"和"not happy"，不会在索引中存在，搜索的准确率和召回率就会降低

common_terms query 提高了解决方案，它把 query 分词后的词项分成重要词项（低频词项）和不重要的词项（高频词项，也就是之前的停用词）。在搜索时，首先搜索重要词项匹配的文档，这些文档是词项出现较少并且词项对其评分影响较大的文档。然后执行搜索对评分影响较小的高频词项，但是不计算所有文档的评分，而是只计算第一次查询已经匹配的文档得分。如果一个查询中只包含高频词项，那么会通过 and 连接符执行一个单独的查询（搜索所有词项）
> 词项是否是高频词是通过 cutoff_frequency 来设置阈值的，值可以是绝对频率（>1）或者相对频率（0～1），它能自适应特定领域的停用词（将高频词自动表现为停用词，无需保留手动列表）

比如，文档频率高于0.1%的词项会被当做高频词项，用 low_freq_operator、high_freq_operator 参数连接，设置低频词项操作法为"and"是所有的低频词都是必须搜索的：

```json
GET _search
{
    "query" : {
        "common" : {
            "body" : {
                "query" : "nelly the elephant as a cartoon",
                "cutoff_frequency" : 0.001,
                "low_freq_operator" : "and"
            }
        }
    }
}
```
等价于：
```json
GET _search
{
    "query" : {
        "bool" : {
            "must" : [
                {
                    "term" : {
                        "body" : "nelly"
                    }
                },
                {
                    "term" : {
                        "body" : "elephant"
                    }
                },
                {
                    "term" : {
                        "body" : "cartoon"
                    }
                },
            ],
            "should" : [
                {
                    "term" : {
                        "body" : "the"
                    }
                },
                {
                    "term" : {
                        "body" : "as"
                    }
                },
                {
                    "term" : {
                        "body" : "a"
                    }
                },
            ]
        }
    }
}
```

# query_string query

query_string query 是与 Lucene 查询语句的语法结合非常紧密的一种查询，允许在一个查询语句中使用多个特殊条件关键字（AND、OR、NOT）对多个字段进行查询，建议熟悉 Lucene 查询语法的用户去使用

# simple_query_string

simple_query_string 是一种适合直接暴露给用户，并且具有非常完善的查询语法的查询语句，接受 Lucene 查询语法，解析过程中发送错误不会抛出异常

```json
GET _search
{
    "query" : {
        "simple_query_string" : {
            "query" : "\"fried eggs\" + (eggplant | potato) - frittata",
            "analyzer" : "snowball",
            "fields" : ["body^5", "_all"],
            "default_operator" : "and"
        }
    }
}
```