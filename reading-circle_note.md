# 輪読会 演習メモ

## 3章

### 3-2 負荷試験の準備

#### リスト4 nginxでJSON形式のアクセスログを出力する設定例

```
log_format json escape=json '{"time":"$time_iso8601",'
  '"host":"$remote_addr",'
  '"port":$remote_port,'
  '"method":"$request_method",'
  '"uri":"$request_uri",'
  '"status":"$status",'
  '"body_bytes":$body_bytes_sent,'
  '"referer":"$http_referer",'
  '"ua":"$http_user_agent",'
  '"request_time":"$request_time",'
  '"response_time":"$upstream_response_time"}';

access_log /var/log/nginx/access.log json;
```