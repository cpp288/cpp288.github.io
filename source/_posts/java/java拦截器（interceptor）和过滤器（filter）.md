---
title: java拦截器（interceptor）和过滤器（filter）
date: 2019-03-04 13:32:22
tags:
- java
categories: 
- java
---

从概念上来讲，filter是servlet规范定义的，而interceptor是spring定义的

过滤器和拦截器在对请求进行拦截时：
* 发生的时机不一样，filter是在servlet容器外，interceptor在servlet容器内，且可以对请求的3个关键步骤进行拦截处理
* 另外filter在过滤是只能对request和response进行操作，而interceptor可以对request、response、handler、modelAndView、exception进行操作。

相关DEMO：

**过滤器（Filter）**：
```java
@Component
@WebFilter(filterName = "urlFilter", urlPatterns = "/test")// 配置拦截路径
public class UrlFilter implements Filter {

    /**
     * filter初始化的时候调用，即web容器启动时调用
     * web容器启动时根据web.xml文件，依次加载ServletContext -> listener -> filter -> servlet
     *
     * @param filterConfig
     * @throws ServletException
     */
    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        System.out.println("UrlFilter init...");
    }

    /**
     * filter执行功能，根据参数来看，可以对request,response和chain（是否放行）进行操作
     *
     * @param request
     * @param response
     * @param chain
     * @throws IOException
     * @throws ServletException
     */
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) throws IOException, ServletException {
        System.out.println("UrlFilter doFilter before...");
        chain.doFilter(request, response);
        System.out.println("UrlFilter doFilter after...");
    }

    /**
     * filter在服务器正常关闭(比如System.exit(0))等情况下会调用
     */
    @Override
    public void destroy() {
        System.out.println("UrlFilter destroy...");
    }
}
```

**拦截器（Interceptor）**
```java
@Component
public class UrlInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        System.out.println("UrlInterceptor preHandle...");
        return true;
    }

    @Override
    public void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler, ModelAndView modelAndView) throws Exception {
        System.out.println("UrlInterceptor postHandle...");
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) throws Exception {
        System.out.println("UrlInterceptor afterCompletion...");
    }
}
```
注册拦截器：
```java
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Autowired
    private UrlInterceptor urlInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(urlInterceptor).addPathPatterns("/test");
    }
}
```

**执行结果分析**

这里用的是spring boot来搭建并启动web服务（使用spring boot bean的方式配置）

```java
@RestController
public class TestController {

    @GetMapping(value = "/test")
    public String test() {
        System.out.println("do test...");
        return "ok";
    }
}
```

访问该api打印日志：
```
UrlFilter doFilter before...
UrlInterceptor preHandle...
do test...
UrlInterceptor postHandle...
UrlInterceptor afterCompletion...
UrlFilter doFilter after...
```

相关博客文章：
* https://blog.csdn.net/dshf_1/article/details/81112595