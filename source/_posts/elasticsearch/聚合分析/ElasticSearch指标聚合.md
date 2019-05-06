---
title: ElasticSearch指标聚合
date: 2019-05-06 13:35:15
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

# Max / Min Aggregation

用于最大值/最小值统计

```json
GET books/_search
{
    "size" : 0,
    "aggs" : {
        "max_price" : {
            "max" : {"field" : "price"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "max_price" : {"value" : 81.4}
    }
}
```

# Avg / Sum Aggregation

用于平均值/总和计算统计

```json
GET books/_search
{
    "size" : 0,
    "aggs" : {
        "sum_price" : {
            "sum" : {"field" : "price"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "sum_price" : {"value" : 815}
    }
}
```

# Cardinality Aggregation

用于基数统计，类似于SQL中的 distinct 操作，去掉集合中重复项，然后统计排重后的集合长度

例如，在 books 索引中对 language 字段进行 cardinality 操作可以统计出编程语言的种类数量：

```json
GET books/_search
{
    "size" : 0,
    "aggs" : {
        "all_lan" : {
            "cardinality" : {"field" : "language"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "all_lan" : {"value" : 3}
    }
}
```

# Stats / Extended Stats Aggregation

Stats 用于基本统计，会一次返回count、max、min、avg和sum 5个指标

Extended Stats 比 Stats 多4个指标：平方和（sum_of_squares）、方差（variance）、标准差（std_deviation）、平均值加/减两个标准差的区间（std_deviation_bounds）

```json
GET books/_search
{
    "size" : 0,
    "aggs" : {
        "grades_stats" : {
            "extended_stats" : {"field" : "price"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "grades_stats" : {
            "count" : 5,
            "min" : 46.5,
            "max" : 81.4,
            "avg" : 63.2,
            "sum" : 395,
            "sum_of_squares" : 21095.46,
            "variance" : 148.651999999999967,
            "std_deviation" : 12.19229264740638,
            "std_deviation_bounds" : {
                "upper" : 88.16458529481276,
                "lower" : 39.41541470518475
            }
        }
    }
}
```

# Percentiles Aggregation

用于百分位统计，百分位数是一个统计学术语，如果将一组数据从大到小排序，并计算相应的累计百分位，某一百分位所对应数据的值就称为这一百分位的百分位数

```json
GET books/_search
{
    "size" : 0,
    "aggs" : {
        "book_price" : {
            "percentiles" : {"field" : "price"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "book_price" : {
            "values" : {
                "1.0" : 46.82,
                "5.0" : 48.1,
                "25.0" : 54.5,
                "50.0" : 66.4,
                "75.0" : 70.2,
                "95.0" : 79.16,
                "99.0" : 80.95200000000001,
            }
        }
    }
}
```

# Value Count Aggregation

按字段统计文档数量

例如，统计 books 索引中包含 author 字段的文档数量

```json
POST books/_search
{
    "size" : 0,
    "aggs" : {
        "doc_count" : {
            "value_count" : {"field" : "author"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "doc_count" : {"value" : 3}
    }
}
```