---
title: ElasticSearch位置查询
date: 2019-05-05 19:32:32
tags:
- ElasticSearch
- 从Lucene到ElasticSearch：全文检索实战
categories:
- ElasticSearch
---

ElasticSearch 可以对地理位置点 geo_point 类型和地理位置形状 geo_shape 类型的数据进行搜索。

地址位置数据：

```json
{"index" : {"_index" : "geo", "_type" : "city", "_id" : "1"}}
{"name" : "北京", "location" : "39.90498900,116.40528500"}
{"index" : {"_index" : "geo", "_type" : "city", "_id" : "2"}}
{"name" : "上海", "location" : "31.23170600,121.47264400"}
{"index" : {"_index" : "geo", "_type" : "city", "_id" : "3"}}
{"name" : "广州", "location" : "23.12517800,113.28063700"}
{"index" : {"_index" : "geo", "_type" : "city", "_id" : "4"}}
{"name" : "杭州", "location" : "30.28745900,120.15357600"}
```

创建一个索引并设置映射：

```json
PUT geo
{
    "mappings" : {
        "city" : {
            "properties" : {
                "name" : {
                    "type" : "keyword"
                }
            },
            "location" : {
                "type" : "geo_point"
            }
        }
    }
}
```

# geo_distance query

geo_distance query 可以查找在一个中心点指定范围内的地理点文档，例如查找距离北京200KM以内的城市

```json
GET geo/_search
{
    "query" : {
        "bool" : {
            "must" : {
                "match_all" : {}
            },
            "filter" : {
                "geo_distance" : {
                    "distance" : "200km",
                    "location" : {
                        "lat" : 39.90498900,
                        "lon" : 116.40528500
                    }
                }
            }
        }
    }
}
```

按各城市离北京的距离排序：

```json
GET geo/_search
{
    "query" : {
        "match_all" : {}
    },
    "sort" : {
        "_geo_distance" : {
            "location" : "39.90498900,116.40528500",
            "unit" : "km"
        }
    }
}
```

# geo_bounding_box query

geo_bounding_box query 用于查找落入指定的矩形内的地址坐标。查询中由两个点确定一个矩形

![](/images/elasticsearch/geo_bounding_box矩形查找.png)

```json
GET geo/_search
{
    "query" : {
        "bool" : {
            "must" : {
                 "match_all" : {}
            },
            "filter" : {
                "geo_bounding_box" : {
                    "location" : {
                        "top_left" : {
                            "lat" : 39.90498900,
                            "lon" : 116.40528500
                        },
                        "bottom_right" : {
                            "lat" : 30.28745900,
                            "lon" : 120.15357600
                        }
                    }
                }
            }
        }
    }
}
```

# geo_polygon query

geo_polygon query 用于查找在指定多边形内的地理点

```json
GET geo/_search
{
    "query" : {
        "bool" : {
            "must" : {
                 "match_all" : {}
            },
            "filter" : {
                "geo_polygon" : {
                    "location" : {
                        "points" : [
                            {
                                "lat" : 39.90498900,
                                "lon" : 116.40528500
                            },
                            {
                                "lat" : 39.90498900,
                                "lon" : 116.40528500
                            },
                            {
                                "lat" : 23.12517800,
                                "lon" : 113.28063700
                            },
                        ]
                    }
                }
            }
        }
    }
}
```

# geo_shape query

geo_shape query 用于查询 get_shape 类型的地理数据，地理形状之间的关系有相交、包含、不相交三种。

创建一个新的索引用于测试，其中 location 字段的类型设为 get_shape 类型：

```json
PUT geoshape
{
    "mappings" : {
        "city" : {
            "properties" : {
                "name" : {
                    "type" : "keyword"
                }
            },
            "location" : {
                "type" : "geo_shape"
            }
        }
    }
}
```

> 关于经纬度的顺序，geo_point 类型的字段纬度在前经度在后，对于 geo_shape 类型则相反

把西安和郑州连成的线写入索引：

```json
POST geoshape/city/1
{
    "name" : "西安-郑州",
    "location" : {
        "type" : "linestring",
        "coordinates" : [
            [108.94802400, 34.26316100],
            [113.66541200, 34.75797500]
        ]
    }
}
```

查询包含在由银川和南昌作为对角线上的点组成的矩形的地理形状，由于西安和郑州组成的直线在该矩形区域内，因此可以被查到

```json
GET geoshape/_search
{
    "query" : {
        "bool" : {
            "must" : {
                 "match_all" : {}
            },
            "filter" : {
                "geo_shape" : {
                    "location" : {
                        "shape" : {
                            "type" : "envelope",
                            "coordinates" : [
                                [106.27817900, 38.46637000],  // 银川
                                [115.89215100, 28.67649300]   // 南昌
                            ]
                        },
                        "relation" : "within"
                    }
                }
            }
        }
    }
}
```