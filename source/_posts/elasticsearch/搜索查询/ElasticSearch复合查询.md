---
title: ElasticSearch复合查询
date: 2019-05-05 16:42:32
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

复合查询就是把一些简单查询组合在一起实现更复杂的查询需求，除此之外还可以控制另外一个查询的行为

# constant_score query

constant_source query 可以包装一个其它类型的查询，并返回匹配过滤器中的查询条件且具有相同评分的文档

下面的查询会返回 title 字段中含有关键词"java"的文档，所有文档评分都是1.2

```json
GET books/_search
{
    "query" : {
        "constant_score" : {
            "filter" : {
                "term" : {
                    "title" : "java"
                },
                "boost" : 1.2
            }
        }
    }
}
```

# bool query

bool 查询可以把任意多个简单查询组合在一起，使用 must、should、must_not、filter选项来表示简单查询之间的逻辑（可以出现0次或多次）：
* must：文档必须匹配 must选项下的查询条件，相当于and
* should：文档可以匹配 should 选项下的查询条件也可以不匹配，相当于or
* must_not：于 must 相反
* filter：和 must 一样，但是 filter 不评分，只起到过滤作用

查询 title 中包含关键字 java，且 price 不高于70，description 可以包含也可以不包含虚拟机的书籍：

```json
GET books/_search
{
    "query" : {
        "bool" : {
            "must" : {
                "match" : {
                    "title" : "java"
                }
            },
            "should" : {
                "match" : {
                    "description" : "虚拟机"
                }
            },
            "must_not" : {
                "range" : {
                    "price" : {
                        "gte" : 70
                    }
                }
            }
        }
    }
}
```

# dis_max query

dis_max query 与 bool query 有一定联系也有一定区别，dis_max query 支持多并发查询，可返回与任意查询条件子句匹配的任何文档类型。与 bool 查询可以将所有匹配查询的分数相结合的方式不通，dis_max 查询只使用最佳匹配查询条件的分数

```json
GET _search
{
    "query" : {
        "dis_max" : {
            "tie_breaker" : 0.7,
            "boost" : 1.2,
            "queries" : [
                {
                    "term" : {
                        "age" : 34
                    }
                },
                {
                    "term" : {
                        "age" : 35
                    }
                }
            ]
        }
    }
}
```

# function_score query

function_score query 可以修改查询的文档得分，比如通过评分函数计算文档得分代价较高，可以改用过滤器加自定义评分函数的方式来取代传统的评分方式

用户需要定义一个查询和一到多个评分函数，评分函数会对查询到的每个文档分别计算得分

下面这条语句会返回books索引中的所有文档，最大得分为5，每个文档的得分随机生成，权重的计算模式为相乘模式：

```json
GET books/_search
{
    "query" : {
        "function_score" : {
            "query" : {
                "match_all" : {}
            },
            "boost" : "5",
            "random_score" : {},
            "boost_mode" : "multiply"
        }
    }
}
```

使用脚本自定义评分公式，这里把 price 值的十分之一开方作为每个文档的得分：

```json
GET books/_search
{
    "query" : {
        "function_score" : {
            "query" : {
                "match" : {
                    "title" : "java"
                }
            },
            "script_score" : {
                "script" : {
                    "inline" : "Math.sqrt(doc('price').value/10)"
                }
            }
        }
    }
}
```

# boosting query

boosting 查询用于需要对两个查询的评分进行调整的场景，boosting 查询会把两个查询封装在一起并降低其中一个查询的评分。

boosting 查询包括 positive、negative 和 negative_boost 三个部分：
* positive：查询评分保持不变
* negative：查询会降低文档评分
* negative_boost：指明 negative 中降低的权值（之前得分的XX倍）

```json
GET books/_search
{
    "query" : {
        "boosting" : {
            "positive" : {
                "match" : {
                    "title" : "python"
                }
            },
            "negative" : {
                "range" : {
                    "publish_time" : {
                        "lte" : "2015-01-01"
                    }
                }
            },
            "negative_boost" : 0.2
        }
    }
}
```

# indices query

indices query 适用于需要在多个索引之间进行查询的场景，它允许指定一个索引名字列表和内部查询。

由 query 和 no_match_query 两部分组成：
* query：用于搜索指定索引列表中的文档
* no_match_query：用于搜索指定索引列表之外的文档

```json
GET _search
{
    "query" : {
        "indices" : {
            "indices" : ["books", "books2"],
            "query" : {
                "match" : {
                    "title" : "javascript"
                }
            },
            "no_match_query" : {
                "term" : {
                    "title" : "basketball"
                }
            }
        }
    }
}
```