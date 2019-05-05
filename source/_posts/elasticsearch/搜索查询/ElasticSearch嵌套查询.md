---
title: ElasticSearch嵌套查询
date: 2019-05-05 19:06:26
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

在 ElasticSearch 这样的分布式系统中执行 SQL 风格的连接查询代价昂贵，为了实现水平规模的扩展，提供了两种形式的join：
* nested query（嵌套查询）
    > 文档中可能包含嵌套类型的字段，这些字段用来索引一些数组对象，每个对象都可以作为一条独立的文档被查询出来
* has_child query（有子查询）和has_parent query（有父查询）
    > 父子关系可以存在单个的索引的两个类型的文档之间。has_child 返回其子文档能满足特定查询的父文档；has_parent 返回其父文档能满足特定查询的子文档

# nested query

文档中可能包含嵌套类型的字段，这些字段用来索引一些数组对象，每个对象都可以作为一条独立的文档被查询出来

文档的父子关系在创建索引时在映射中声明

```json
PUT /my_index
{
    "mappings" : {
        "type1" : {
            "properties" : {
                "obj1" : {
                    "type" : "nested"
                }
            }
        }
    }
}
```

# has_child query

这里以员工（employee）和工作城市（branch）为例，它们属于不同的类型，相当于数据库中的两张表，这里需要建立映射关系，员工是 child type，工作城市是 parent type：

```json
PUT /company
{
    "mappings" : {
        "branch" : {},
        "employee" : {
            "_parent" : {
                "type" : "branch"
            }
        }
    }
}
```

使用 bulk api 索引 branch 类型下的文档：

```json
POST company/branch/_bulk
{"index" : {"_id" : "london"}}
{"name" : "London Westminster", "city" : "London", "country" : "UK"}
{"index" : {"_id" : "liverpool"}}
{"name" : "Liverpool Central", "city" : "Liverpool", "country" : "UK"}
```

添加员工数据：
```json
{"index" : {"_id" : 1, "parent" :  "london"}}
{"name" : "Alice Smith", "dob" : "1970-10-24", "hobby" : "hiking"}
{"index" : {"_id" : 2, "parent" :  "liverpool"}}
{"name" : "Alice Grand", "dob" : "1980-04-24", "hobby" : "diving"}
```

搜索1980年以后出生的员工所在工作城市：

```json
GET company/barnch/_search
{
    "query" : {
        "has_child" : {
            "type" : "employee",
            "query" : {
                "range" : {
                    "dob" : {
                        "gte" : "1980-01-01"
                    }
                }
            }
        }
    }
}
```

可以使用 min_children 指定子文档的最小个数，例如搜索最少有两个 employee 的机构：

```json
GET company/barnch/_search?pretty
{
    "query" : {
        "has_child" : {
            "type" : "employee",
            "min_children" : 2,
            "query" : {
                "match_all" : {}
            }
        }
    }
}
```

# has_parent query

搜索哪些 employee 工作在 UK：

```json
GET company/employee/_search
{
    "query" : {
        "has_parent" : {
            "parent_type" : "branch",
            "query" : {
                "match" : {
                    "country" : "UK"
                }
            }
        }
    }
}
```