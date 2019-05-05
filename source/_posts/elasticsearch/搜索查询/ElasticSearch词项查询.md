---
title: ElasticSearch词项查询
date: 2019-05-05 14:55:16
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

全文搜索在执行查询之前会分析查询字符串，词项搜索时对倒排序索引中存储的词项进行精确操作。常用于结构化数据，如数字、日期和枚举类型

# term query

term 查询用来查找指定字段中包含给定单词的文档，term 查询不被解析，只有查询词和文档中的词精确匹配才会被搜索到

```json
GET books/_search
{
    "query" : {
        "term" : {
            "title" : "java"
        }
    }
}
```

# terms query

是 term 的升级，可以用来查询文档中包含多个词的文档

```json
GET books/_search
{
    "query" : {
        "terms" : {
            "title" : ["java", "python"]
        }
    }
}
```

# range query

range 查询用于匹配某一范围内的数值型、日期类型或者字符串字段的文档，支持的参数：
* gt：大于
* gte：大于等于
* lt：小于
* lte：小于等于

```json
GET books/_search
{
    "query" : {
        "range" : {
            "price" : {
                "gt" : 50,
                "lte" : 70
            },
            "publish_time" : {
                "gte" : "2018-01-01",
                "lte" : "2019-12-31",
                "format" : "yyyy-MM-dd"
            }
        }
    }
}
```

# exists query

exists 查询会返回字段中至少有一个非空值的文档：

```json
GET _search
{
    "query" : {
        "exists" : {
            "field" : "user"
        }
    }
}
```

以下会匹配：
* `{"user" : "jane"}`
* `{"user" : ""}`
* `{"user" : "-"}`
* `{"user" : ["jane"]}`
* `{"user" : ["jane", null]}`

以下不会匹配：
* `{"user" : null}`
* `{"user" : []}`
* `{"user" : [null]}`
* `{"foo" : bar}` 没有user字段

# prefix query

prefix 查询用于查询某个字段中以给定前缀开始的文档：

```json
GET books/_search
{
    "query" : {
        "prefix" : {
            "description" : "win"
        }
    }
}
```

# wildcard query

通配符查询，支持单字符通配符和多字符通配符：
* `?` 匹配一个任意字符
* `*` 匹配零个或多个字符

和 prefix 查询一样，wildcard 查询的性能不是很高，需要消耗较多的CPU资源

```json
GET books/_search
{
    "query" : {
        "wildcard" : {
            "author" : "陈*"
        }
    }
}
```

# regexp query

正则表达式查询

```json
GET _search
{
    "query" : {
        "regexp" : {
            "oistcide" : "W[0-9].+"
        }
    }
}
```

# fuzzy query

编辑距离又称 Levenshtein 距离，是指两个字符串之间，由一个转成另一个所需的最少编辑操作次数（许可操作包括替换、插入、删除一个字符）

fuzzy 查询就是通过计算词项与文档的编辑距离来得到结果的，但是需要消耗的资源比较大，效率不高，适用于需要模糊查询的场景

```json
GET books/_search
{
    "query" : {
        "fuzzy" : {
            "title" : "javascritp"  // 将 javascript 打成了 javascritp
        }
    }
}
```

# type query

用于查询具有指定类型的文档：

```json
GET _search
{
    "query" : {
        "type" : {
            "value" : "IT"
        }
    }
}
```

# ids query

用于查询具有指定id的文档

类型是可选的，也可以省略，也可以接受一个数组：

```json
GET _search
{
    "query" : {
        "ids" : {
            "type" : "IT",
            "value" : ["1", "2", "3"]
        }
    }
}
```