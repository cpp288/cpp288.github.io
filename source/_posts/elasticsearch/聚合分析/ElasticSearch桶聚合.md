---
title: ElasticSearch桶聚合
date: 2019-05-06 14:40:01
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

Bucket 可以理解为一个桶，它会遍历文档中的内容，凡是符合某一要求的就放入一个桶中（类似于SQL中的group by）

# Terms Aggregation

用于分组聚合

根据 language 字段对 books 索引中的文档进行分组，统计各编程语言的书的数量

```json
POST books/_search?size=0
{
    "aggs" : {
        "per_count" : {
            "items" : {"feild" : "language"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "per_count" : {
            "doc_count_error_upper_bound" : 0,
            "sum_other_doc_count" : 0,
            "buckets" : [
                {"key" : "java", "doc_count" :  2},
                {"key" : "python", "doc_count" :  2},
                {"key" : "javascript", "doc_count" :  3}
            ]
        }
    }
}
```

# Filter / Filters Aggregation

Filter 是过滤器聚合，将符合过滤器条件的文档分别分到一个桶中

Filters 是多过滤器聚合，将符合多个过滤条件的文档分到不通的桶中

```json
POST books/_search?size=0
{
    "aggs" : {
        "per_avg_price" : {
            "filters" : {
                "filters" : [
                    {"match" : {"title" : "java"}},
                    {"match" : {"title" : "python"}}
                ]
            },
            "aggs" : {
                "avg_price" : {
                    {"avg" : {"feild" : "price"}}
                }
            }
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "per_avg_price" : {
            "buckets" : [
                {
                    "doc_count" : 2,
                    "avg_price" : {"value" :  58.35}
                },
                {
                    "doc_count" : 4,
                    "avg_price" : {"value" :  67.95}
                }
            ]
        }    
    }
}
```

# Range / Date Range / IP Range Aggregation

Range 范围聚合，可以用于数字、日期

```json
POST books/_search?size=0
{
    "aggs" : {
        "price_ranges" : {
            "range" : {
                "field" : "price",
                "ranges" : {
                    {"to" : 50},    // 小于 50
                    {"from" : 50, "to" : 80},   // 大于等于50小于80
                    {"from" : 80}   // 大于等于80
                }
            }
        }
    }
}
```

Date Range 专门用于日期类型的，与 Range 不通在于日期的起止值可以使用数学表达式

```json
POST books/_search?size=0
{
    "aggs" : {
        "publish_ranges" : {
            "date_range" : {
                "field" : "publish_time",
                "format" : "yyyy-MM-dd",
                "ranges" : {
                    {"to" : "now-24M/M"},   // 两年前
                    {"from" : "now-24M/M"}  // 两年前到现在
                }
            }
        }
    }
}
```

IP Range 用于对IP类型数据范围聚合

```json
POST ip_test/_search?size=0
{
    "aggs" : {
        "ip_ranges" : {
            "ip_range" : {
                "field" : "ip",
                "ranges" : {
                    {"to" : "10.0.0.5"},
                    {"from" : "10.0.0.5"}
                }
            }
        }
    }
}
```

# Date Histogram Aggregation

时间直方图聚合，常用于按照日期对文档进行统计并绘制条形图

对 books 索引中的图书和出版日期按月做时间直方图聚合

```json
POST books/_search?size=0
{
    "aggs" : {
        "books_over_time" : {
            "date_histogram" : {
                "feild" : "publish_time",
                "interval" : "month"
            }
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "books_over_time" : {
            "buckets" : [
                {
                    "key_as_string" : "2007-10-01T00:00:00.000Z",
                    "key" : 1191196800000,
                    "doc_count" : 1
                },
                ...
            ]
        }
    }
}
```

# Missing Aggregation

空值聚合，将文档集中所有缺失字段的文档分到一个桶中

对 books 索引中缺失 price 字段（包含值为null的）的文档进行聚合

```json
POST books/_search?size=0
{
    "aggs" : {
        "books_without_a_price" : {
            "missing" : {"feild" : "price"}
        }
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "books_without_a_price" : {
            "doc_count" : 0
        }
    }
}
```

# Children Aggregation

一种特殊的单桶聚合，可以根据父子分档关系进行分桶

# Geo Distance Aggregation

用于对地理点（geo_point）做范围统计

```json
POST geo/_search?size=0
{
    "aggs" : {
        "city_from_beijing" : {
            "geo_distance" : {
                "feild" : "location",
                "origin" : "39.90498900,116.40528500",
                "unit" : "km",
                "ranges" : [
                    {"to" : 500},
                    {"from" : 500, "to" : 1000},
                    {"from" : 1000},
                ]
            }
        }    
    }
}
```

结果如下：

```json
{
    "aggregations" : {
        "city_from_beijing" : {
            "buckets" : [
                {
                    "key" : "*-500.0",
                    "from" : 0,
                    "to" : 500,
                    "doc_count" : 2
                },
                {
                    "key" : "500.0-1000.0",
                    "from" : 500,
                    "to" : 1000,
                    "doc_count" : 2
                },
                {
                    "key" : "1000.0-*",
                    "from" : 1000,
                    "doc_count" : 3
                }
            ]
        }    
    }
}
```