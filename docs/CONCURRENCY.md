# 并发注意事项

当前版本暂未实现 GitHub history SHA conflict 自动重试。不要同时提交同一个 product_id 多次，否则可能出现 GitHub 写回冲突。
